#!perl

use strict;
use warnings;

use Test::More;

use File::Find;
use File::Which;

my $nytprofhtml_path = File::Which::which('nytprofhtml');

if ( ! $nytprofhtml_path ) {
  # last ditch attempt to find nytprofhtml, assume in same dir as perl
  $nytprofhtml_path = $^X;
  $nytprofhtml_path =~ s/perl[\d\.]*$/nytprofhtml/;
}

BAIL_OUT( "Couldn't find nytprofhtml in PATH or in same location as $^X" )
	if ! -e $nytprofhtml_path;

ok( -e $nytprofhtml_path );
done_testing();
