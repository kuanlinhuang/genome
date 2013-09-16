#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Genome::Utility::Text;
use Test::More tests => 37;

use Cwd;
#use Carp::Always;

#These get reused several times in this test--if later this test somehow depends on the contents of the directories make one for each
my $temp_dir = File::Temp::tempdir('Model-Command-Define-SomaticValidation-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $temp_build_data_dir = File::Temp::tempdir('t_SomaticValidation_Build-XXXXX', CLEANUP => 1, TMPDIR => 1);

my $somatic_variation_build = &setup_somatic_variation_build(1);
isa_ok($somatic_variation_build, 'Genome::Model::Build::SomaticVariation', 'setup test somatic variation build');

#Set up a fake feature-list
my $data = <<EOBED
1	10003	10004	A/T
EOBED
;
my $test_bed_file = Genome::Sys->create_temp_file_path;
Genome::Sys->write_file($test_bed_file, $data);
my $test_bed_file_md5 = Genome::Sys->md5sum($test_bed_file);
my $test_targets = Genome::FeatureList->create(
    name => 'test_somatic_validation_feature_list',
    format              => 'true-BED',
    content_type        => 'validation',
    file_path           => $test_bed_file,
    file_content_hash   => $test_bed_file_md5,
    reference_id        => $somatic_variation_build->tumor_model->reference_sequence_build->id,
);
isa_ok($test_targets, 'Genome::FeatureList', 'created test feature-list');

my $variants_1 = $somatic_variation_build->final_result_for_variant_type('snvs');

my $mg = Genome::ModelGroup->__define__( name => 'test for SomaticValidation.t');
isa_ok($mg, 'Genome::ModelGroup', 'defined model-group');

my @params_for_define_1 = (
    target => $test_targets,
    variants => [$variants_1],
    groups => [$mg],
);

my $define_1 = Genome::Model::Command::Define::SomaticValidation->create(@params_for_define_1);
isa_ok($define_1, 'Genome::Model::Command::Define::SomaticValidation', 'first creation command');
$define_1->dump_status_messages(1);

ok($define_1->execute, 'executed first creation command');
my $m_1 = Genome::Model->get($define_1->result_model_ids);
isa_ok($m_1, 'Genome::Model::SomaticValidation', 'created model with the first creation command');
my $snv_result = $m_1->snv_variant_list;
isa_ok($snv_result, 'Genome::Model::Tools::DetectVariants2::Result', 'result for first model');
is($snv_result->detector_name, 'samtools', 'found existing result for first model as expected');
is($snv_result->detector_params, '--fake', 'found existing result for first model as expected');
is($m_1->subject, $somatic_variation_build->tumor_model->subject->source, 'model has expected subject');
is($mg->models, $m_1, 'new model was added to group');

my $manual_result_cmd = Genome::Model::SomaticValidation::Command::ManualResult->create(
    variant_file => $test_bed_file,
    variant_type => 'indel',
    source_build => $somatic_variation_build,
    description => 'curated for testing purposes',
);
$manual_result_cmd->execute;
my $result = $manual_result_cmd->manual_result;
ok($result, 'created a manual result');

my @params_for_define_2 = (
    name => 'awesome second model',
    design => $test_targets,
    variants => [$variants_1, $result],
);

my $define_2 = Genome::Model::Command::Define::SomaticValidation->create(@params_for_define_2);
isa_ok($define_2, 'Genome::Model::Command::Define::SomaticValidation', 'second creation command');
$define_2->dump_status_messages(1);

ok($define_2->execute, 'executed second creation command');
my $m_2 = Genome::Model->get($define_2->result_model_ids);
isa_ok($m_2, 'Genome::Model::SomaticValidation', 'created model with the second creation command');
my $indel_result = $m_2->indel_variant_list;
isa_ok($indel_result, 'Genome::Model::Tools::DetectVariants2::Result::Manual', 'result for second model');
is($indel_result->description, 'curated for testing purposes', 'found existing result for second model as expected');


my $somatic_variation_build2 = &setup_somatic_variation_build(2);
my $variants_2 = $somatic_variation_build2->final_result_for_variant_type('snvs');
my @params_for_define_3 = (
    design => $test_targets,
    target => $test_targets,
    variants => [$variants_1, $variants_2],
);

my $define_3 = Genome::Model::Command::Define::SomaticValidation->create(@params_for_define_3);
isa_ok($define_3, 'Genome::Model::Command::Define::SomaticValidation', 'third creation command');
$define_3->dump_status_messages(1);

ok($define_3->execute, 'executed third creation command');
my @m_3 = Genome::Model->get([$define_3->result_model_ids]);
is(scalar(@m_3), 2, 'created two models');
isnt($m_3[0]->subject, $m_3[1]->subject, 'two models have two different subjects');
is($m_3[1]->region_of_interest_set, $test_targets, 'roi set to default properly');

my @params_for_define_4 = (
    design => $test_targets,
    target => $test_targets,
    tumor_sample => $somatic_variation_build2->tumor_model->subject,
    normal_sample => $somatic_variation_build2->normal_model->subject,
);

my $define_4 = Genome::Model::Command::Define::SomaticValidation->create(@params_for_define_4);
isa_ok($define_4, 'Genome::Model::Command::Define::SomaticValidation', 'fourth creation command');
$define_4->dump_status_messages(1);

ok($define_4->execute, 'executed fourth creation command');
my $m_4 = Genome::Model->get($define_4->result_model_ids);
isa_ok($m_4, 'Genome::Model::SomaticValidation', 'created fourth model with samples explicitly named');
is($m_4->tumor_sample, $somatic_variation_build2->tumor_model->subject, 'tumor sample set properly');
is($m_4->normal_sample, $somatic_variation_build2->normal_model->subject, 'normal sample set properly');

#Test with no normal
my @params_for_define_5 = (
    design => $test_targets,
    target => $test_targets,
    tumor_sample => $somatic_variation_build2->tumor_model->subject,
);

my $define_5 = Genome::Model::Command::Define::SomaticValidation->create(@params_for_define_5);
isa_ok($define_5, 'Genome::Model::Command::Define::SomaticValidation', 'fifth creation command');
$define_5->dump_status_messages(1);

ok($define_5->execute, 'executed fifth creation command');
my $m_5 = Genome::Model->get($define_5->result_model_ids);
isa_ok($m_5, 'Genome::Model::SomaticValidation', 'created fifth model with samples explicitly named');
is($m_5->tumor_sample, $somatic_variation_build2->tumor_model->subject, 'tumor sample set properly');
ok(!$m_5->normal_sample, 'no normal sample set');
isnt($m_5->processing_profile, $m_4->processing_profile, 'assigned different default processing profile for single-sample case');


my $fake_individual = Genome::Individual->create(
    common_name => 'FAKE1',
    name => 'fake_individual_1',
);

my @fake_samples;
for my $i (1...8) {
    push @fake_samples,
        Genome::Sample->create(
            name => 'fake_sample_' . $i,
            source_id => $fake_individual->id,
        );
}

#test warning about normal in tumor position
$fake_samples[1]->common_name('normal');
$fake_samples[0]->common_name('tumor');

my $fake_library = Genome::Library->create(
    sample_id => $fake_samples[7]->id,
    name => $fake_samples[7]->name . '-lib4',
);

my $sample_list_file = Genome::Sys->create_temp_file_path;
Genome::Sys->write_file($sample_list_file, join("\n",
    join("\t", $fake_samples[0]->name, $fake_samples[1]->name),
    join("\t", $fake_samples[2]->name, $fake_samples[3]->name, $fake_samples[4]->name, $fake_samples[5]->id, $fake_samples[6]->name),
    $fake_library->name
));

my $define_6 = Genome::Model::Command::Define::SomaticValidation->create(
    sample_list_file => $sample_list_file,
    target => $test_targets,
);
isa_ok($define_6, 'Genome::Model::Command::Define::SomaticValidation', 'sixth creation command');
$define_6->dump_status_messages(1);

ok($define_6->execute, 'executed sixth creation command');
my @m_6 = Genome::Model->get([$define_6->result_model_ids]);
is(scalar(@m_6), 12, 'created twelve models based on sample file');

my $wm = $define_6->warning_message;
ok($wm =~ /Sample specified as tumor fake_sample_2.*indicates it is a normal!/, 'produced desired warning about possible tumor/normal swap');

# Create some test models with builds and all of their prerequisites
sub setup_somatic_variation_build {
    my $i = shift;

    use Genome::Test::Factory::Model::SomaticValidation;

    my $somvar_build = Genome::Test::Factory::Model::SomaticValidation->setup_somatic_variation_build();

    my $dir = ($temp_dir . '/' . 'fake_samtools_result' . $i);
    Genome::Sys->create_directory($dir);
    my $result = Genome::Model::Tools::DetectVariants2::Result->__define__(
        detector_name => 'samtools',
        detector_version => 'r599',
        detector_params => '--fake',
        output_dir => Cwd::abs_path($dir),
        id => (-2013 - $i),
    );
    $result->lookup_hash($result->calculate_lookup_hash());

    my $bed_file = $dir . '/snvs.hq.bed';
    my $bed_text = Genome::Utility::Text::table_to_tab_string([
        [qw(1 10003 10004 A/T)],
        [qw(2  8819  8820 A/G)],
    ]);
    Genome::Sys->write_file($bed_file, $bed_text);

    my $detector_file = $dir . '/snvs.hq';
    my $detector_text = Genome::Utility::Text::table_to_tab_string([
        [qw(1  554426 C G  5  5  0 2 G ')],
        [qw(1 3704868 C T 30 30 37 1 t ;)],
    ]);
    Genome::Sys->write_file($detector_file, $detector_text);

    my $dir2 = ($temp_dir .'/' . 'fake_combine_result' . $i);
    Genome::Sys->create_directory($dir2);
    my $result2 = Genome::Model::Tools::DetectVariants2::Result::Combine::IntersectIndel->__define__(
        output_dir => Cwd::abs_path($dir2),
        id => (-3014 - $i),
    );
    $result2->lookup_hash($result2->calculate_lookup_hash());

    $result->add_user(user => $somvar_build, label => 'uses');
    $result2->add_user(user => $somvar_build, label => 'uses');

    return $somvar_build;
}
