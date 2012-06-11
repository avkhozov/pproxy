use Test::More tests => 6;

use_ok('PProxy::Rule');

my $test_rule = 'alert tcp any any -> any any (content:"test"; content:"a\\\\b\\;c\\"d"; content:"|5C 00|P|00|I|00|P|00|E|00 5C 00 00 00|"; content:!"qw\\;er";)';

my $o = PProxy::Rule->new($test_rule);
is($o->{opt_content}->[0]->{template}, 'test', 'opt_content is ok');
is($o->{opt_content}->[1]->{template}, 'a\\b;c"d', 'opt_content is ok');
is($o->{opt_content}->[2]->{template}, pack('H*', '5c0050004900500045005c000000'), 'opt_content is ok');

ok($o->{opt_content}->[3]->{negative}, 'opt_content negative is ok');
is($o->{opt_content}->[3]->{template}, 'qw;er', 'opt_content is ok');
