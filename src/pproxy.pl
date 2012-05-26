#!/usr/bin/perl -w

use strict;
use Mojo::IOLoop;
use Net::PcapWriter;

my $conf = do 'pproxy.conf';

my $lister = $conf->{listen};
my $proxy = $conf->{proxy};

my $connections = {};

for my $port (keys %$proxy) {
    print "Listen on $port\n";
    my $server = Mojo::IOLoop->server({port => $port} => sub {
        my ($loop, $stream, $id) = @_;
        $stream->on(close => sub {
            1;
        });
        $stream->on(error => sub {
            2;
        });
        $stream->on(read => sub {
            my ($stream, $chunk) = @_;
            my $handle = $stream->handle;
            if (my $orign = $connections->{$id}) {
                return Mojo::IOLoop->stream($orign)->write($chunk);
            }
            my $orign = Mojo::IOLoop->client({address => $proxy->{$port}->{address},
                                                port => $proxy->{$port}->{port}} => sub {
                my ($loop, $err, $stream) = @_;
                $stream->on(read => sub {
                    my ($stream, $chunk) = @_;

                });
                $stream->write($chunk);
            });
            $connections->{$id} = $orign;
        });
    });
}

Mojo::IOLoop->start;
