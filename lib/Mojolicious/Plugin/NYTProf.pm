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

use Data::Dumper;

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
    my $tempfh = File::Temp->new(
      ($nytprof->{profiles_dir} ? (DIR => $nytprof->{profiles_dir}) : () ),
    );
    my $file      = $tempfh->filename;
    $tempfh       = undef; # let the file get deleted
    $ENV{NYTPROF} = "start=no:file=$file";

    require Devel::NYTProf;
    unlink $file;
  }
}

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

=cut

1;

# vim: ts=2:sw=2:et
