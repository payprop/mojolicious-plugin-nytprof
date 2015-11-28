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

my $prof_dir = catfile($Bin,"nytprof");

my @existing_profs = glob "$prof_dir/profiles/nytprof*";
unlink $_ for @existing_profs;
my @existing_runs = glob "$prof_dir/html/nytprof*";
rmtree($_) for @existing_runs;
unlink(catfile($prof_dir,"nytprof.trace"));

{
  use Mojolicious::Lite;
  $prof_dir =~ s{\\}{/}g;   #not found the right place to fix this in plugin source!
  plugin NYTProf => {
    nytprof => {
      profiles_dir => $prof_dir,
      env => {
        trace => 1,
        log => "$prof_dir/nytprof.trace",
      }
    },
  };

  any 'some_route' => sub {
    my ($self) = @_;
    $self->render(text => "basic stuff\n");
  };
}

my $t = Test::Mojo->new;

#fake MSWin32
{
	$t->app->hook(before_dispatch => sub { $^O = 'MSWin32'; });
    $t->get_ok(
        '/some_route?arg1=test&arg2=colon:colon&arg3=' . ( 'v' x 260 ) )
        ->status_is(200)->content_is("basic stuff\n");

    my (@profiles)
        = Mojolicious::Plugin::NYTProf::_profiles(
        catfile( $prof_dir, 'profiles' ) );
    is( scalar(@profiles), 1, 'generate 1 profile' );
    my $file = $profiles[0]{file};
    unlike( $file, qr/[?:]/, 'file name contain valid chars' );
    cmp_ok( length($file), '<=', 260,
        'long file name truncated under MSWin32' );
}

ok( -e catfile($prof_dir,'nytprof.trace'),' ... env vars used' );

done_testing();
