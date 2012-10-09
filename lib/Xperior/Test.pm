#
#===============================================================================
#
#         FILE:  Xperior/Test.pm
#
#  DESCRIPTION:  Class implement Test abstraction
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex 
#      CREATED:  08/30/2011 11:49:56 PM
#===============================================================================

=pod

=head1 Class implements Test abstraction.

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
