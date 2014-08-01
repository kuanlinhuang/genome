#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use above "Genome";

use Test::More;

# for samtools
if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

use_ok('Genome::InstrumentData::Command::Import::TcgaBam') or die;

my $cmd = Genome::InstrumentData::Command::Import::TcgaBam->create(
    target_region       => 'none',
    tcga_name           => "TCGA-AB-2804-03B-01W-0728-08",  
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/test.bam',
    reference_sequence_build_id => 101947881,
);
ok($cmd, "created cmd object");
ok($cmd->execute,"executed command");

my $i_d = $cmd->_inst_data;
ok($i_d, 'created instrument data');
is($i_d->sequencing_platform, 'solexa', 'platform');
is($i_d->original_data_path, $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/test.bam', 'original data path');
is($i_d->user_name, Genome::Sys->username, "user name is correct");
ok($i_d->description,"description was created: ".$i_d->description);
ok($i_d->import_date, "date is set");
ok($i_d->is_paired_end, "is_paired_end is set");
is($i_d->read_count,2742092, "read_count is set");
is($i_d->fragment_count, 5484184,"fragment_count is set");
is($i_d->read_length, 50,"read_length is set");
is($i_d->base_count,274209200, "base_count is set to 274209200");
ok(-s $i_d->archive_path, "bam exists");

# created attributes properly
my $inst_data = $cmd->_inst_data;
my $aid_attr = $inst_data->attributes(attribute_label=>"analysis_id");
ok($aid_attr, 'attribute exists.');
is($aid_attr->attribute_value, "a1d11d67-4d5f-4db9-a61d-a0279c3c3d4f", 'attribute has correct value.');
is($aid_attr->nomenclature, "CGHub", 'nomeclature set on attribute properly');
my $isn_attr = $inst_data->attributes(attribute_label=>"participant_id");
ok((not defined $isn_attr), "attribute doesn't exist.");


# getting args from passed in first then from metadata file.
my $test_cmd1 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    tcga_name           => "test_tcga_passed_in",  
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/test.bam',
    import_source_name  => 'Broad',
    reference_sequence_build_id => 101947881,
    analysis_id => "test_analysis_id",
);
$test_cmd1->_resolve_args;
ok($test_cmd1->bam_md5, 'read bam_md5 from metadata file.');
is($test_cmd1->tcga_name, 'test_tcga_passed_in', 'read in tcga_name from passed arg not from metadata file.');
is($test_cmd1->target_region, "agilent sureselect exome version 2 broad refseq cds only", 'read in and translated target_region from the metadata file.');
is($test_cmd1->analysis_id, "test_analysis_id", 'read in test_analysis_id as passed arg not from metadata file.');
is($test_cmd1->aliquot_id, "f957194b-6da9-4690-a87d-0051e239bf3f", 'read in aliquot_id from metadata file.');
is($test_cmd1->participant_id, undef, 'participant_id was not defined and that is a-OK.');


# alternative md5 value from passed in
my $test_cmd2 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/test.bam',
    reference_sequence_build_id => 101947881,
    bam_md5 => "test_md5_value"
);
$test_cmd2->_resolve_args;
is($test_cmd2->bam_md5, 'test_md5_value', 'Found md5 value from passed in arg, not from metadata file or .md5 file');

# alternative md5 value from file
my $test_cmd3 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    tcga_name           => "TCGA-AB-2804-03B-01W-0728-08",  
    target_region       => "something",
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/no_metadata/test.bam',
    reference_sequence_build_id => 101947881,
);
$test_cmd3->_resolve_args;
is($test_cmd3->bam_md5, '0f307401916947ab16e37b225da8c999', "found md5 value from .md5 file, no metadata file present and it wasn't passed in.");


# no bam_md5 fail
my $test_cmd4 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    tcga_name           => "TCGA-AB-2804-03B-01W-0728-08",  
    target_region       => "something",
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/no_md5_no_metadata/test.bam',
    reference_sequence_build_id => 101947881,
);
eval {$test_cmd4->_resolve_args};
ok($@, 'expected failure.');
is($test_cmd4->error_message, "Required argument (bam_md5) was not passed and couldn't be found in the metadata or an .md5 file in the directory where the bam file is.", 'failed properly when md5 is not passed in and not in metadata file and no_md5=0');   


# no fail if no_md5 is set
my $test_cmd5 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    tcga_name           => "TCGA-AB-2804-03B-01W-0728-08",  
    target_region       => "something",
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/no_md5_no_metadata/test.bam',
    reference_sequence_build_id => 101947881,
    no_md5 => 1,
);
eval {$test_cmd5->_resolve_args};
ok(!$@, "didn't crash if no_md5 is set.") or diag($@);


# required arg missing fail
my $test_cmd6 = Genome::InstrumentData::Command::Import::TcgaBam->create(
    target_region       => "something",
    import_source_name  => 'Broad',
    original_data_path  => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData--Command-Import-Bam/no_md5_no_metadata/test.bam',
    reference_sequence_build_id => 101947881,
);
eval {$test_cmd6->_resolve_args};
ok($@, "expected failure for missing required arg");
is($test_cmd6->error_message, "Required argument (tcga_name) was not passed and couldn't be found in the metadata.", 'failed properly required arg is missing.');   

done_testing();
