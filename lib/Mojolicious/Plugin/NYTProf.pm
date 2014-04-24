package Mojolicious::Plugin::NYTProf;

=head1 NAME

Mojolicious::Plugin::NYTProf - Auto handling of Devel::NYTProf in your Mojolicious app

=head1 VERSION

0.01

=head1 DESCRIPTION

This plugin enables L<Mojolicious> to automatically generate Devel::NYTProf
profiles and routes for your app

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin NYTProf => {
    nytprof => {
      profiles_dir     => '/some_tmp_dir/',
      nytprofhtml_path => '/path/to/nytprofhtml',
    },
  };

  app->start;

=cut

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes 'gettimeofday';
use File::Temp;
use File::Which;
use File::Spec::Functions qw/catfile catdir/;

use Data::Dumper;

our $VERSION = '0.01';

=head1 METHODS

=head2 register

Registers the plugin with your app - this will only do something if the nytprof
key exists in your config hash

  register
      $self->register($app, \%config);

=cut

sub register {
  my ($self, $app, $config) = @_;

  if (my $nytprof = $config->{nytprof}) {

    my $nytprofhtml_path = $nytprof->{nytprofhtml_path}
      || File::Which::which('nytprofhtml');

    -e $nytprofhtml_path
      or die "Could not find nytprofhtml script.  Ensure it's in your path, "
      . "or set the nytprofhtml_path option in your config.";

    # Devel::NYTProf will create an nytprof.out file immediately so
    # we need to assign a tmp file and disable profiling from start
    my $prof_dir = $nytprof->{profiles_dir} || 'nytprof';

    if (! -d $prof_dir) {
      mkdir $prof_dir
        or die "$prof_dir does not exist and cannot create - $!";
    }

    my $tempfh = File::Temp->new(
      ($nytprof->{profiles_dir} ? (DIR => $nytprof->{profiles_dir}) : () ),
    );
    my $file      = $tempfh->filename;
    $tempfh       = undef; # let the file get deleted
    $ENV{NYTPROF} = "start=no:file=$file";

    require Devel::NYTProf;
    unlink $file;

    $self->_add_hooks($app, $config, $nytprofhtml_path);
  }
}

sub _add_hooks {
  my ($self, $app, $config, $nytprofhtml_path) = @_;

  my $nytprof  = $config->{nytprof};
  my $prof_dir = $nytprof->{profiles_dir} || 'nytprof';

  $app->hook(before_dispatch => sub {
    my $c = shift;
    my $path = $c->req->url->to_string;
    return if $path =~ m{^/nytprof}; # viewing profiles
    $path =~ s!^/!!g;
    $path =~ s!/!-!g;
    my ($sec, $usec) = gettimeofday;
    DB::enable_profile(catfile($prof_dir,"nytprof_out_${sec}_${usec}_${path}_$$"));
  });

  $app->hook(after_dispatch => sub {
    DB::disable_profile();
    DB::finish_profile();
  });

  $app->routes->get('/nytprof/html/:dir'
    => [dir => qr/nytprof_out_\d+_\d+.*/]
    => sub { _show_profile(@_,$prof_dir) }
  );

  $app->routes->get('/nytprof/:file'
    => [file => qr/nytprof_out_\d+_\d+.*/]
    => sub { _generate_profile(@_,$prof_dir,$nytprofhtml_path) }
  );

  $app->routes->get('/nytprof' => sub { _list_profiles(@_,$prof_dir) });
}

sub _list_profiles {
  my $self = shift;
  my $prof_dir = shift;

  $self->stash(profiles => [_profiles($prof_dir)]);
  my $ep = <<'EndOfEp';
<html>
  <head>
    <title>NYTProf profile run list</title>
  </head>
  <body>
    <h1>Profile run list</h1>
    % if (@{$profiles}) {
      <p>Select a profile run output from the list to view the HTML reports as
  produced by <tt>Devel::NYTProf</tt>.</p>
      <ul>
      % for (@{$profiles}) {
      <li>
        <a href="<%= $_->{url} %>"><%= $_->{label} %></a>
          (PID <%= $_->{pid} %>, <%= $_->{created} %>, <%= $_->{duration} %>)
      </li>
      % }
      </ul>
    % } else {
      <p>No profiles found</p>
    %}
  </body>
</html>
EndOfEp

  $self->render(inline => $ep);
}

sub _profiles {
  my $prof_dir = shift;

  require Devel::NYTProf::Data;
  opendir my $dirh, $prof_dir
      or die "Unable to open profiles dir $prof_dir - $!";
  my @files = grep { /^nytprof_out/ } readdir $dirh;
  closedir $dirh;

  my @profiles;

  for my $file ( sort {
    (stat catfile($prof_dir,$b))[10] <=> (stat catfile($prof_dir,$a))[10]
  } @files ) {
    my $profile;
    my $filepath = catfile($prof_dir,$file);
    my $label = $file;
    $label =~ s{nytprof\.out\.(\d+)\.(\d+)\.}{};
    my ($sec, $usec) = ($1,$2);
    $label =~ s{\.}{/}g;
    $label =~ s{/(\d+)$}{};
    my $pid = $1;

    my ($nytprof,$duration);
    eval { $nytprof = Devel::NYTProf::Data->new({filename => $filepath}); };

    $profile->{duration} = $nytprof
      ? sprintf('%.4f secs', $nytprof->attributes->{profiler_duration})
      : '??? seconds - corrupt profile data?';

    @{$profile}{qw/file url pid created label/}
      = ($file,"/nytprof/$file",$pid,scalar localtime($sec),$label);
    push(@profiles,$profile);
  }

  return @profiles;
}

sub _generate_profile {
  my $self = shift;
  my $htmldir = my $prof_dir = shift;
  my $nytprofhtml_path = shift;

  my $file    = $self->stash('file');
  my $profile = catfile($prof_dir, $file);
  return $self->render_not_found if !-f $profile;
  
  foreach my $sub_dir ('html',$file) {
    $htmldir = catfile($htmldir, $sub_dir);

    if (! -d $htmldir) {
      mkdir $htmldir
        or die "$htmldir does not exist and cannot create - $!";
    }
  }

  if (! -f catfile($htmldir, 'index.html')) {
    system($nytprofhtml_path, "--file=$profile", "--out=$htmldir");

    if ($? == -1) {
      die "'$nytprofhtml_path' failed to execute: $!";
    } elsif ($? & 127) {
      die sprintf "'%s' died with signal %d, %s coredump",
        $nytprofhtml_path,,($? & 127),($? & 128) ? 'with' : 'without';
    } elsif ($? != 0) {
      die sprintf "'%s' exited with value %d", 
        $nytprofhtml_path, $? >> 8;
    }
  }

  $self->redirect_to("/nytprof/html/$file");
}

sub _show_profile {
  my $self = shift;
  my $prof_dir = shift;
  my $dir = $self->stash('dir');

  $self->render_static("$prof_dir/html/$dir/index.html");
}

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

=cut

1;

# vim: ts=2:sw=2:et
