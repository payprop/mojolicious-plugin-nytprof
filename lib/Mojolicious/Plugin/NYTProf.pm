package Mojolicious::Plugin::NYTProf;

=head1 NAME

Mojolicious::Plugin::NYTProf - Auto handling of Devel::NYTProf in your Mojolicious app

=head1 VERSION

0.09

=head1 DESCRIPTION

This plugin enables L<Mojolicious> to automatically generate Devel::NYTProf
profiles and routes for your app, it has been inspired by
L<Dancer::Plugin::NYTProf>

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin NYTProf => {
    nytprof => {
      ... # see CONFIGURATION
    },
  };

  app->start;

Or

  use Mojo::Base 'Mojolicious';

  ...

  sub startup {
    my $self = shift;

    ...

    my $mojo_config = $self->plugin('Config');
    $self->plugin(NYTProf => $mojo_config);
  }

Then run your app. Profiles generated can be seen by visting /nytprof and reports
will be generated on the fly why you click on a specific profile.

=cut

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes 'gettimeofday';
use File::Temp;
use File::Which;
use File::Spec::Functions qw/catfile catdir/;

our $VERSION = '0.09';

=head1 METHODS

=head2 register

Registers the plugin with your app - this will only do something if the nytprof
key exists in your config hash

  $self->register($app, \%config);

=head1 HOOKS AND Devel::NYTProf

The plugin adds hooks to control the level of profiling, Devel::NYTProf profiling
is started using a before_routes hook and the stopped with an after_dispatch hook.

The consequence of this is that you should see profiling only for your routes and
rendering code and will not see most of the actual Mojolicious framework detail.

You can override the hooks used to control when the profiling runs, see the
CONFIGURATION section below.

=head1 CONFIGURATION

Here's what you can control in myapp.conf:

  {
    # Devel::NYTProf will only be loaded, and profiling enabled, if the nytprof
    # key is present in your config file, so either remove it or comment it out
    # to completely disable profiling.
    nytprof => {

      # path to your nytprofhtml script (installed as part of Devel::NYTProf
      # distribution). the plugin will do its best to try to find this so this
      # is optional, just set if you have a none standard path
      nytprofhtml_path => '/path/to/nytprofhtml',

      # path to store Devel::NYTProf output profiles and generated html pages.
      # options, defaults to "/path/to/your/app/root/dir/nytprof"
      profiles_dir => '/path/to/nytprof/profiles/'

      # set this to true to allow the plugin to run when in production mode
      # the default value is 0 so you can deploy your app to prod without
      # having to make any changes to config/plugin register
      allow_production => 0,

      # Devel::NYTProf environment options, see the documentation at
      # https://metacpan.org/pod/Devel::NYTProf#NYTPROF-ENVIRONMENT-VARIABLE
      # for a complete list. N.B. you can't supply start or file as these
      # are used internally in the plugin so will be ignored if passed
      env => {
        trace => 1,
        log   => "/path/to/foo/",
        ....
      },

      # when to enable Devel::NYTProf profiling - the pre_hook will run
      # to enable_profile and the post_hook will run to disable_profile
      # and finish_profile. the values show here are the defaults so you
      # do not need to provide these options
      #
      # N.B. there is nothing stopping you reversing the order of the
      # hooks, which would cause the Mojolicious framework code to be
      # profiled, or providing hooks that are the same or even invalid. these
      # config options should probably be used with some care
      pre_hook  => 'before_routes',
      post_hook => 'after_dispatch',
    },
  }

=cut

sub register {
  my ($self, $app, $config) = @_;

  if (my $nytprof = $config->{nytprof}) {

    return if $app->mode eq 'production' and ! $nytprof->{allow_production};

    my $nytprofhtml_path = $nytprof->{nytprofhtml_path}
      || File::Which::which('nytprofhtml');

    if ( ! $nytprofhtml_path ) {
      # last ditch attempt to find nytprofhtml, assume in same dir as perl
      $nytprofhtml_path = $^X;
      $nytprofhtml_path =~ s/perl[\d\.]*$/nytprofhtml/;
    }

    -e $nytprofhtml_path
      or die "Could not find nytprofhtml script.  Ensure it's in your path, "
      . "or set the nytprofhtml_path option in your config.";

    # Devel::NYTProf will create an nytprof.out file immediately so
    # we need to assign a tmp file and disable profiling from start
    my $prof_dir = $nytprof->{profiles_dir} || 'nytprof';

    foreach my $dir ($prof_dir,catfile($prof_dir,'profiles')) {
      if (! -d $dir) {
        mkdir $dir
          or die "$dir does not exist and cannot create - $!";
      }
    }

    # disable config option is undocumented, it allows testing where we
    # don't actually load or run Devel::NYTProf
    unless ($nytprof->{disable}) {
      my $tempfh = File::Temp->new(
        ($nytprof->{profiles_dir} ? (DIR => $nytprof->{profiles_dir}) : () ),
      );
      my $file      = $tempfh->filename;
      $tempfh       = undef; # let the file get deleted

      # https://metacpan.org/pod/Devel::NYTProf#NYTPROF-ENVIRONMENT-VARIABLE
      # options for Devel::NYTProf - any can be passed but will always set
      # the start and file options here
      $nytprof->{env}{start} = 'no';
      $nytprof->{env}{file}  = $file;

      $ENV{NYTPROF} = join( ':',
        map { "$_=" . $nytprof->{env}{$_} }
          keys %{ $nytprof->{env} }
      );

      require Devel::NYTProf;
      unlink $file;
    }

    $self->_add_hooks($app, $config, $nytprofhtml_path);
  }
}

