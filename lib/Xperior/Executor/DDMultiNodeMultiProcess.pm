package Xperior::Executor::DDMultiNodeMultiProcess;
use strict;
use warnings FATAL => 'all';
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;
use Storable qw(dclone);

extends 'Xperior::Executor::MultiNodeSingleProcess';

our $VERSION = '0.0.1';

#there we out of threads ny nodes, $self is main executor
sub run{
    my ($self, $targets)= @_;
    my $thr = $self->test->getParam('ddthreads');
    my @threads = ();
    for(my $i=0; $i < $thr; $i++){
        foreach my $t ( @{$targets} ) {
            my $coderef = sub {$self->_run_test()};
            my %tc = %{$t};
            $tc{id}=$t->{id}."_thr$i";
            $tc{thread_id}=$i;
            $tc{connector}=$t->{connector}->clone();
            $tc{connector}->initTemp();
            push @threads, threads->create(sub {$self->run_test(\%tc)});
      }
    }
   my @results;
    foreach my $t (@threads){
        my $res = $t->join();
        $self->addYEE( 'subtests','subtest_'.$res->yaml()->{id}, $res->yaml());
        push @results, $res;
    }
    return \@results;
}

sub verify_node{
    my ($self, $t) = @_;
    my $result = Xperior::SubTestResult->new();
    my %y = ();
    $result->yaml(\%y);
    $result->owner($self);
    $result->addYE( "id", $t->{id} );
    my $thr = $self->test->getParam('ddthreads');
    DEBUG "MultiNodeSingleProcess _verify_node";
    my $fullres=0;
    for (my $i=0; $i < $thr; $i++){
        #FIXME dirty workaround, we should add one more phase
        #'test_preparation' and do it same as for 'run' call
        # this hask is need for filing cmd template
        my $id = $t->{'id'};
        $t->{id}=$t->{id}."_thr$i";
        #subtests:
        #  subtest_client1_thr0:
        #  outfile:
        #  datafile:
        my $datafile = $self->yaml->{subtests}->{"subtest_$t->{id}"}->{datafile};
        my $outfile  = $self->yaml->{subtests}->{"subtest_$t->{id}"}->{outfile};
        #md5 calculating
        #my $dfile = $self->_replace_vars($self->test->getParam('datafile'), $t);
        my $starttime = time;
        my $rmd5 = $t->{connector}->run("md5sum $outfile",timeout=>300);
        my $endtime = time;
        #restore id, see FIXME several lines above
        $result->addYEE("md5sum_exit_code","thr$i",$rmd5->{exitcode});
        $result->addYEE("md5sum_starttime","thr$i",$starttime);
        $result->addYEE("md5sum_endtime","thr$i",$endtime);
        if( $rmd5->{stdout} =~ m/([\d\w]+)\s+/x){
            my $md5 = $1;
            $result->addYEE("md5sum","thr$i",${md5});
            $result->addYEE("md5sum_cacl_parse","thr$i",1);
            my $md5org =
                $self->yaml
                    ->{subtests_prepare}
                        ->{"subtest_${id}"}
                            ->{"md5sum"}
                               ->{"thr${i}"};
            if($md5org eq $md5){
                $result->addYEE("md5sum_check","thr$i",1);
                $result->accumulate_resolution(
                    $self->PASSED,'');
            }else{
                $result->addYEE("md5sum_check","thr$i",'failed');
                $result->accumulate_resolution(
                    $self->FAILED,
                    "md5sum verification failed for thr$i");
            }
        }else{
            $result->accumulate_resolution(
                $self->FAILED,
                "Cannot parse md5sum for thr$i");
            DEBUG "$->{id}_thre${i}: Cannot parse md5sum for".$rmd5->{stdout} ;
            $result->addYEE("md5sum_cacl_parse","thr$i",'failed');
        }
        $t->{id}=$id;
    }
    return $result;

}

