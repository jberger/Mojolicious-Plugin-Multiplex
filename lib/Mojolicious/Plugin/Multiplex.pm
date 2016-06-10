package Mojolicious::Plugin::Multiplex;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::WebSocket::Multiplex;

sub register {
  my ($plugin, $app, $conf) = @_;

  $app->helper(multiplex => sub {
    my $c = shift;
    return $c->stash->{'multiplex.instance'} ||= Mojo::WebSocket::Multiplex->new($c);
  });
}

1;

