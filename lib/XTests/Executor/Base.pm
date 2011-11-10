#
#===============================================================================
#
#         FILE:  Base.pm
#
#  DESCRIPTION:  Base class for execute tests 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex 
#      VERSION:  1.0
#      CREATED:  09/30/2011 01:31:34 AM
#===============================================================================
package XTests::Executor::Base;
use Moose;
use Data::Dumper;
use YAML::Tiny;
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;

use XTests::SshProcess;

our $EXT = '.yaml';
has 'test'              => ( is => 'rw');
has 'options'           => ( is => 'rw');
has 'env'               => ( is => 'rw');
has 'result_code'       => ( is => 'rw');
has 'result'            => ( is => 'rw');
has 'yaml'              => ( is => 'rw');

has 'steptimeout'       => ( is => 'rw');#sec

#TODO looks like nee t move to one class with execute
has cmd                 => (is=>'rw');
has appname             => (is=>'rw');
has remote_out          => (is=>'rw');
has remote_err          => (is=>'rw');

sub init{
    my ($self, $test, $opt, $env) = @_;
    
    $self->steptimeout(5);

    $self->{'test'} = $test;
    $self->{'options'} = $opt;
    $self->{'env'}     = $env;
    foreach my $k ( @{$test->getParamNames}){
        $self->addYE($k,$test->getParam($k));
    }
}

sub addYE{
    my ($self, $key, $value) = @_;
    $self->{'yaml'}->{$key} = $value ;
}

sub addYEE{
    my ($self, $key1, $key2, $value) = @_;
    $self->{'yaml'}->{$key1}->{$key2} = $value ;
}

sub pass{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg 
    }else{
        $msg='';
    }
    $self->{'result'} ="ok 1$msg"; 
    $self->{'result_code'} = 0;
    $self->yaml->{'status'} = 'passed';
    $self->yaml->{'status_code'} = 0;
}

sub fail{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg 
    }else{
        $msg='';
    }
    $self->{'result'} ="not ok 1$msg" ;
    $self->{'result_code'} = 1;
    $self->yaml->{'status'} = 'failed';
    $self->yaml->{'status_code'} = 1;  
}

sub registerLogFile{
    my ($self,$key,$path)  = @_;
    $self->addYE('log.'.$key,$path); 
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

sub tap{
    my $self = shift;
    $self->addYE('result',$self->result);
    my $yaml='';
    $yaml = Dump($self->yaml);
    my $out=
        "TAP version 13\n".
        "1..1\n".
        $self->result."\n".
        $yaml;
}

sub write{
     my $self = shift;
     my $file = $self->_reportFile;
     $self->_createDir;
     $self->addYE('result',     $self->result);
     $self->addYE('result_code',$self->result_code);
     open REP, "> $file" or confess "Cannot open report file:" . $!;
     print REP Dump($self->yaml);
     close REP;
}

=item * 
Stub of execute test function. See implementations in child classes.
=cut
sub execute{
    confess 'Functions is not implemented!';
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
           $self->test->getName.$EXT;
}

#TODO add test
sub _resourceFilePrefix{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getName.'.';

}
__PACKAGE__->meta->make_immutable;

1;

