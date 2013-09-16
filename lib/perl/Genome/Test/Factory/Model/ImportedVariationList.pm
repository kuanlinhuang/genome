package Genome::Test::Factory::Model::ImportedVariationList;
use Genome::Test::Factory::Model;
@ISA = (Genome::Test::Factory::Model);

use strict;
use warnings;
use Genome;

use Genome::Test::Factory::ProcessingProfile::ImportedVariationList;

our @required_params = qw(subject);

sub generate_obj {
    my $self = shift;

    my $m = Genome::Model::ImportedVariationList->create(@_);
    return $m;
}

sub create_processing_profile_id {
    my $p = Genome::Test::Factory::ProcessingProfile::ImportedVariationList->setup_object();
    return $p->id;
}

sub create_subject {
    return Genome::Sample->create(name => Genome::Test::Factory::Util::generate_name("test_subject"));
}

1;
