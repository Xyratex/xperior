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

Xperior::CheckConfig - Module for checking cluster configuration

=head1 DESCRIPTION

Check yaml files context with predefined schemas

=cut

package Xperior::CheckConfig;
use strict;
use warnings;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use YAML qw "Bless LoadFile Load";

#TODO Switch to ::Syck in future, not all yaml files read ok by Syck
use Carp;
use File::Basename;
use English;
use File::Find;
use Data::Rx;
use Error qw(:try);
use Xperior::Xception;

our @ISA;
our @EXPORT;
my $XPERIORBINDIR;

BEGIN {
    @ISA           = ("Exporter");
    @EXPORT        = qw(&checkDir);
    $XPERIORBINDIR = dirname( Cwd::abs_path($PROGRAM_NAME) );
    push @INC, "$XPERIORBINDIR/../lib";
}

sub doCheck {
    my ( $yfile, $fuflag ) = @_;

    DEBUG "Load data file [$yfile]";
    my $data = LoadFile($yfile)
      or confess "Cannot load file '$yfile'";

    my $sfile = $data->{'schema'};
    if ( ( !defined($sfile) ) or ( $sfile eq '' ) ) {
        if ($fuflag) {
            ERROR "No schema defined in yaml doc [$yfile], exiting with error";
            #exit 9;
            throw NoSchemaException;
        }
        WARN "No schema defined in yaml doc [$yfile], skip exiting";
        return 0;
    }
    $sfile = "$XPERIORBINDIR/../" . $data->{'schema'};
    my $rx = Data::Rx->new;

    DEBUG "Load schema [$sfile]";
    my ($schema_def) = LoadFile($sfile)
      or confess "Cannot load Rx schema file [$sfile]";

    DEBUG "Make schema";
    my $schema = $rx->make_schema($schema_def)
      or confess "Cannot make schema";

    DEBUG "Do check";

    my $res = $schema->check($data);

    if ( $res == 1 ) {
        INFO "File [$yfile] passed check,";
    }
    else {
        ERROR "File [$yfile] don't fit to schema [$sfile]:"
          . $schema->failure;
        #exit 8;
        throw CannotPassSchemaException
            ("File [$yfile] don't fit to schema [$sfile]");
    }
    return 1;
}

sub checkDir {
    my ( $ydir, $fuflag ) = @_;
    my @yamls;
    my $res = 0;
    find(
        sub {
            push( @yamls, $File::Find::name )
              if ( (/\.yaml$/) && ( !(/testenv\.yaml$/) ) );
        },
        $ydir
    );

    foreach my $file (@yamls) {
        $res = doCheck( $file, $fuflag ) + $res;
    }
    return $res;
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

