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

sub nonblock {
    my $self=shift;

    my $delay = Mojo::IOLoop::Delay->new;

    $self->app->log->info("starting request, first sleep");

    sleeping_before_any_callbacks();

    $delay->steps(
        sub {
            my $end = $delay->begin;
            $self->app->log->info("in first callback");
            sleeping_in_first_callback();
            $end->();
        },
        sub {
            my $end = $delay->begin;
            $self->app->log->info("in second callback");
            sleeping_in_second_callback();
            $end->();
            $self->render(text=>"Done with second callback, returning this response\n");
        },
    );
    $self->app->log->info("about to wait");
    $delay->wait unless Mojo::IOLoop->is_running;

    $self->app->log->info("returning from controller");
}

sub sleeping_before_any_callbacks {
       sleep 1;
}
sub sleeping_in_first_callback {
       sleep 1;
}
sub sleeping_in_second_callback {
       sleep 1;
}
1;
