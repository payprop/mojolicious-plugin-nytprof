#!perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME          => 'Mojolicious::Plugin::NYTProf',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/NYTProf.pm',
  VERSION_FROM  => 'lib/Mojolicious/Plugin/NYTProf.pm',
  AUTHOR        => 'Lee Johnson <leejo@cpan.org>',
  LICENSE       => 'perl',
  PREREQ_PM => {
    'Devel::NYTProf' => '5.06',
    'Mojolicious'    => '4.83',
    'File::Which'    => 0,
  },
  BUILD_REQUIRES => {
    'Test::More'      => 0,
    'Test::Exception' => 0.32,
  },
  META_MERGE => {
    resources => {
      license    => 'http://dev.perl.org/licenses/',
      homepage   => 'https://metacpan.org/module/Mojolicious::Plugin::NYTProf',
      bugtracker => 'https://github.com/leejo/mojolicious-plugin-nytprof/issues',
      repository => 'https://github.com/leejo/mojolicious-plugin-nytprof'
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
