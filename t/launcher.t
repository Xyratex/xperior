#
#===============================================================================
#
#         FILE: launcher.t
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#===============================================================================
#!/usr/bin/perl -w
package launcher;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;


startup         _startup  => sub {
 Log::Log4perl->easy_init({level => $DEBUG});
};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################

test plan => 2, cExitCodes => sub {

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/pass'`;
    my $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,0,"pass exit code");

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/exita.*'`;
    my $resa = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($resa,0xc00,"exitafter exit code");


};

launcher->run_tests;
