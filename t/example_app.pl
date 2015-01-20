#!/usr/bin/env perl
 
# in reality this would be in a separate file
package ExampleApp;
 
# automatically enables "strict", "warnings", "utf8" and perl 5.10 features
use Mojo::Base qw( Mojolicious );
 
sub startup {
    my ( $self ) = @_;
 
    $self->plugin(NYTProf => {
        nytprof => {
            trace => 1,
            log => '/tmp/nytprof.log',
            pre_hook  => 'before_routes',
            post_hook => 'after_dispatch',
        },
    });

    $self->routes->any('/t1')->to('ExampleController#t1');
    $self->routes->any('/t2')->to('ExampleController#t2');
    $self->routes->any('/t3')->to('ExampleController#t3');
    $self->routes->any('/t4')->to('ExampleController#t4');
}
 
# in reality this would be in a separate file
package ExampleApp::ExampleController;
 
use Mojo::Base 'Mojolicious::Controller';
 
sub t1 {
    my $self=shift;
    $self->render(text=>'ok t1');
}
sub t2 {
    my $self=shift; # implicit render example/t2.html.ep
}
sub t3 {
    my $self=shift;
    $self->render;  # explicit render example/t3.html.ep
}
sub t4 {
    my $self=shift;
    $self->render(template=>'t3');
}

 
# in reality this would be in a separate file
package main;
 
use strict;
use warnings;
 
use Mojolicious::Commands;
 
Mojolicious::Commands->start_app( 'ExampleApp' );

__DATA__

@@ example_controller/t2.html.ep
ok t2

@@ example_controller/t3.html.ep
ok t3

@@ t3.html.ep
ok t3
