#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Mojo;

use File::Spec::Functions 'catfile';
use FindBin '$Bin';
use File::Path qw'rmtree';

use Mojolicious::Plugin::NYTProf;
Mojolicious::Plugin::NYTProf::_find_nytprofhtml()
	|| plan skip_all => "Couldn't find nytprofhtml in PATH or in same location as $^X";

# run this test with -v and pipe output to a log file to
# see the difference in run time between the first calls
# to the route and the last calls to the route. see GH #5

plan skip_all => 'DEV_TESTING_PLUGIN_NYTPROF required'
	if ! $ENV{DEV_TESTING_PLUGIN_NYTPROF};

my $prof_dir = catfile($Bin,"nytprof");

my @existing_profs = glob "$prof_dir/profiles/nytprof*";
unlink $_ for @existing_profs;
my @existing_runs = glob "$prof_dir/html/nytprof*";
rmtree($_) for @existing_runs;

{
  use Mojolicious::Lite;

  plugin NYTProf => {
    nytprof => {
      profiles_dir => $prof_dir,
    },
  };

  any 'some_route' => sub {
    my ($self) = @_;
    $self->render(text => "basic stuff\n");
  };
}

my $t = Test::Mojo->new;

$t->get_ok('/some_route')
  ->status_is(200)
  ->content_is("basic stuff\n") for 1 .. 30000;

done_testing();
