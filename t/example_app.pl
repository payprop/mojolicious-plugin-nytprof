#!/usr/bin/env perl
 
use lib 'lib';
use ExampleApp;
 
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
