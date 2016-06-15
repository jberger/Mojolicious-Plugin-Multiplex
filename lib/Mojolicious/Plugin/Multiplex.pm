package Mojolicious::Plugin::Multiplex;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Transaction::WebSocket::Multiplex;

sub register {
  my ($plugin, $app, $conf) = @_;

  $app->helper(multiplex => sub {
    my $c = shift;
    my $tx = $c->tx;
    return undef unless $tx->is_websocket;
    $c->rendered(101) unless $tx->established;
    return $c->stash->{'multiplex.instance'} ||= Mojo::Transaction::WebSocket::Multiplex->new(tx => $tx);
  });
}

1;

