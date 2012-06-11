package PProxy::Rule;

use strict;
use warnings;

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
                    (?<key>\w+)
                    \s*:\s*
                    (?<negative>([\!]))?\s*
                    (?:
                        "(?<value>(\\\\|\\;|\\"|[^";\\])*?)"
                        |
                        (?<value>[^;]*?)
                    )
                    ;
                /x;
    my $opt = $+{opt};
    while ($opt =~ /$opt_re/g) {
        my ($key, $value, $negative) = ($+{key}, $+{value}, $+{negative});
        $value =~ s/(\\(.))/$2/g;
        if ($key eq 'content') {
            $value =~   s/
                        \|([0-9a-fA-F\s]+)\|
                        /my $data = join '', split ' ', $1; pack "H*", $data
                        /gex;
            push @{$self->{"opt_$key"}}, {negative => $negative, template => $value};
        } else {
            push @{$self->{"opt_$key"}}, $value;
        }
    }
}

1;
