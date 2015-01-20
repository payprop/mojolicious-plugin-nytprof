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

1;
