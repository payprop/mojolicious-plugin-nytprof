#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Mojo;

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
      profiles_dir     => '/tmp',
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
  ->content_is("basic stuff\n");

done_testing();
