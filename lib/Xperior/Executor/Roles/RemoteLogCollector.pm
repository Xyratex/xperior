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
# Copyright 2016 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::RemoteLogCollector - Role implemnts harvesting
logs from remote places which defined in system configuration

=head1 DESCRIPTION

Logs collected based on node definition in array 'collect' under node.
For every node should be defined separatelly.

    Nodes:
       - id           : oss1
         ....
         collect:
            - name : conman
                # mandatory
                # used as name of log for attaching to test
              file : /tmp/conman_log
                # mandatory
                # fail for observing and collecting
              full_on_fail :
                # mandatory
                # 1(or perl true) if full log should be collected in fail case
              node :
                # optional
                # host name or ip
              user :
                # mandatory
                # user with enbaled passwordless access

Example:

    Nodes:
       - id           : oss1
         ip           : 1.2.3.4
         ctrlproto    : ssh
         user         : admin
         collect:
            - name : syslog
              node : 1.2.3.10
              user : tomcat
              file : /tmp/syslog_log
              # correct, log will be collected via tail
            - name : conman
              file : /tmp/conman_log
              full_on_fail : 1
              node : 1.2.3.11
              user : tomcat
              #correct, if test failed full log will be downloaded
            - name : conman1
              file : /tmp/conman1_log
             #incorrect, no host set


Logs will not be collected in  node crash case.

=cut

package Xperior::Executor::Roles::RemoteLogCollector;

use Moose::Role;
#it is needed for coverage calculation
#use MooseX::CoverableModifiers;
use Time::HiRes;
use Xperior::Utils;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Basename;
use Xperior::RemoteHelper;
use Xperior::Node;
our $VERSION = "0.0.2";

requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

#has conman_file_name   => ( is => 'rw', default => '');
has remote_collector_procs  => ( is => 'rw', isa => 'HashRef' );
has logs                    => ( is => 'rw', isa => 'HashRef' );
has nodes                   => ( is => 'rw', isa => 'HashRef' );
has items                   => ( is => 'rw', isa => 'HashRef' );
has keep_lines              => ( is => 'rw', default => 100);

my $title = 'NodeLogCollector';


before 'execute' => sub{
    my $self    = shift;
    $self->beforeBeforeExecute($title);
    my (%h, %l, %n, %i);
    $self->remote_collector_procs(\%h);
    $self->logs(\%l);
    $self->nodes(\%n);
    $self->items(\%i);

    foreach my $n ( @{ $self->env->nodes } ) {
        DEBUG Dumper  $n;
        my $id = $n->id;
        if(defined $n->_node->{collect}){
            foreach my $c (@{$n->_node->{collect}}){
                my $name = $c->{name};
                my $node = $c->{node};
                my $user = $c->{user};
                my $file = $c->{file};

                if( not ( defined $name and
                          defined $node and
                          defined $user and
                          defined $file )
                                    ){
                    $self->addMessage(
                        "Not all paramaters defined for ".
                        "'collect' for[$name/".$n->id."]");
                    next;
                }
                my $log    = "/tmp/xperior_$name.".$n->id.".".time;
                DEBUG "****************************";
                DEBUG Dumper $c;
                #start log collection
                my $sp =  Xperior::SshProcess->new();
                $sp->init($node,$user);
                my $r = $sp->create("${id}_${name}",
                    "tail -f -n ".$self->keep_lines()
                    ." -v  $file 2>&1 > $log");
                my $al = $sp->isAlive();
                if( $r != 0  or $al != 0 ){
                    INFO "Cannot start collection for '$id:$name'";
                    $self->addMessage(
                        "Collection of '$file' for record [$name] ".
                        "failed with exit code ".$sp->exitcode);
                    next;
                }
                $self->remote_collector_procs->{"${id}_$name"} = $sp;
                $self->logs->{"${id}_$name"}  = $log;
                $self->nodes->{"${id}_$name"} = $n->_node();
                $self->items->{"${id}_$name"} = $c;
                DEBUG "Started log collection for $id:$name";
            }
        }else{
            DEBUG "No 'collect' defined for node [".$n->id."]";
        }
    }
    $self->afterAfterExecute($title);
};

after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    foreach my $k (keys %{$self->remote_collector_procs()}){
        my $proc    = $self->remote_collector_procs()->{$k};
        my $rfile   = $self->logs()->{$k};
        my $n       = $self->nodes()->{$k};
        my $i       = $self->items()->{$k};
        my $lcorename = $i->{name}.'.'.$n->{id};
        my $lfile   = $self->getNormalizedLogName($lcorename);
        $proc->kill();
        if( $i->{full_on_fail} and $self->yaml->{status_code} == 1 ){
            #get full log
            DEBUG "Get full log for $i->{name}";
            my $node = Xperior::Node->new(
                user => $i->{user},
                ip   => $i->{node},
                id   => $i->{name}
            );
            my @files  = ($i->{file});
            my @lfiles = ($lcorename);
            collect_remote_files_by_mask($node,$self,\@files,\@lfiles);
        }else{
            #get only tailed log
            my $scpres  = $proc->getFile($rfile, $lfile);
            if ($scpres == 0){
                $self->registerLogFile($lfile,$lfile);
                $self->processSystemLog($proc,$lfile);
            }else{
                $self->addMessage(
                    "Cannot copy log file [".$rfile."]: $scpres");
            }

        }
    }
    $self->afterAfterExecute($title);
};

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



Copyright 2016 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut


