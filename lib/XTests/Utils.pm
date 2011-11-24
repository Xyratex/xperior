#
#===============================================================================
#
#         FILE:  Xtests/Utils.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/05/2011 03:55:22 PM
#     REVISION:  ---
#===============================================================================
package XTests::Utils;
use strict;
use warnings;

use LWP;
use Carp;
use Log::Log4perl qw(:easy);
use Cwd qw(chdir);
use File::chdir;
use File::Path;


our @ISA = ("Exporter");
our @EXPORT = qw(&trim &runEx);

sub trim{
   my $string = shift;
   if(defined( $string)){
        $string =~ s/^\s+|\s+$//g;
   }
   return $string;
}


sub runEx{
    my ($cmd, $dieOnFail,$failMess ) = @_;    
    DEBUG "Cmd is [$cmd]";
    DEBUG "WD  is [$CWD]";

    $dieOnFail = 0 if ( !( defined $dieOnFail ) );

    my $error_code = system($cmd);

    if ( ( $error_code != 0 ) and ( $dieOnFail == 1 ) ) {
        confess "Child process failed with error status $error_code";
    }

    INFO "Return code is:[" . $error_code . "]";
    return $error_code;
}
1;

