#!/usr/bin/perl -w

use strict;
use Mojo::IOLoop;
use Mojo::Log;
use Mojo::Asset::File;
use PProxy::IDS;
use File::Path 'make_path';
use File::Spec;
use MIME::QuotedPrint 'encode_qp';

my $conf = do 'pproxy.conf' or die 'Invalid configuration file';
my $log = Mojo::Log->new(path => $conf->{log}, level => 'info');
my $rules_dir = $conf->{rules} // 'rules';
my $proxy = $conf->{proxy};
my $dump_dir = $conf->{dump_dir} // 'dumps';
my $connections = {};

my $ids = PProxy::IDS->new($rules_dir);

for my $port (keys %$proxy) {
    make_path(File::Spec->catfile($dump_dir, $port));
    $log->info("Start listen on $port");
    my $remote_addr = $proxy->{$port}->{address};
    my $remote_port = $proxy->{$port}->{port};
    my $server = Mojo::IOLoop->server({port => $port} => sub {
        my ($loop, $stream, $id) = @_;
        $stream->on(close => sub {
            $log->debug("Closed $id");
            Mojo::IOLoop->remove($connections->{$id}->{orign_id}) if $connections->{$id}->{orign_id};
            delete $connections->{$id};
        });
        $stream->on(error => sub {
            my ($stream, $error) = @_;
            $log->debug("Error in $id: $error");
            Mojo::IOLoop->remove($connections->{$id}->{orign_id}) if $connections->{$id}->{orign_id};
            delete $connections->{$id};
        });
        $stream->on(read => sub {
            my ($stream, $chunk) = @_;
            my $chunk_qp = encode_qp $chunk, '';
            $connections->{$id}->{text_log}->debug("< $chunk_qp");
            $connections->{$id}->{bin_log}->add_chunk($chunk);
            $log->debug("Read data on $id: $chunk");
            my $ids_action = $ids->process_chunk($chunk);
            $log->debug("Action for this chunk is $ids_action");
            return if $ids_action eq 'drop';
            # Check for existsting connection
            if (my $orign = $connections->{$id}->{orign_id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    if (length $connections->{$id}->{temp_buffer}) {
                        $orign_stream->write($connections->{$id}->{temp_buffer});
                        $connections->{$id}->{temp_buffer} = '';
                        return;
                    }
                    return $orign_stream->write($chunk);
                }
                $connections->{$id}->{temp_buffer} .= $chunk;
                return;
            }
        });
        # Open new connection
        $log->debug("Connecting to $remote_addr:$remote_port");
        my $orign = Mojo::IOLoop->client({address => $remote_addr,
                                            port => $remote_port,
                                            timeout => 5*60 } => sub {
            my ($loop, $err, $stream) = @_;

            if ($err) {
                $log->warn("Error in $id: $err");
                return Mojo::IOLoop->stream($id)->close;
            }

            $stream->on(read => sub {
                my ($stream, $chunk) = @_;
                my $chunk_qp = encode_qp $chunk, '';
                $connections->{$id}->{text_log}->debug("> $chunk_qp");
                $connections->{$id}->{bin_log}->add_chunk($chunk);
                $log->debug("Read data from orign $id: $chunk");
                my $ids_action = $ids->process_chunk($chunk);
                $log->debug("Action for this chunk is $ids_action");
                return if $ids_action eq 'drop';
                Mojo::IOLoop->stream($id)->write($chunk);
            });
            $stream->on(timeout => sub {
                $log->debug("timeout: orign $id");
                Mojo::IOLoop->remove($id);
                delete $connections->{$id};
            });
            $stream->on(error => sub {
               my ($stream, $error) = @_;
               $log->debug("Error in orign $id while process $remote_addr:$remote_port: $error");
               Mojo::IOLoop->remove($id);
               delete $connections->{$id};
            });
            $stream->on(close => sub {
                $log->debug("Closed orign $id");
                Mojo::IOLoop->remove($id);
                delete $connections->{$id};
            });
            $log->debug("Connected to $remote_addr:$remote_port");
            if (length $connections->{$id}->{temp_buffer}) {
                    $stream->write($connections->{$id}->{temp_buffer});
                    $connections->{$id}->{temp_buffer} = '';
            }
        });
        my $text_log = Mojo::Log->new(path => File::Spec->catfile($dump_dir, $port, time."_$_$id.txt"));
        my $bin_log = Mojo::Asset::File->new(path => File::Spec->catfile($dump_dir, $port, time."_$_$id.bin"), cleanup => 0);
        $connections->{$id}->{orign_id} = $orign;
        $connections->{$id}->{text_log} = $text_log;
        $connections->{$id}->{bin_log} = $bin_log;
        $log->debug("Starting stream: $id");
    });
}

sub reload_rules
{
   $log->debug("Reload rules...\n");
   $ids->read_rules_dir($rules_dir);
}

Mojo::IOLoop->recurring(5 => \&reload_rules);
Mojo::IOLoop->start;
