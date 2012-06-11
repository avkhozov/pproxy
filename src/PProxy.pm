package PProxy;

sub new {
    bless {}, shift;
}

sub match {
    my ($self, $content, $rule) = @_;
    return if ref $rule->{opt_content} ne 'ARRAY';
    my @templates = @{$rule->{opt_content}};
    for (@templates) {
        my $template = $_->{template};
        return $rule->{action} if $content =~ /$template/;
    }
    return 0;
}

1;
