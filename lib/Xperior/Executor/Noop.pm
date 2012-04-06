#
#===============================================================================
#
#         FILE:  Noop.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/28/2011 11:09:03 PM
#     REVISION:  ---
#===============================================================================
package Xperior::Executor::Noop;
use Moose;
extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = '0.01';


sub execute{
    my $self = shift;
    my $id = $self->test->getParam('id');
    $self->fail;
    $self->addYE('testid',$id);
    $self->addYE('message','Noop engine, empty test');
my $ml = <<ML
Qwerty
Asdfg
Zxcvb
ML
;
    $self->addYE('multiline1',$ml);
    $self->addYE('multiline2',"qwerty\n"."asdfgh\n\nzxcvbn");
    $self->pass;
    $self->test->results ($self->yaml);

}

1;


