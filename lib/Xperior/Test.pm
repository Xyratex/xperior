#
# GPL HEADER START
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 only,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License version 2 for more details (a copy is included
# in the LICENSE file that accompanied this code).
#
# You should have received a copy of the GNU General Public License
# version 2 along with this program; If not, see http://www.gnu.org/licenses
#
# Please  visit http://www.xyratex.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

Xperior::Test - Class implements Test abstraction.


=head1 DESCRIPTION

The class is used for describing tests and keep passive information for executors. Executor class use Test for get all information about test under execution.

=cut

package Xperior::Test;
use Moose;
use Data::Dumper;
#use MooseX::Storage;
use Log::Log4perl;

our $VERSION = '0.01';
#with Storage('format' => 'JSON', 'io' => 'File');


has 'testcfg'              => ( is => 'rw');
has 'groupcfg'             => ( is => 'rw');
has 'tap'                  => ( is => 'rw');
has 'results'              => ( is => 'rw');

sub init {
    my $self    = shift;
    $self->{'testcfg'}    = shift;
    $self->{'groupcfg'}   = shift;
}

=over

=item getName

returns name of a test. Name could be defined as I<name> in test descriptor. Test id is returned if I<name> is not defined.

=back

=cut

sub getName{
    my $self = shift;
    return $self->testcfg->{'name'} if (defined($self->testcfg->{'name'} ));
    return $self->testcfg->{'id'};
}

=over

=item getParamNames

return list of available parameters for test (from test description and group description considering inheritance ).

=back

=cut

sub getParamNames{
    my $self = shift;
    my @names;
    foreach my $n (keys %{$self->testcfg}){
        push @names, $n;
    }
    foreach my $n (keys %{$self->groupcfg}){
        push @names, $n;
    }
    #print Dumper \@names;
    return \@names;
}


=over

=item getParam

returns parameter value by name.
if given $compare parameter, returns the value

=back

=cut

sub getParam{
    my ($self, $name, $compare) = @_;

	my $value;

    if (defined($self->testcfg->{$name})) {
		$value = $self->testcfg->{$name};
	}
	elsif (defined($self->groupcfg->{$name})) {
		$value = $self->groupcfg->{$name};
	}

	$value = $value eq $compare if defined $compare;

    return $value;
}

=over

=item getTags

returns tags list for test. Tags list contains tags defined in test descriptor and also test group name.

=back

=cut

sub getTags{
    my $self=shift;
    my @tags;
    my $ts = $self->getParam('tags');
    if(defined($ts)){
        foreach my $t (split(/\s/,$ts)){
            push @tags, $t;
        }
    }
    push @tags, $self->getParam('groupname');
    return \@tags;
}

sub getGroupName{
    my $self=shift;
    return  $self->getParam('groupname');
}

=over

=item getDescription

returns text description for test

=back

=cut

sub getDescription{
my $self = shift;
my $td='none';
if(defined($self->testcfg->{'description'})){
        $td=$self->testcfg->{'description'};
}
return
"Test full name    : [".$self->getParam('groupname')."/".$self->getName."]\n".
"Group description : ".$self->groupcfg->{'description'}."\n".
"Test description  : ".$td."\n".
"Test group        : ".$self->getParam('groupname')."\n".
"Test name         : ".$self->getName."\n".
"Test tags         : ".join(',',@{$self->getTags})."\n";
}


sub clean{

}

__PACKAGE__->meta->make_immutable;

1;

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 only,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License version 2 for more details (a copy is included
in the LICENSE file that accompanied this code).

You should have received a copy of the GNU General Public License
version 2 along with this program; If not, see http://www.gnu.org/licenses



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

