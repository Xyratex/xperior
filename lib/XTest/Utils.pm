#===============================================================================
#
#         FILE:  Xtest/Utils.pm
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex 
#      CREATED:  09/05/2011 03:55:22 PM
#===============================================================================
package XTest::Utils;
use strict;
use warnings;

use LWP;
use Carp;
use Log::Log4perl qw(:easy);
use Cwd qw(chdir);
use File::chdir;
use File::Path;
use File::Find;
use Data::Dumper;

our @ISA = ("Exporter");
our @EXPORT = qw(&trim &runEx &parseIEFile &compareIE &getExecutedTestsFromWD);

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

    my $st = time;
    my $error_code = system($cmd);
    my $time = time - $st;

    DEBUG "Execution time = $time sec";
    if ( ( $error_code != 0 ) and ( $dieOnFail == 1 ) ) {
        confess "Child process failed with error status $error_code";
    }

    INFO "Return code is:[" . $error_code . "]";
    return $error_code;
}

sub parseIEFile{
    my $file = shift;
    DEBUG "Parse [$file] as include/exclude list";
    open(F,"< $file") or confess "Cannot open file: $file";
    my @onlyvalues;
    while(<F>){
        my $str=$_;
        chomp $str;
        my @nocomment = split (/#/,$str);
        next unless defined $nocomment[0];
        $nocomment[0] = trim( $nocomment[0]) if defined $nocomment[0];
        confess "Cannot parse file, space found on string [$str]:[".$nocomment[0]."]" 
            if $nocomment[0] =~ m/\s+/ ;
        push(@onlyvalues, $nocomment[0]) if $nocomment[0] ne '';
    }
    close F;
    return \@onlyvalues;
}

# 0 - different values
# 1 - match
sub compareIE{
    my ($template, $value) =@_;
    $template = trim $template;
    #DEBUG "Compare for exclusion/inclusion: [$template] and [$value]";
    return 1 if( $value =~ m/^$template$/);
    #DEBUG "Negative comparing result";
    return 0;
}


sub  getExecutedTestsFromWD{
    my $wd = shift;
    my @testlist;
    return \@testlist  unless -d $wd;
    find sub {
        my $file = $_;
        my $path =  $File::Find::name;
        $path =~ s/^$wd//;
        $path =~ s/^\///;
        push (@testlist, $path) unless ( -d $file); }, 
        $wd; 
    #DEBUG Dumper \@testlist;
    return \@testlist;
}

1;

