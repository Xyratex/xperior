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

Xperior::Executor::Base - Base executor class

=head1 DESCRIPTION

Base class for test. Keep all test parametes to field B<yaml> which
saved to Xprerior result files by b<report> call. Also could be stored
TAP report which have less information but more compatible with other tools.

Method B<execute> is extension poit for
L<Xperior::Executor::SingleProcessBase> and its inheritors.

It is possible to use http://instanttap.appspot.com/ for check tap outputs.

=head1 FUNCTIONS


=cut

package Xperior::Executor::Base;
use Moose;
use Data::Dumper;
#use YAML::Tiny;
use YAML;
#use YAML::Syck;
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;
use File::Slurp;
use Carp;

our $YVERSION = 'Xperior1'; #yaml output version. other modules also can add fields.
our $EXT  = '.yaml';
our $TEXT = '.tap';

has DEFAULT_POLL => ( is => 'ro', default => 5 );
has PASSED       => ( is => 'ro', default => 0 );
has SKIPPED      => ( is => 'ro', default => 1 );
has FAILED       => ( is => 'ro', default => 10 );
has NOTSET       => ( is => 'ro', default => 100 );    #also failed


has 'test'              => ( is => 'rw');
has 'options'           => ( is => 'rw');
has 'env'               => ( is => 'rw');
has 'result_code'       => ( is => 'rw');
has 'result'            => ( is => 'rw');
has 'yaml'              => ( is => 'rw');

has 'steptimeout'       => ( is => 'rw');#sec

#TODO probably needs to move to one class with execute implementation
has cmd                 => (is=>'rw');
has appname             => (is=>'rw');
has remote_out          => (is=>'rw');
has remote_err          => (is=>'rw');

has before_start_time => (is=>'rw', isa => 'HashRef[Int]');
has after_start_time => (is=>'rw', isa => 'HashRef[Int]');

sub init{
    my ($self, $test, $opt, $env) = @_;
    my %th;
    $self->yaml(\%th);
    $self->yaml->{'status'} = 'not set';
    $self->yaml->{'status_code'} = -1;
    $self->yaml->{'messages'}    = '';
    $self->yaml->{'schema'}    = $YVERSION;
    $self->yaml->{'fail_reason'} = '';

    $self->steptimeout(5);

    $self->{'test'} = $test;
    $self->{'options'} = $opt;
    $self->{'env'}     = $env;
    foreach my $k ( @{$test->getParamNames}){
        $self->addYE($k,$test->getParam($k));
    }
    $self->_write();
    $self->before_start_time ({});
    $self->after_start_time  ({});
}

=head2 addYE(KEY, VALUE)

Adds Yaml Element.

Returns 1 if the value has been overridden, otherwise returns 0.

=cut

sub addYE{
    my ($self, $key, $value) = @_;
    my $overridden = defined $self->yaml->{$key};
    $self->yaml->{$key} = $value ;
    $self->_write;
    return $overridden;
}

=head2 addYEE(KEY1, KEY2, VALUE)

Adds Yaml Element in Element. Means adding second level hash element.

Returns 1 if the value has been overridden, otherwise returns 0.

=cut

sub addYEE{
    my ($self, $key1, $key2, $value) = @_;
    my $overridden = (defined $self->yaml->{$key1} and
                      defined $self->yaml->{$key1}->{$key2});
    $self->yaml->{$key1}->{$key2} = $value ;
    $self->_write;
    return $overridden;
}

=head2 addMessage

Save message to tests. User for message frpm Xperior, e.g.
"Master client down". Saved in result yaml.

=cut

sub addMessage{
    my ($self,$data) = @_;
    $self->yaml->{'messages'} = $self->yaml->{'messages'}
                                    . $data."\n";
    $self->_write;
}

=head2 pass

Set test passed.

=cut

sub pass{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->{'result'} ="ok 1 $msg";
    $self->{'result_code'} = 0;
    $self->yaml->{'status'} = 'passed';
    $self->yaml->{'status_code'} = 0;
    $self->_write;
}

