#!/usr/bin/perl -w

use strict;
use Mojo::IOLoop;
use Mojo::Log;
use Net::PcapWriter;

my $conf = do 'pproxy.conf';
my $log = Mojo::Log->new;

my $lister = $conf->{listen};
my $proxy = $conf->{proxy};

my $connections = {};

for my $port (keys %$proxy) {
    $log->info("Start listen on $port");
    my $server = Mojo::IOLoop->server({port => $port} => sub {
        my ($loop, $stream, $id) = @_;
        $stream->on(close => sub {
            $log->debug("Closed $id");
            if (my $orign = $connections->{$id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    return $orign_stream->close;
                }
            }
        });
        $stream->on(error => sub {
            my ($stream, $error) = @_;
            if (my $orign = $connections->{$id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    return $orign_stream->close;
                }
            }
        });
        $stream->on(read => sub {
            my ($stream, $chunk) = @_;
            $log->debug("Read data on $id: $chunk");
            if (my $orign = $connections->{$id}) {
                if (my $orign_stream = Mojo::IOLoop->stream($orign)) {
                    return $orign_stream->write($chunk);
                }
                return;
            }
            my $remote_addr = $proxy->{$port}->{address};
            my $remote_port = $proxy->{$port}->{port};
            $log->debug("Connecting to $remote_addr:$remote_port");
            my $orign = Mojo::IOLoop->client({address => $remote_addr,
                                                port => $remote_port} => sub {
                my ($loop, $err, $stream) = @_;
                $stream->on(read => sub {
                    my ($stream, $chunk) = @_;
                    $log->debug("Read data from orign $id: $chunk");
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
            $connections->{$id} = $orign;
        });
        $log->debug("Starting stream: $id");
    });
}

Mojo::IOLoop->start;
