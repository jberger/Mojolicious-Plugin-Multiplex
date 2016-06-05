package Mojolicious::Plugin::Multiplex;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::EventEmitter;
use Mojo::JSON;

sub register {
  my ($plugin, $app, $conf) = @_;

  $app->helper('multiplex.attach' => sub {
    my ($c, $cb) = (shift, pop);
    my $tx = $c->tx;
    return unless $c->tx->is_websocket;

    my $events = Mojo::EventEmitter->new;
    $c->on(text => sub {
      my ($tx, $bytes) = @_;

      my ($type, $channel, $payload) = split /,/, $bytes, 3;

      return $c->app->log->warn("unknown multiplex message type $type")
        unless $type =~ /^sub|msg|uns$/;

      $events->emit($type, $channel, $payload);
    });

    return $events;
  });

  $app->helper('multiplex.send' => sub {
    my ($c, $channel, $payload) = @_;
    $c->send("msg,$channel,$payload");
  });

}

1;

