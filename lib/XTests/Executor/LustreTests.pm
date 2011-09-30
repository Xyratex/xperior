#
#===============================================================================
#
#         FILE:  LustreTests.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/27/2011 11:47:51 PM
#     REVISION:  ---
#===============================================================================
package XTests::Executor::LustreTests;
use Moose;
use Data::Dumper;
use MooseX::Storage;
use Carp qw( confess cluck );

extends 'XTests::Executor::Base';

our $VERSION = '0.01';


sub execute{
 return 
        <<TAP
TAP version 13
1..1
not ok 1  # TODO not implemented 
---
message: 'Test engine for luste sanity is not implemented'
TAP

}





__PACKAGE__->meta->make_immutable;

1;

