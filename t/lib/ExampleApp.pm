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
    $self->routes->any('/t5')->to('ExampleController#t5');
}

1;