sub _replace_vars{
    my ($self, $cmd, $target, $filename) = @_;
    confess "cmd is undefined " unless defined $cmd;
    my $mp        = $self->env->cfg->{'client_mount_point'};
    my $tmpdir    = $self->env->cfg->{'tempdir'};
    my $target_id   =
        (defined ($target->{id}))? $target->{id} : 'idnotset';
    $cmd =~ s/\@client_mount_point\@/$mp/xge;
    $cmd =~ s/\@genfilename\@/$filename/xge;
    $cmd =~ s/\@tmpdir\@/$tmpdir/xge;
    $cmd =~ s/\@target_id\@/$target_id/xge;
    return $cmd;
}



#there we are in thread, executor is copyied and should not changed.
sub prepare_node{
    my ($self, $t, $connector, $mountpoint) = @_;
    my $result = $self->SUPER::prepare_node($t, $connector, $mountpoint);

    if( not $self->need_verification() ){
        #no file generation when verification is not needed
        return $result;
    }

    DEBUG Dumper $t;
    my $thr = $self->test->getParam('ddthreads');
    DEBUG "MultiNodeSingleProcess prepare_node";
    #my $fullres=0;
    for (my $i=0; $i < $thr; $i++){
        #FIXME dirty workaround, we should add one more phase
        #'test_preparation' and do it same as for 'run' call
        # this hask is need for filing cmd template
        my $id = $t->{'id'};
        $t->{id}=$t->{id}."_thr$i";
        my $cmd = $self->_replace_vars($self->test->getParam('createdata'), $t);
        $result->addYEE("ddcmd","thr$i",$cmd);
        my $rr = $connector->run($cmd, timeout=>1200);
        $result->addYEE("ddexitcode","thr$i",$rr->{exitcode});
        $result->writeLogFile("$t->{id}.prepare.dd.stdout",$rr->{stdout});
        $result->writeLogFile("$t->{id}.prepare.dd.stderr",$rr->{stderr});
        #$fullres = $fullres + $rr->{exitcode};
        #md5 calculating
        my $dfile = $self->_replace_vars($self->test->getParam('datafile'), $t);
        my $rmd5 = $connector->run("md5sum $dfile");
        #restore id, see FIXME several lines above
        if( $rmd5->{stdout} =~ m/([\d\w]+)\s+/x){
            $result->addYEE("md5sum","thr$i",${1});
            $result->accumulate_resolution(
                    $self->PASSED,'');
        }else{
            $result->accumulate_resolution(
                $self->FAILED,
                "Cannot parse md5sum for thr$i");
            DEBUG "$->{id}_thre${i}: Cannot parse md5sum for".$rmd5->{stdout} ;
        }
        $t->{id}=$id;
    }
    return $result;
}

sub cleanup_node{
    DEBUG "MultiNodeSingleProcess cleanup_node";
    my ($self, $t) = @_;
    my $result = Xperior::SubTestResult->new();
    my %y = ();
    $result->yaml(\%y);
    $result->owner($self);
    $result->addYE( "id", $t->{id} );
    #my $result = $self->SUPER::prepare_node($t, $connector, $mountpoint);
    my $thr = $self->test->getParam('ddthreads');
    #my $fullres=0;
    for (my $i=0; $i < $thr; $i++) {
        #FIXME dirty workaround, we should add one more phase
        #'test_preparation' and do it same as for 'run' call
        # this hask is need for filing cmd template

        my $id = $t->{'id'};
        $t->{id}=$t->{id}."_thr$i";
        my $datafile = $self->yaml->{subtests}->{"subtest_$t->{id}"}->{datafile};
        my $starttime = time;
        my $rm = $t->{connector}->run("rm -f -v $datafile",timeout=>300);
        my $endtime = time;
        $result->addYEE("ddcleanupexitcode","thr$i",$rm->{exitcode});
        $result->writeLogFile("$t->{id}.cleanup.dd.stdout",$rm->{stdout});
        $result->writeLogFile("$t->{id}.cleanup.dd.stderr",$rm->{stderr});
        $result->addYEE("cleanup_starttime","thr$i",$starttime);
        $result->addYEE("cleanup_endtime","thr$i",$endtime);
        $t->{id}=$id;
    }
    return $result;
}

__PACKAGE__->meta->make_immutable;

1;