=head2 fail

Set test failed.

=cut

sub fail{
    my ($self,$msg)  = @_;
    my $pmsg = $msg;
    if((defined $msg) and ($msg ne '')){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->{'result'} ="not ok 1 $msg" ;
    $self->{'result_code'} = 1;
    $self->yaml->{'status'} = 'failed';
    $self->yaml->{'status_code'} = 1;
    $self->yaml->{'fail_reason'} = $pmsg;
    $self->_write;
}

=head2 skip

Set test skipped

=cut

sub skip{
    #mode means type of skip - skip may
    # be acc-sm induced or exclude list induced
    my ($self,$mode,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->{'result'} ="ok 1# SKIP $msg" ;
    $self->{'result_code'} = 2;
    $self->yaml->{'status'} = 'skipped';
    $self->yaml->{'status_code'} = 2;
    $self->yaml->{'fail_reason'} = $msg;
    $self->_write;
}

=head2 setExtOpt(KEY, VALUE)

Set additional fied to yaml in special section B<extoptions>. Use it
for adding meta-information to test result.

=cut

sub setExtOpt{
    my ($self,$key,$value) = @_;
    $self->addYEE('extoptions',$key,$value)
        and DEBUG "Overridden YAML key [extoptions/$key] with value [$value]";
}

sub registerLogFile{
    my ($self,$key,$path)  = @_;
    my $rd=$self->_reportDir.'/';
    $path =~ s/$rd//;
    $self->addYEE('log',$key,$path);
}

#TODO add tests!
sub normalizeLogPlace{
    my ($self,$lfile,$key)  = @_;
    move "$lfile",
            $self->_resourceFilePrefix."$key.log";
}

sub getNormalizedLogName{
    my ($self,$key)  = @_;
    $self->_createDir;
    return $self->_resourceFilePrefix."$key.log";
}

sub createLogFile{
    my ($self,$key)  = @_;
    my $file = $self->_resourceFilePrefix."$key.log";

    $self->_createDir;
    my $fd;
    open $fd, "> $file"  or confess "Cannot log  file[$file]:" . $!;
    $self->registerLogFile($key,$file);
    return $fd;
}

sub writeLogFile{
    my ($self,$key, $data)  = @_;
    my $file = $self->_resourceFilePrefix."$key.log";
    $self->_createDir;
    my $res = write_file ($file,$data);
    if($res != 1){
        ERROR "Cannot log  file[$file]";
        return 0;
    }
    $self->registerLogFile($key,$file);
    return $res;
}


=head2 tap

Write TAP report for B<$self-E<gt>yaml>

=cut

sub tap{
    my $self = shift;
    $self->addYE('result',$self->result);
    my %tapy;
    $tapy{'extensions'}=$self->yaml;
    $tapy{'datetime'}  =$self->yaml->{'starttime'};
    $tapy{'source'}    =$self->yaml->{'groupname'}.
                            $self->yaml->{'id'};
    $tapy{'message'}   =$self->yaml->{'messages'};
    my $yamlt = Dump(\%tapy);
    #well-from dumped yaml to tap yaml
    my $yaml = '';
    foreach my $s( split(/\n/,$yamlt)){
        if( $s =~ m/---$/ ){
            $yaml = "$yaml$s\n";
        }else{
            $yaml = "$yaml   $s\n";
        }
    }
    my $out=
        "TAP version 13\n".
        "1..1\n".
        $self->result."\n".
        $yaml.
        "...\n";
     my $file = $self->_tapFile;
     $self->_createDir;
     open  TAP, "> $file" or confess "Cannot open report file:" . $!;
     print TAP $out;
     close TAP;
     return $out;
}

=head2 report

Write B<$self-E<gt>yaml> to yaml file in work directory

=cut

sub report{
     my $self = shift;
     $self->addYE('result',     $self->result);
     $self->addYE('result_code',$self->result_code);
     $self->_write;
}

=head2 execute()

Stub of execute test function.

Should be implemented in child classes.

=cut

sub execute{
    confess 'Functions is not implemented, override it!';
}

=head2 getReason()

Stub of getReason function.

Should be implemented in child classes.
Should return short failure reason description.

=cut

sub getReason{
    return "Non-zero exit code";
}

=head2 beforeBeforeExecute($title)

Roles debug helper for using together with B<afterBeforeExecute>.
Save time per role and report it  in  call B<afterBeforeExecute>.

Parameters:
 * title - key for separating one role from another

Example

    my $title = 'roleX'

    before 'execute' => sub {
        my $self = shift;
        $self->beforeBeforeExecute($title);
        .... some code ...
        $self->afterBeforeExecute($title);
    };


=cut

sub beforeBeforeExecute{
    my $self = shift;
    my $title = shift;
    my $time = time();
    confess 'Base is not initialized'
        unless (defined( $self->before_start_time()));
    $self->before_start_time->{'title'}=$time;
    DEBUG "BEFORE[beforeExecute]:".$title."[$time]";
};

=head2 afterBeforeExecute($title)

See B<beforeBeforeExecute($title)>

=cut

sub afterBeforeExecute {
    my $self = shift;
    my $title = shift;
    my $time = time();
    DEBUG "AFTER[beforeExecute]:"
        .$title.
        "[$time], elapsed [".
        ($time-$self->before_start_time->{'title'})."]";
    $self->before_start_time->{'title'}=0;
};

=head2 beforeAfterExecute($title)

Roles debug helper for using together with B<beforeAfterExecute>.
Save time per role and report it  in  call B<afterAfterExecute>.

Parameters:
 * title - key for separating one role from another

Example

    my $title = 'roleX'

    before 'execute' => sub {
        my $self = shift;
        $self->beforeAfterExecute($title);
        .... some code ...
        $self->afterAfterExecute($title);
    };


=cut

sub beforeAfterExecute{
    my $self = shift;
    my $title = shift;
    my $time = time();
    $self->after_start_time->{'title'}=$time;
    DEBUG "BEFORE[afterExecute]:".$title."[$time]";
};

=head2 afterAfterExecute($title)

See B<beforeAfterExecute($title)>

=cut

sub afterAfterExecute{
    my $self = shift;
    my $title = shift;
    my $time = time();
    DEBUG "AFTER[afterExecute]:"
        .$title."[$time], elapsed [".
        ($time-$self->after_start_time->{'title'})."]";
    $self->after_start_time->{'title'}=0;
};

sub _write{
     my $self = shift;
     my $file = $self->_reportFile;
     $self->_createDir;
     $YAML::Stringify = 1;
#$YAML::Syck::ImplicitTyping =1;
#     $YAML::Syck::SingleQuote = 1;
#     $YAML::XS::QuoteNumericStrings=0;
     open REP, "> $file" or confess "Cannot open report file:" . $!;
     print REP Dump($self->yaml);
     close REP;
}


sub _createDir{
    my $self = shift;
    if ( ! -d $self->_reportDir){
        mkpath ($self->_reportDir);
    }
}

sub _reportDir{
    my $self = shift;
    return $self->options->{'workdir'}.'/'.
           $self->test->getParam('groupname');
}

sub _reportFile{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getId().$EXT;
}

sub _tapFile{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getId().$TEXT;
}

sub _getLog {
    my ( $self, $connector, $logfile, $logname ) = @_;

    my $res =
      $connector->getFile( $logfile, $self->getNormalizedLogName($logname) );
    if ( $res == 0 ) {
        $self->registerLogFile( $logname,
            $self->getNormalizedLogName($logname) );
    }
    else {
        $self->addMessage( "Cannot copy log file [$logfile]: $res" );
    }
    return $res;
}



#TODO add test
sub _resourceFilePrefix{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getId().'.';

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

