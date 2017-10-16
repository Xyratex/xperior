package test_EC2Node;
use strict;
use warnings FATAL => 'all';


use strict;
use warnings;
use Test::Class::Moose;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Log::Log4perl qw(:easy);
use File::Slurp;

use Xperior::Nodes::EC2Node;

sub test_setup {
    my $test = shift;
    $test->next::method;


    Log::Log4perl->easy_init($DEBUG);

    # more setup
    #remove_tree('/tmp/test_wd');
}


#
# node preventive should be started/alive
#
sub test_alive_stop_start {
    my $objn = Xperior::Node->new(
        user       => 'centos',
        id         => 'awstest',
        ip         => '0.0.0.0',
        cert       => '/home/ryg/work/xyratex/keys/aws-robot/robot.pem',
        nodetype   => 'EC2Node',
        instance   => 'X-XXXXXXXXXXXXXXXXX',
        access_key => 'XXXXXXXXXXXXXXXXXXXX',
        secret_key => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    );

    my $s_res = $objn->start();
    DEBUG "start res:". $s_res;
    is($s_res, 1, "Instance is started");
    $objn->waitUp(60);
    my $isa1 = $objn->isAlive();
    is($isa1,1, "Instance is up and ssh-ed");

    DEBUG "Detected pub  ip:". $objn->public_ip();
    DEBUG "Detected prvt ip:". $objn->private_ip();
    DEBUG "isAlive res:". $isa1;

    my $h_res = $objn->halt();
    DEBUG "halt res:". $isa1;
    isnt($h_res,0, "Send stop request");
    $objn->waitDown(60);
    my $isa2 = $objn->isAlive();
    #DEBUG "Detected pub  ip after stop :". $objn->public_ip();
    #DEBUG "Detected prvt ip after stop :". $objn->private_ip();
    DEBUG "isAlive 2 res:". $isa2;
    is($isa2,0, "Instance is fully stopped");



}

1;
