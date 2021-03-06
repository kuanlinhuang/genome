#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
    $ENV{NO_LSF}=1;
}

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;
use Genome::Test::Factory::SoftwareResult::User;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $ref_seq_build,
);

#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";

my $tumor_bam = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_tumor_sorted.bam";
my $normal_bam = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_normal_sorted.bam";

# Test dispatcher for running a single detector followed by a single filter case
my $test_working_dir = File::Temp::tempdir('DetectVariants2-Dispatcher-filterXXXXX', CLEANUP => 1, TMPDIR => 1);
my $filter_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 filtered by snp-filter v1',
    output_directory => $test_working_dir,
    reference_build_id => $refbuild_id,
    aligned_reads_input => $tumor_bam,
    control_aligned_reads_input => $normal_bam,
    aligned_reads_sample => 'TEST',
    result_users => $result_users,
);
ok($filter_test, "Object to test a filter case created");
$filter_test->dump_status_messages(1);
ok($filter_test->execute, "Successfully executed test.");
ok($filter_test->_workflow_result->{snv_result_id}, 'snv_result_id defined in workflow result');
ok($filter_test->_workflow_result->{snv_result_class}, 'snv_result_class defined in workflow result');
ok($filter_test->snv_result, 'snv_result defined on command');

done_testing();
