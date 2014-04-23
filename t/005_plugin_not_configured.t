#!perl

use strict;
use warnings;

use Test::More;
use Test::Mojo;

{
  use Mojolicious::Lite;
  plugin NYTProf => {};

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
