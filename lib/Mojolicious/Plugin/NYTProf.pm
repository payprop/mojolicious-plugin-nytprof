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

use Mojo::Base 'Mojolicious::Plugin';
use File::Temp;
use File::Which;
use File::Spec::Functions 'catfile';

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

    $self->_add_hooks($app, $config);
  }
}

sub _add_hooks {
  my ($self, $app, $config) = @_;

  my $nytprof  = $config->{nytprof};
  my $prof_dir = $nytprof->{profiles_dir} || 'nytprof';

  $app->hook(before_dispatch => sub {
    my $c = shift;
    my $path = $c->req->url->to_string;
    return if $path =~ m{^/nytprof}; # viewing profiles
    $path =~ s!^/!!g;
    $path =~ s!/!-!g;
    DB::enable_profile(catfile($prof_dir,"nytprof.out.$path.$$"));
  });

  $app->hook(after_dispatch => sub {
    DB::disable_profile();
    DB::finish_profile();
  });

  $app->routes->any('/nytprof/:file'
    #=> [file => qr/^nytprof\.out\..*/]
    => [file => qr/\w+/]
    => \&_generate_profile
  );
  $app->routes->any('/nytprof/html/:file' => \&_show_profile);
  $app->routes->any('/nytprof' => sub { _list_profiles(@_,$prof_dir) });
}

sub _list_profiles {
  my $self = shift;
  my $prof_dir = shift;

  require Devel::NYTProf::Data;
  opendir my $dirh, $prof_dir
      or die "Unable to open profiles dir $prof_dir - $!";
  my @files = grep { /^nytprof\.out/ } readdir $dirh;
  closedir $dirh;

  $self->render(text => "list nytprof profiles\n");
}

sub _generate_profile {
  my $self = shift;

  my $file = $self->param('file');
warn "-->$file";

  $self->render(text => "generate nytprof profile\n");
}

sub _show_profile {
  my $self = shift;

  $self->render(text => "show nytprof profile\n");
}

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

=cut

1;

# vim: ts=2:sw=2:et
