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
package Xtests::Utils;
use strict;
use warnings;

use LWP;
use Carp;

our @ISA = ("Exporter");
our @EXPORT = qw(&log);

