#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;
use File::Compare;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

use_ok('Genome::Model::Tools::DetectVariants2::Filter::FalseIndel');

my $test_base_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Filter-FalseIndel';
my $test_data_dir = $test_base_dir. "/input.v3";
my $detector_vcf_directory = $test_base_dir. "/detector_vcf_result";

#These aren't very good test files.
my $bam_file     = join('/', $test_data_dir, 'tumor.tiny.bam');
my $variant_file = join('/', $test_data_dir, 'indels.hq.bed');
my $expected_dir = join('/', $test_base_dir, '6');

my $test_output_dir  = Genome::Sys->create_temp_directory;
my $vcf_version = Genome::Model::Tools::Vcf->get_vcf_version;

my $reference = Genome::Model::Build::ImportedReferenceSequence->get_by_name('NCBI-human-build36');
isa_ok($reference, 'Genome::Model::Build::ImportedReferenceSequence', 'loaded reference sequence');

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $test_data_dir,
    detector_name => 'Genome::Model::Tools::DetectVariants2::VarscanSomatic',
    detector_params => '',
    detector_version => 'awesome',
    aligned_reads => $bam_file,
    reference_build_id => $reference->id,
);
$detector_result->lookup_hash($detector_result->calculate_lookup_hash());

my $detector_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Detector->__define__(
    input => $detector_result,
    output_dir => $detector_vcf_directory,
    aligned_reads_sample => "TEST",
    vcf_version => $vcf_version,
);
$detector_vcf_result->lookup_hash($detector_vcf_result->calculate_lookup_hash());
$detector_result->add_user(user => $detector_vcf_result, label => 'uses');

my $param_str = '--bam-readcount-version 0.3';
run_test('default_params', $param_str);

#TODO the test input indel list is too short, need longer one
$param_str .= ' --max-mm-qualsum-diff 100 --min-var-freq 0.2 --min-homopolymer 10 --min-var-count 10';
run_test('non_default_params', $param_str);

done_testing();


sub run_test {
    my ($type, $params) = @_;
    my $output_dir = $test_output_dir."/$type";
    my $expect_dir = $expected_dir."/$type";

    my %params = (
        previous_result_id => $detector_result->id,
        output_directory   => $output_dir,
        params => $params,
    );

    my $filter_command = Genome::Model::Tools::DetectVariants2::Filter::FalseIndel->create(%params);
    $filter_command->dump_status_messages(1);
    isa_ok($filter_command, 'Genome::Model::Tools::DetectVariants2::Filter::FalseIndel', 'created filter command');
    ok($filter_command->execute(), 'executed filter command');

    my %parameters = split /\s+/, $params;

    for my $parameter (keys %parameters) {
        my $before_value = $parameters{$parameter};
        $parameter =~ s/^\-\-//;
        $parameter =~ s/\-/_/g;
        my $after_value  = $filter_command->$parameter;
        ok($before_value eq $after_value, "Parameter $parameter set correctly via params string");
    }

    my @files = qw(indels.hq indels.lq indels.hq.bed indels.lq.bed indels.vcf.gz);

    for my $file_name (@files) {
        my $test_output     = $output_dir."/".$file_name;
        my $expected_output = $expect_dir."/".$file_name;
        my $msg = "Output: $file_name generated as expected";

        if ($file_name =~ /vcf\.gz/) {
            my $out_md5    = qx(zcat $test_output     | grep -vP '^##fileDate' | md5sum);
            my $expect_md5 = qx(zcat $expected_output | grep -vP '^##fileDate' | md5sum);
            ok($out_md5 eq $expect_md5, $msg);
        }
        else {
            is(compare($test_output, $expected_output), 0, $msg);
        }
    }

    return 1;
}

