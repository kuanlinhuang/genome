#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::Orient') or die;

use_ok('Genome::Model::Build::MetagenomicComposition16s::TestBuildFactory') or die;
my ($build, $example_build) = Genome::Model::Build::MetagenomicComposition16s::TestBuildFactory->build_with_example_build_for_454;
ok($build && $example_build, 'Got build and example_build');

my @amplicon_sets = $build->amplicon_sets;
my @example_amplicon_sets = $example_build->amplicon_sets;
ok(@amplicon_sets && @example_amplicon_sets, 'Got amplicon sets');
for ( my $i = 0; $i < @example_amplicon_sets; $i++ ) {
    for my $file_name (qw/ processed_fasta_file processed_qual_file classification_file /) {
        my $file = $example_amplicon_sets[$i]->$file_name;
        die "File ($file_name: $file) does not exist!" if not -s $file;
        Genome::Sys->create_symlink($file, $amplicon_sets[$i]->$file_name);
    }
}
$build->amplicons_attempted(20);
$build->amplicons_processed(14);
$build->amplicons_processed_success('0.70');
$build->amplicons_classified(14);
$build->amplicons_classified_success('1.00');
$build->amplicons_classification_error(0);

ok($build->orient_amplicons, 'orient amplicons');

for ( my $i = 0; $i < @amplicon_sets; $i++ ) { 
    my $set_name = $amplicon_sets[$i]->name;
    is($set_name, $example_amplicon_sets[$i]->name, "set name: $set_name");
    for my $file_name (qw/ oriented_fasta_file oriented_qual_file /) {
        my $file = $amplicon_sets[$i]->$file_name;
        ok(-s $file, "$file_name exists for set $set_name");
        my $example_file = $example_amplicon_sets[$i]->$file_name;
        ok(-s $example_file, "example $file_name name exists for set $set_name");
        is(File::Compare::compare($file, $example_file), 0, "$file_name exists for set $set_name");
    }
}

#print $build->data_directory."\n"; <STDIN>;
done_testing();
exit;


