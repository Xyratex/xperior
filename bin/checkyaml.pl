#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  checkyaml.pl
#
#        USAGE:  ./checkyaml.pl <options>
#
#  DESCRIPTION:  Check yaml files context with predefined schemas
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  05/05/2012 08:41:56 AM
#===============================================================================

=pod 

=head1 NAME

checkyaml.pl - program do check for yaml files for schemas. 
Check engine:http://rx.codesimply.com/, schemas are getting from Xperior C<data> dir

=head1 SYNOPSIS

    checkyaml.pl --dir=<directory> [--failonundef]

=head1 DESCRIPTION

Tool for check yaml files correctness. Based on L<Data::Rx library|http://rx.codesimply.com>.

=head1 OPTIONS


=over 12


=item --dir

Directory where placed target yaml files. These files will NOT be changed.

=item --failonundef
If set program exit with error code  9 if found yaml without field 'schema' or cannot find file defined in 'schema' field.

=back

=head1 EXIT CODES

=over 12

=item  0

All is ok

=item  9

No 'schema' field found in yaml document and option --failonundef set

=item 8

Data doesn't fit to schema

=back

=cut

##################### main
use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use Pod::Usage;
use File::Basename;
use English;
use Cwd qw(abs_path);

my $XPERIORBASEDIR; 
BEGIN {

    $XPERIORBASEDIR = dirname(Cwd::abs_path($PROGRAM_NAME));
    push @INC, "$XPERIORBASEDIR/../lib";

};

use Xperior::CheckConfig;
use Error qw(:try);
use Xperior::Xception;

$| = 1;

#process parameters
my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my ( $dir, $fuflag, $helpflag, $manflag );
GetOptions(
    "dir:s"       => \$dir,
    "failonundef!" => \$fuflag,
    "help!"        => \$helpflag,
    "man!"         => \$manflag,
);
pod2usage( -verbose => 1 ) if ( ($helpflag) || ($nopts) );

pod2usage( -verbose => 2 ) if ($manflag);

if ( ( not defined $dir ) || ( $dir eq '' ) ) {
    print "No directory with YAML files set!\n";
    pod2usage( -verbose => 1 );
    exit 1;
}
try {
    checkDir( $dir, $fuflag );
}
catch NoSchemaException with {
    exit 9;
}
catch CannotPassSchemaException with {
    exit 8;
}
catch Error with {
    ERROR "Unknow failure";
    exit 10;
}
finally {};

INFO "Completed!";

