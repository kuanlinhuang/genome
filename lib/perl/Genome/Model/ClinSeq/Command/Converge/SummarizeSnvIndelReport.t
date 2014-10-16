#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above "Genome";
use Test::More;

use_ok('Genome::Model::ClinSeq::Command::Converge::SummarizeSnvIndelReport') or die;

#Define the test where expected results are stored
my $expected_output_dir = $ENV{"GENOME_TEST_INPUTS"} .
  "Genome-Model-ClinSeq-Command-Converge-SummarizeSnvIndelReport/2014-10-13/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Run GenerateSciclone on the 'apipe-test-clinseq-wer' model
my $clinseq_build =
  Genome::Model::Build->get(id => '84b87bb59d994a48a7bb1bee785b4ccd');
ok($clinseq_build, "Found clinseq build.");
my $run_summarize_sireport = Genome::Model::ClinSeq::Command::Converge::SummarizeSnvIndelReport->create(
  outdir => $temp_dir,
  clinseq_build => $clinseq_build,
  min_bq => 20,
  min_mq => 30,
);
$run_summarize_sireport->queue_status_messages(1);
$run_summarize_sireport->execute();

#Dump the output to a log file
my @output1 = $run_summarize_sireport->status_messages();
my $log_file = $temp_dir . "/summarize_sireport.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
$log->close();
ok(-e $log_file, "Wrote message file from generate-sciclone-plots to a log file: $log_file");

my @diff = `diff -r -x '*.log.txt' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected
  results and test results")
or do {
  diag("expected: $expected_output_dir\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-run-summarize_sireport/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-run-summarize_sireport");
  die print "\n\nFound $diff_line_count differing lines\n\n";
};

done_testing();
