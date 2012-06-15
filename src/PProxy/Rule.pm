package PProxy::Rule;

use strict;
use warnings;
use Data::Dumper;

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
                        (?<src>[\!\w_\.\$]+)\s+
                        (?<src_port>[\!\w_\$\[\]\,\:]+)\s+
                        (?<direction>[<>-]{1,2})\s+
                        (?<dst>[\!\w_\.\$]+)\s+
                        (?<dst_port>[\!\w_\$\[\]\,\:]+)\s+
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
        my ($key, $value, $negative) = @+{'key', 'value', 'negative'};
        $value =~ s/(\\(.))/$2/g;
        if ($key eq 'content' || $key eq 'pcre') {
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

sub match
{
    my ($self, $chunk) = @_;
    if (ref $self->{opt_content} eq 'ARRAY') {
        my @templates = @{$self->{opt_content}};
        for (@templates) {
            my $template = $_->{template};
            if ($_->{negative}) {
                return 0 if index($chunk, $template) >= 0;
            } else {
                return 0 if index($chunk, $template) == -1;
            }
        }
    }
    
    if (ref $self->{opt_pcre} eq 'ARRAY') {
        my @templates = @{$self->{opt_pcre}};
        for (@templates) {
            my $template = $_->{template};
            if ($_->{negative}) {
                return 0 if $chunk =~ /$template/;
            } else {
                return 0 if $chunk !~ /$template/;
            }
        }
    }


    local $, = ' ';
    local $\ = $/;
    Dumper $self;
    return 1;
}

1;
