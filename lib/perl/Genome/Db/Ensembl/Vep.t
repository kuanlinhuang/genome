#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Genome::Utility::Test qw(command_execute_ok);
use Test::More;

use_ok("Genome::Db::Ensembl::Vep");

my $VERSION = '2';
my $input_data_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Db-Ensembl-Vep';
my $expected_data_dir = $input_data_dir . '/expected_output';
my $expected_output_file = $expected_data_dir.'/output.'.$VERSION;

my $output_file = Genome::Sys->create_temp_file_path;
my $cmd_1 = Genome::Db::Ensembl::Vep->create(
    input_file => $input_data_dir."/input.".$VERSION,
    format => "ensembl",
    output_file => $output_file,
    sift => "b",
    regulatory => 1,
    plugins => ["Condel,PLUGIN_DIR,b,2"],
    version => "2_5",
    ensembl_annotation_build_id => 124434505,
    quiet => 1,
);

isa_ok($cmd_1, 'Genome::Db::Ensembl::Vep');
Genome::Sys->dump_status_messages(0);
command_execute_ok($cmd_1,
    { error_messages => [],
      status_messages => undef, },
    'execute');
ok(-s $output_file, 'output file is non-zero');


my $expected = `cat $expected_output_file | grep -v "Output produced at" | grep -v "Using cache"`;
my $output = `cat $output_file | grep -v "Output produced at" | grep -v "Using cache"`;

my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'output matched expected result');

done_testing();
