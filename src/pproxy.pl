#!/usr/bin/perl -w

use strict;
use Mojo::IOLoop;
use Mojo::Log;
use Net::PcapWriter;
use PProxy::IDS;

my $conf = do 'pproxy.conf' or die 'Invalid configuration file';
my $log = Mojo::Log->new(path => $conf->{log});
my $pcap_file = $conf->{pcap} // 'data.pcap';
my $rules_dir = $conf->{rules} // 'rules';

my $lister = $conf->{listen};
my $proxy = $conf->{proxy};

my $connections = {};

open my $fh, '>', $pcap_file or die "Error on write to $pcap_file: $!";
my $old = select $fh; $|=1; select $old;
my $pcap_writer = Net::PcapWriter->new($fh);

my $ids = PProxy::IDS->new($rules_dir);

for my $port (keys %$proxy) {
    $log->info("Start listen on $port");
    my $remote_addr = $proxy->{$port}->{address};
    my $remote_port = $proxy->{$port}->{port};
    my $server = Mojo::IOLoop->server({port => $port} => sub {
        my ($loop, $stream, $id) = @_;
        $stream->on(close => sub {
            $log->debug("Closed $id");
            $connections->{$id}->{pcap_connection}->shutdown(0);
            undef $connections->{$id}->{pcap_connection};
            if (my $orign = $connections->{$id}->{orign_id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    $orign_stream->close;
                }
            }
            delete $connections->{$id};
        });
        $stream->on(error => sub {
            my ($stream, $error) = @_;
            $log->debug("Error in $id: $error");
            if (my $orign = $connections->{$id}->{orign_id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    $orign_stream->close;
                }
            }
        });
        $stream->on(read => sub {
            my ($stream, $chunk) = @_;
            $log->debug("Read data on $id: $chunk");
            my $ids_action = $ids->process_chunk($chunk);
            $log->debug("Action for this chunk is $ids_action");
            $connections->{$id}->{pcap_connection}->write(0, $chunk);
            $connections->{$id}->{pcap_connection}->ack(1);
            return if $ids_action eq 'drop';
            # Check for existsting connection
            if (my $orign = $connections->{$id}->{orign_id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    return $orign_stream->write($chunk);
                }
                return;
            }
            # Open new connection
            $log->debug("Connecting to $remote_addr:$remote_port");
            my $orign = Mojo::IOLoop->client({address => $remote_addr,
                                                port => $remote_port} => sub {
                my ($loop, $err, $stream) = @_;
                # Inactivity timeout for stream
                $stream->timeout(5 * 60);
                $stream->on(read => sub {
                    my ($stream, $chunk) = @_;
                    $log->debug("Read data from orign $id: $chunk");
                    my $ids_action = $ids->process_chunk($chunk);
                    $log->debug("Action for this chunk is $ids_action");
                    $connections->{$id}->{pcap_connection}->write(1, $chunk);
                    $connections->{$id}->{pcap_connection}->ack(0);
                    return if $ids_action eq 'drop';
                    Mojo::IOLoop->stream($id)->write($chunk);
                });
                $stream->on(timeout => sub {
                    $log->debug("timeout: orign $id");
                    Mojo::IOLoop->stream($id)->close;
                });
                $stream->on(error => sub {
                   my ($stream, $error) = @_;
                   $log->debug("Error in orign $id while process $remote_addr:$remote_port: $error");
                   Mojo::IOLoop->stream($id)->close;
                });
                $stream->on(close => sub {
                    $log->debug("Closed orign $id");
                    Mojo::IOLoop->stream($id)->close;
                });
                $log->debug("Connected to $remote_addr:$remote_port");
                $stream->write($chunk);
            });
            $connections->{$id}->{orign_id} = $orign;
        });
        $log->debug("Starting stream: $id");
        my $conn = $pcap_writer->tcp_conn($stream->handle->peerhost, $stream->handle->peerport, $remote_addr, $remote_port);
        $connections->{$id}->{pcap_connection} = $conn;
    });
}

Mojo::IOLoop->start;
