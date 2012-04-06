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
=pod

=head1 NAME

Xperior::Executor::Base - Base executor class

=head1 DESCRIPTION

To be done
it is possible to use http://instanttap.appspot.com/ for check tap outputs. Doesn't work with skip.

=head1 FUNCTIONS

=over 2

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

#use Xperior::SshProcess;

our $YVERSION = 'Xperior1'; #yaml output version. other modules also can add fields.
our $EXT  = '.yaml';
our $TEXT = '.tap';
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
    my %th;
    $self->yaml(\%th);
    $self->yaml->{'status'} = 'not set';
    $self->yaml->{'status_code'} = -1;
    $self->yaml->{'messages'}    = '';
    $self->yaml->{'schema'}    = $YVERSION;


    $self->steptimeout(5);

    $self->{'test'} = $test;
    $self->{'options'} = $opt;
    $self->{'env'}     = $env;
    foreach my $k ( @{$test->getParamNames}){
        $self->addYE($k,$test->getParam($k));
    }
    $self->_write;
}

=item addYE(KEY, VALUE) - Adds Yaml Element. 

Returns 1 if the value has been overridden, otherwise returns 0.

=cut

sub addYE{
    my ($self, $key, $value) = @_;
    my $overridden = defined $self->yaml->{$key};
    $self->yaml->{$key} = $value ;
    $self->_write;
    return $overridden;
}

=item addYEE(KEY1, KEY2, VALUE) - Adds Yaml Elelement in Element. 

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

sub addMessage{
    my ($self,$data) = @_;
    $self->yaml->{'messages'} = $self->yaml->{'messages'}
                                    . $data."\n";
}

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
}

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
}

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
}

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

sub report{
     my $self = shift;
     $self->addYE('result',     $self->result);
     $self->addYE('result_code',$self->result_code);
     $self->_write;
}

=item execute() - Stub of execute test function. 

Should be implemented in child classes.

=cut
sub execute{
    confess 'Functions is not implemented, override it!';
}

=item getReason() - Stub of getReason function.

Should be implemented in child classes. 
Should return short failure reason description.

=cut
sub getReason{
    return "Non-zero exit code";
}



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
           $self->test->getName.$EXT;
}

sub _tapFile{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getName.$TEXT;
}


#TODO add test
sub _resourceFilePrefix{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->test->getName.'.';

}
__PACKAGE__->meta->make_immutable;

1;

=back

=cut=

