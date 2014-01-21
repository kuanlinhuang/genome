#!/usr/bin/env genome-perl
use strict;
use warnings;

use Test::More;
use above "Genome";
use Genome::Utility::Test;
use Carp::Always;

my $class = 'Genome::Config::Handler::TreeHandler';

use_ok($class);
my $data_dir = Genome::Utility::Test->data_dir($class, 1);
ok(-d $data_dir, "data_dir exists: $data_dir") or die;

eval {
    Genome::Config::Handler::TreeHandler->create(base_path => $data_dir . '/invalid');
};
ok($@, 'TreeHandler will blow up when given multiple leaves at a node');

#get_config order doesn't matter
my $tree_handler = Genome::Config::Handler::TreeHandler->create(base_path => $data_dir . '/valid');
is($tree_handler->get_config('human', 'dna'), $tree_handler->get_config('dna', 'human'));

eval {
    $tree_handler->get_config('blah', 'rna');
};
ok($@, 'get_config blows up when it encounters invalid parameters');

#parameters exist
ok($tree_handler->valid_params('human', 'dna'));

#paramters don't exist
ok(!$tree_handler->valid_params('blah', 'dna'));


eval {
    Genome::Config::Handler::TreeHandler->create(base_path => 'this_dir_doesnt_exist');
};
ok($@, 'TreeHandler dies when given a non-existent directory');

done_testing();