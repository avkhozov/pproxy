package PProxy::IDS;

use PProxy::Rule;

use strict;
use warnings;

sub new {
    my ($type, $rules_dir) = @_;
    my $self = {};
    bless $self, $type;
    $self->read_rules_dir($rules_dir);
    return $self;
}

sub read_rules_dir {
    my ($self, $rules_dir) = @_;
    my @rules_files = <$rules_dir/*.rules>;
    $self->{rules} = [];
    for my $rules_file (@rules_files) {
        open Rules, '<', $rules_file;
        my @rules = <Rules>;
        @rules = grep {$_ !~ /^\s*$/} map {s/^\#.*//g; chomp; $_} @rules;
        for my $rule_string (@rules) {
            push @{$self->{rules}}, PProxy::Rule->new($rule_string);
        }
        close Rules;
    }
    print @{$self->{rules}}." rules added\n";
}

sub process_chunk {
    my ($self, $chunk) = @_;
    my @rules = @{$self->{rules}};
    my $alert = 0;
    for my $rule (@rules) {
        if ($rule->match($chunk)) {
            print $rule->{action}.' with msg '.(join ', ', @{$rule->{opt_msg}}).' on chunk '.$chunk."\n";
            my $action = $rule->{action};
            return 'drop' if $action eq 'drop';
            $alert = 1 if $action eq 'alert';
        }
    }
    return 'alert' if $alert;
    return 'none';
}

1;
