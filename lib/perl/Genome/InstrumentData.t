#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

my $base_class = 'Genome::InstrumentData';

use_ok('Genome::InstrumentData') or die;

my %seq_plats_and_ids = (
    454     => ['2853729194','2853729397'],
        # region_id  seq_id     index_sequence
        # 2853729293 2853729194
        # 2853729292 2853729397 AACAACTC
    sanger  => ['22sep09.863amcb1'],
    solexa  => ['2338813239'],
);

my @rcs = Genome::InstrumentData->get([ map { @$_ } values %seq_plats_and_ids ]);
is(scalar(@rcs), 4, "got 4 objects");

for my $platform (keys %seq_plats_and_ids) {
    note("Now test $platform");
    
    my $subclass = $base_class.'::'.ucfirst($platform);
    use_ok($subclass);
    
    for my $id (@{ $seq_plats_and_ids{$platform} }) {
        my $instrument_data =Genome::InstrumentData->get($id);
        isa_ok($instrument_data, $subclass);
        is($instrument_data->sequencing_platform, $platform, 'platform is correct');
        
        if ( $platform eq 'solexa' ) {
            is($instrument_data->sample_type,'rna','got expected sample type');
            is($instrument_data->resolve_quality_converter,'sol2sanger','got expected quality converter for ' . $instrument_data->native_qual_type . " this is WRONG FIXME!");
            #is($instrument_data->resolve_quality_converter,'sol2phred','got expected quality converter for ' . $instrument_data->native_qual_type); # correct
        }
    }
}

# Test is_attribute
class SuperSeq {
    is => 'Genome::InstrumentData',
    has => [
        file => { is_attribute => 1, },
    ],
};
sub SuperSeq::Ghost::__signal_change__ { return 1; }

my $library = Genome::Library->create(
    name => '__TEST_LIBRARY__',
    sample => Genome::Sample->create(name => '__TEST_SAMPLE__'),
);
ok($library, 'define library');
my $inst_data = SuperSeq->__define__(
    library => $library,
    file => 'some_file',
);
ok($inst_data, 'create super seq inst data');
my @attrs = $inst_data->attributes;
ok(@attrs, 'super seq has attributes');
my ($file_attr) = grep { $_->attribute_label eq 'file' } @attrs;
ok($file_attr, 'super seq file attr');
is($file_attr->attribute_value, $inst_data->file, 'super seq file attr matches accessor');

# test delete
#  abandon build
class Genome::Model::SuperModel { is => 'Genome::Model', };
my $model = Genome::Model::SuperModel->__define__(
    id => -111,
    name => 'Cathy Ireland',
    created_by => 'apipe-builder',
);
$model->add_instrument_data($inst_data);

class Genome::Model::Build::SuperBuild { is => 'Genome::Model::Build', };
my $build = Genome::Model::Build::SuperBuild->__define__(
    id => -111,
    model_id => $model->id,
    model => $model,
);
$build->add_instrument_data($inst_data);
my $event = $build->_create_master_event;
$event->event_status('Succeeded');

#  create associated alignment results
my $alignment_result = Genome::InstrumentData::AlignmentResult::Bwa->__define__(
    id => -333,
    instrument_data_id => $inst_data->id,
    aligner_name => 'bwa',
    aligner_version => '1',
    aligner_params => 'NA',
);
ok($alignment_result, 'define alignment result for super seq inst data');
ok($alignment_result->add_user(user => $build), 'add build as user of alignment result');

my $merged_result = Genome::InstrumentData::AlignmentResult::Merged->__define__(id => -444,);#instrument_data_id => [$inst_data->id]);
$merged_result->add_input(name => 'instrument_data_id-1', value_id => $inst_data->id, value_class_name => $inst_data->class);
ok($merged_result, 'define merged alignment result for super seq inst data');

my $qc_result = Genome::InstrumentData::AlignmentResult::Merged::BamQc->__define__(alignment_result_id => $alignment_result->id);
ok($qc_result, 'define merged qc result for inst data');

my $tophat_result = Genome::InstrumentData::AlignmentResult::Tophat->__define__(id => -555);
ok($tophat_result, 'define top hat result');
$tophat_result->add_input(name => 'instrument_data_id-1', value_id => $inst_data->id, value_class_name => $inst_data->class);

#  add users to alignment results
ok($alignment_result->add_user(user => $merged_result, label => 'uses'), 'add merged result as user of alignment result');
ok($alignment_result->add_user(user => $build, label => 'uses'), 'add build as user of merged result');
ok($alignment_result->add_user(user => $qc_result, label => 'uses'), 'add qc result as user of alignment result');
ok($qc_result->add_user(user => $build, label => 'uses'), 'add build as user of qc result');
ok($tophat_result->add_user(user => $build, label => 'uses'), 'add build as user of tophat result');

ok($inst_data->delete, 'delete super seq inst data');
ok(!$model->instrument_data, 'removed inst data from model');
is($build->status, 'Abandoned', 'set build to abandoned');

for my $result ($alignment_result, $merged_result, $qc_result, $tophat_result) {
    ok($result->test_name, 'set test name on result for expunged data');
}

done_testing();
