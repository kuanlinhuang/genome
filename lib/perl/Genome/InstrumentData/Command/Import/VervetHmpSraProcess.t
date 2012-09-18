#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = "1";
    $ENV{UR_DBI_NO_COMMIT} = "1";
};

use above 'Genome';
use Cwd;
use IO::File;
use File::Path;
use File::Compare;
use Test::More;
use lib "/gscuser/jmartin/git/g/lib/perl/Genome/InstrumentData/Command/Import"; #REMOVE THIS ONCE I AM READY TO DEPLOY!!!!
use VervetHmpSraProcess;

#Setup test_dir
my $test_dir = '/gscmnt/sata156/research/mmitreva/HMP_DAWG/VERVET_HMP/VERVET_PIPELINE_WORK/TEST'; #THIS IS A TEMPORARY LOCATION!!!!
#my $test_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Import-Hmp/SUBDIR';
my $bam_name = 'GoldStandardForTesting.2873462096.cleaned.bam';
my $bam_path = $test_dir . '/' . $bam_name;



#Setup imported bam file for use in this test (using my small bam file at $test_dir/GoldStandardForTesting.2873462096.cleaned.bam
#NOTE: I need to do this to setup the test bam file that I will refer to using the 'sra_samples' & 'srr_list' files
#
#NOTE: COMMENT THIS OUT TO RUN FULL TEST!!!!
#vvvvvvvvvvvvvvvvvvvvvvvvvvvv
#my $sample = Genome::Sample->create(
#    name        => 'WFAA-9999-9999999999', #Fake sample name
#    );
#ok($sample, 'create sample');
#my $library = Genome::Library->create(
#    name   => $sample->name.'-testlibs',
#    sample_id => $sample->id
#    );
#ok($library, 'create library');
#my $instrument_data = Genome::InstrumentData::Imported->create(
#    library       => $library,
#    import_format => 'bam',
#    description => 'vervet clean bamfile (subset_name:9999999999 flowcell:XXXXX lane:X index:<NULL> num_input_reads:40 num_clean_reads:30)', #Fake description
#    bam_path      => $bam_path, #Path to my small, 30 read test bam file
#    );
#ok($instrument_data, 'create instrument data');
#my $alloc = Genome::Disk::Allocation->create(
#    owner_id => $instrument_data->id,
#    owner_class_name => $instrument_data->class,
#    kilobytes_requested => 1000,
#    allocation_path => $instrument_data->id,
#    disk_group_name => 'info_alignments',
#    );
#ok($alloc, 'create allocation');
#print $alloc->absolute_path."\n";
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^






#### THIS IS AN EXAMPLE OF HOW TO IMPORT ATTRIBUTE PAIRS INTO INSTRUMENT-DATAS
#my $attr = G:ID:Attribute->create(
#    inst_data=>$inst_data,
#    attribute_name=>'subset_name',
#    attribute_value=>??,
#    );
#my $attr = G:ID:Attribute->get(
#    inst_data=>$inst_data,
#    attribute_name=>'subset_name',
#    attribute_value=>??
#   );





#Test create
use_ok('VervetHmpSraProcess') or die;

#Test function of class ... NOTE: srs_id == sample_name (such as 'WFAA-1108-0104014118')    srr_id == subset_name (such as '2874804312')


my $sra_samples_file = $test_dir . "/test_sra_samples.FULL_TEST";
my $srr_list_file = $test_dir . "/test_srr_list.FULL_TEST";
####my $sra_samples_file = $test_dir . "/test_sra_samples.SMALL_TEST";
####my $srr_list_file = $test_dir . "/test_srr_list.SMALL_TEST";


my %srr_to_srs_index;
my $sra_samples = new IO::File $sra_samples_file;
while (<$sra_samples>) {
    chomp;
    my @line = split(/\t/);
    $srr_to_srs_index{$line[0]} = $line[1];
}
my $srr_list = new IO::File $srr_list_file;
my $index;
while (<$srr_list>) {
    chomp;
    my $srr_id = $_;
    my $srs_id = $srr_to_srs_index{$srr_id};
    push(@{$index->{$srs_id}},$srr_id);
}
foreach my $sample_name (sort {$a cmp $b} keys(%{$index})) { #This example should only be 1 sample_name with 2 subset_names
    my $subset_name_space_delimited_list;
    foreach my $subset_name (sort {$a <=> $b} @{$index->{$sample_name}}) {
	$subset_name_space_delimited_list .= "$subset_name ";
    }
    $subset_name_space_delimited_list =~ s/\s+$//;
    my $cmd = VervetHmpSraProcess->create(srs_sample_id => "$sample_name",srr_accessions => "$subset_name_space_delimited_list",picard_dir => "/gsc/scripts/lib/java/samtools/picard-tools-1.27");
    ok($cmd, 'created VervetHmpSraProcess object');
    ok($cmd->execute, 'executed VervetHmpSraProcess object');
}

#Test output to make sure everything worked










#Exit the test
done_testing();
exit;
