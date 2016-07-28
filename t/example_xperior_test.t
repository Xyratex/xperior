use strict;
use warnings;

use Test::Class::Moose::Load 't/classes';
use Test::Class::Moose::Runner;
Test::Class::Moose::Runner->new(
    #{include => qr/check_collection/,}
        )->runtests;
