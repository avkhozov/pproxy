use Test::More tests => 4;

use_ok('PProxy::Rule');
use_ok('PProxy');

my $test_rule = 'alert tcp any any -> any any (content:"test"; content: !"data";)';

my $o = PProxy::Rule->new($test_rule);
my $pproxy = PProxy->new();
is($pproxy->match("test", $o), 'alert', 'match is ok');
ok(!$pproxy->match("t_e-s_t", $o), 'match is ok');
