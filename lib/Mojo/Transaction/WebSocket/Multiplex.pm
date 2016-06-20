package Mojo::Transaction::WebSocket::Multiplex;

use Mojo::Base 'Mojo::EventEmitter';

use Carp ();
use Scalar::Util ();

has tx => sub { Carp::croak 'tx is required' };

my %map = (
  sub => 'subscribe',
  msg => 'message',
  uns => 'unsubscribe',
);

sub new {
  my $self = shift->SUPER::new(@_);
  my $tx = $self->tx;
  return undef unless $tx->is_websocket;
  Scalar::Util::weaken $self->{tx};

  $tx->on(text => sub {
    my ($tx, $bytes) = @_;
    my ($type, $channel, $payload) = split /,/, $bytes, 3;

    my $e = $map{$type};
    $self->emit($e ? $e : (unknown => $type), $channel, $payload);
  });

  $tx->on(finish => sub { shift; $self->emit(finish => @_) });

  return $self;
}

sub acknowledge {
  my ($self, $chan, $payload, $cb) = @_;
  return unless my $tx = $self->tx;
  $payload = defined($payload) ? $payload ? ',true' : ',false' : '';
  $tx->send("ack,$chan$payload", $cb ? sub { $self->$cb() } : ());
}

sub send {
  my ($self, $chan, $payload, $cb) = @_;
  return unless my $tx = $self->tx;
  $tx->send("msg,$chan,$payload", $cb ? sub { $self->$cb() } : ());
}

1;

