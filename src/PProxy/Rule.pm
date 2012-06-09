package PProxy::Rule;

use strict;

sub new {
    my ($type, $rule_string) = @_;
    my $self = {};
    bless $self, $type;
    $self->_parse($rule_string);
    return $self;
}

sub _parse {
    my ($self, $rule_string) = @_;
    $rule_string =~ /
                        ^\s*
                        (?<action>\w+)\s+
                        (?<proto>\w+)\s+
                        (?<src>[\w\$]+)\s+
                        (?<src_port>[\w\$]+)\s+
                        (?<direction>[<>-]{1,2})\s+
                        (?<dst>[\w\$]+)\s+
                        (?<dst_port>[\w\$]+)\s+
                        \((?<opt>.*)\)
                        \s*$
                    /x;
    $self->{$_} = $+{$_} for (qw/action proto src src_port direction dst dst_port/);
    my $opt_re = qr/
                    \s*
                    (?<key>\w+)
                    \s*:s*
                    (?:
                        "(?<value>[^"]*?)"
                        |
                        '(?<value>[^']*?)'
                        |
                        (?<value>[^;]*)
                    )
                    \s*;
                /x;
    my $opt = $+{opt};
    while ($opt =~ /$opt_re/g) {
        push @{$self->{'opt_' . $+{key}}}, $+{value};
    }
}

1;
