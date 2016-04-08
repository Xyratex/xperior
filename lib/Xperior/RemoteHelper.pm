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
# Copyright 2015 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::RemoteHelper - Utility functions for work with remote
nodes, e.g. logs collection

=head1 FUNCTIONS


=cut


package Xperior::RemoteHelper;
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Basename;
use Xperior::Utils;

our @ISA = ("Exporter");
our @EXPORT = qw(&collect_remote_files_by_mask);



=head2  collect_remote_files_by_mask

Collect files by mask for 'find' untility and attach them
to the executor.

Parameters:
  * $node     - Xperior::Node or child , obj which defines node for
                files collecton

  * $executor - Xperior::Executor::Base or child, which used for
                attaching files
  * @files    - array of string likes this
                    [ '/var/logs/mero-.*\.log',
                      '/qqq/www/.*']
  * @names    - optional, array of strings, contains file names which
                will be used for corrrespodning  files for attaching to
                test result. Names should be in same order as @files.

Return : number of attached logs

Testing via t/roleCustomLogCollector.t

=cut

sub collect_remote_files_by_mask {
    my ( $node, $executor, $files, $names ) = @_;
    my $id   = $node->id;
    my $count = 0;
    foreach my $log ( @{$files} ) {
        DEBUG "Collect [$log] on [$id]";
        my $c = $node->getRemoteConnector();
        my $cmd = "find $log -type f -print";

        #DEBUG $cmd;
        my $resc = $c->run( $cmd, timeout => 30 );
        my $lsout = trim( $resc->{stdout} );
        DEBUG 'list out:' . $lsout;
        my $minpath;
        foreach my $file ( split( /\n/, $lsout ) ) {
            next if ( ( $file eq '' ) or ( $file =~ m/^\s+/ ) );
            my ( $filename, $dirs, $suffix ) = fileparse("$file.$id");
            if ( !$minpath ) {
                $minpath = $dirs;
                next;
            }
            if ( length($dirs) < length($minpath) ) {
                $minpath = $dirs;
            }
        }
        if ( !$minpath ) {
            DEBUG "No dirs found on non-empty out";
            next;
        }

        #DEBUG "Minimal path is [$minpath]";
        my $i=0;
        foreach my $file ( split( /\n/, $lsout ) ) {
            DEBUG "Check line [$file]";
            next if ( ( $file eq '' ) or ( $file =~ m/^\s+/ ) );
            INFO "Attaching log file [$file]";
            my ( $filename, $dirs, $suffix ) = fileparse("$file.$id");
            if( $names and $names->[$i] ){
                $filename = $names->[$i];
            }else{
                if ( $dirs ne $minpath ) {
                    $dirs =~ m/$minpath(.*)\//;
                    my $subpath = $1;
                    #DEBUG "Subpass is [$subpath]";
                    $subpath =~ s/\//_/g;
                    $filename = "${subpath}_${filename}";
                }
            }

            $executor->_getLog( $c, $file, $filename );
            $count++;
        }
    }
    return $count;
}

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



Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

