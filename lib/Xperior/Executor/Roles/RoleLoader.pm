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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::RoleLoader - define activation order for roles.
TODO add more description

=head1 DESCRIPTION


=cut
package Xperior::Executor::Roles::RoleLoader;
use strict;
use warnings;
use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Carp;
use Xperior::Utils;

has default_weight => (is=>'ro', isa=>'Int', default => 50 );
has weights => (is=>'rw', isa=>'HashRef', builder => '_build_weights' );
has allow_local_load => (is=>'rw','default'=>1);

sub _build_weights{
    return{
        'ReformatBefore'      => 1,
        'GetDiagnostics'      => 80,
        'StoreConsole'        => 98,
        'NetconsoleCollector' => 98,
        'StoreSyslog'         => 90,
        'StacktraceGenerator' => 50,
    }
}
sub getWeight{
    my ($self,$role) = @_;
    return $self->weights()->{$role} if defined $self->weights()->{$role};
    return   $self->default_weight();
}

sub initRole{
    my ($self, $exe, $test) = @_;
    DEBUG Dumper $test;
    foreach my $pname (@{$test->getParamNames()}){
        DEBUG $pname;
        $exe->{$pname} = $test->getParam($pname);
    }
    DEBUG Dumper $exe;
}

sub applyRoles{
    my ($self,$exe,$test,@roles) = @_;
    my @sorted_roles = sort
                        {$self->getWeight($a) cmp $self->getWeight($b)}
                            @roles;
    foreach my $role (@sorted_roles) {
        INFO "Applying role [$role]";
        my $module = "Xperior::Executor::Roles::$role";
        DEBUG "Try to  module [$module]";
        eval "require $module";
        if($@){
            WARN "Cannot load [$module]";
            if($self->allow_local_load()){
                INFO "Try to load module [$role]";
                $module = "$role";
                eval "require $module";
                if($@){
                    confess "Cannot load [$module], cannot continue, $@";
                }
            }else{
                confess "Cannot continue, possile ".
                    "'allow_local_load' should be switched on";
            }
        }
        $module->meta->apply($exe);
        $self->initRole($exe, $test);
        INFO "Role [$module] applied successfully";
    }
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



Copyright 2014 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut
