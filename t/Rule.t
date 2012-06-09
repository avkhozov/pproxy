use Test::More tests => 18;

use_ok('PProxy::Rule');

my $test_rule = 'alert tcp $EXTERNAL_NET any -> $HTTP_SERVERS $HTTP_PORTS (msg:"WEB-PHP directory.php arbitrary command attempt"; flow:to_server,established; uricontent:"/directory.php"; content:"dir="; content:"|3B|"; reference:bugtraq,4278; reference:cve,2002-0434; classtype:misc-attack; sid:1815; rev:4;)';

my $o = PProxy::Rule->new($test_rule);
is($o->{action}, 'alert', 'action is ok');
is($o->{proto}, 'tcp', 'proto is ok');
is($o->{src}, '$EXTERNAL_NET', 'src is ok');
is($o->{src_port}, 'any', 'src_port is ok');
is($o->{direction}, '->', 'direction is ok');
is($o->{dst}, '$HTTP_SERVERS', 'dst is ok');
is($o->{dst_port}, '$HTTP_PORTS', 'dst_port is ok');

is($o->{opt_msg}->[0], 'WEB-PHP directory.php arbitrary command attempt', 'opt_msg is ok');
is($o->{opt_flow}->[0], 'to_server,established', 'opt_flow is ok');
is($o->{opt_uricontent}->[0], '/directory.php', 'opt_uricontent is ok');
is($o->{opt_content}->[0], 'dir=', 'opt_content is ok');
is($o->{opt_content}->[1], '|3B|', 'opt_content is ok');
is($o->{opt_reference}->[0], 'bugtraq,4278', 'opt_reference is ok');
is($o->{opt_reference}->[1], 'cve,2002-0434', 'opt_reference is ok');
is($o->{opt_classtype}->[0], 'misc-attack', 'opt_classtype is ok');
is($o->{opt_sid}->[0], '1815', 'opt_sid is ok');
is($o->{opt_rev}->[0], '4', 'opt_rev is ok');