sub _add_hooks {
  my ($self, $app, $config, $nytprofhtml_path) = @_;

  my $nytprof   = $config->{nytprof};
  my $prof_dir  = $nytprof->{profiles_dir} || 'nytprof';
  my $pre_hook  = $nytprof->{pre_hook}     || 'before_routes';
  my $post_hook = $nytprof->{post_hook}    || 'after_dispatch';
  my $disable   = $nytprof->{disable}      || 0;

  # add the nytprof/html directory to the static paths
  # so we can serve these without having to add routes
  push @{$app->static->paths},catfile($prof_dir,'html');

  # put the actual profile files into a profiles sub directory
  # to avoid confusion with the *dirs* in nytprof/html
  my $prof_sub_dir = catfile( $prof_dir,'profiles' );

  $app->hook($pre_hook => sub {

    # figure args based on what the hook is
    my ($tx, $app, $next, $c, $path);

    if ($pre_hook eq 'after_build_tx') {
      ($tx, $app) = @_[0,1];
      $path = $pre_hook; # TODO - need better identifier for this?
    } elsif ($pre_hook =~ /around/) {
      ($next, $c) = @_[0,1];
    } else {
      $c = $_[0];
      $path = $c->req->url->to_string;
      return if $c->stash->{'mojo.static'}; # static files
    }

    return if $path =~ m{^/nytprof}; # viewing profiles
    $path =~ s!^/!!g;
    $path =~ s!/!-!g;

    my ($sec, $usec) = gettimeofday;
    DB::enable_profile(
      catfile($prof_sub_dir,"nytprof_out_${sec}_${usec}_${path}_$$")
    ) unless $disable;
    return $next->() if $pre_hook =~ /around/;
  });

  $app->hook($post_hook => sub {
    DB::disable_profile() unless $disable;
    DB::finish_profile() unless $disable;
    # first arg is $next if the hook matches around
    return shift->() if $post_hook =~ /around/;
  });

  $app->routes->get('/nytprof/profiles/:file'
    => [file => qr/nytprof_out_\d+_\d+.*/]
    => sub { _generate_profile(@_,$prof_dir,$nytprofhtml_path) }
  );

  $app->routes->get('/nytprof' => sub { _list_profiles(@_,$prof_sub_dir) });
}

sub _list_profiles {
  my $self = shift;
  my $prof_dir = shift;

  my @profiles = _profiles($prof_dir);

  # could use epl here, but users might be using a different Template engine
  my $list = @profiles
    ? '<p>Select a profile run output from the list to view the HTML reports as produced by <tt>Devel::NYTProf</tt>.</p><ul>'
    : '<p>No profiles found</p>';

  foreach (@profiles) {
    $list .= qq{
      <li>
        <a href="$_->{url}">$_->{label}</a>
          (PID $_->{pid}, $_->{created}, $_->{duration})
      </li>
    };
  }

  $list .= '</ul>' if $list !~ /No profiles found/;

  my $html = <<"EndOfEp";
<html>
  <head>
    <title>NYTProf profile run list</title>
  </head>
  <body>
    <h1>Profile run list</h1>
      $list
  </body>
</html>
EndOfEp

  $self->render(text => $html);
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
    $label =~ s{nytprof_out_(\d+)_(\d+)_}{};
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
      = ($file,"/nytprof/profiles/$file",$pid,scalar localtime($sec),$label);
    push(@profiles,$profile);
  }

  return @profiles;
}

sub _generate_profile {
  my $self = shift;
  my $htmldir = my $prof_dir = shift;
  my $nytprofhtml_path = shift;

  my $file    = $self->stash('file');
  my $profile = catfile($prof_dir,'profiles',$file);
  return $self->render_not_found if !-f $profile;
  
  foreach my $sub_dir (
    $htmldir,
    catfile($htmldir,'html'),
    catfile($htmldir,'html',$file),
  ) {
    if (! -d $sub_dir) {
      mkdir $sub_dir
        or die "$sub_dir does not exist and cannot create - $!";
    }
  }

  $htmldir = catfile($htmldir,'html',$file);

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

  $self->redirect_to("/${file}/index.html");
}

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation
please raise an issue / pull request:

    https://github.com/leejo/mojolicious-plugin-nytprof

=cut

1;

# vim: ts=2:sw=2:et
