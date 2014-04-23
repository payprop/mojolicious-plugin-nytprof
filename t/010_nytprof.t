#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Mojo;

use File::Spec::Functions 'catfile';
use FindBin '$Bin';

my $prof_dir = catfile($Bin, "nytprof");

my @existing_profs = glob "$prof_dir/nytprof*";
unlink $_ for @existing_profs;

{
  use Mojolicious::Lite;

  dies_ok(
    sub {
      plugin NYTProf => {
        nytprof => {
          nytprofhtml_path => '/tmp/bad'
        },
      };
    },
    'none existent nytprofhtml dies',
  );

  like( $@,qr/Could not find nytprofhtml script/i,' ... with sensible error' );

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

$t->get_ok('/nytprof')
  ->status_is(200)
  ->content_is("list nytprof profiles\n");

ok(
  !-e catfile($prof_dir, "nytprof.out.some_route.$$"),
  'nytprof.out file not created'
);

$t->get_ok('/some_route')
  ->status_is(200)
  ->content_is("basic stuff\n");

ok(
  -e catfile($prof_dir, "nytprof.out.some_route.$$"),
  'nytprof.out file created'
);

$t->get_ok("/nytprof/nytprof.out.some_route.$$")
  ->status_is(200)
  ->content_is("generate nytprof profile\n");

$t->get_ok("/nytprof/html/nytprof.out.some_route.$$")
  ->status_is(200)
  ->content_is("show nytprof profile\n");

done_testing();
