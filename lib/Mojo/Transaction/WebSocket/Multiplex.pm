package Mojo::Transaction::WebSocket::Multiplex;

use Mojo::Base 'Mojo::EventEmitter';

use Carp ();
use Scalar::Util ();

has tx => sub { Carp::croak 'tx is required' };

my %map = (
  sub => 'subscribe',
  msg => 'message',
  uns => 'unsubscribe',
  err => 'client_error',
  ack => 'acknowledge',
);

sub new {
  my $self = shift->SUPER::new(@_);
  my $tx = $self->tx;
  return undef unless $tx->is_websocket;
  Scalar::Util::weaken $self->{tx};

  $tx->on(text => sub {
    my ($tx, $bytes) = @_;
    my ($type, $topic, $payload) = split /,/, $bytes, 3;

    my $e = $map{$type};
    my @args = ($topic);
    if (! defined $e) {
      $e = 'message_error';
      unshift @args, "Message type not understood: $type";
    } elsif ($e eq 'message' || $e eq 'client_error') {
      push @args, $payload;
    } elsif ($e eq 'acknowledge') {
      no warnings 'uninitialized';
      push @args,
        $payload eq 'true'  ? 1 :
        $payload eq 'false' ? 0 :
        ! (defined $payload || length $payload)  ? undef :
        do { $e = 'message_error'; "Ack payload not understood: $payload" };
    }
    $self->emit($e, @args);
  });

  $tx->on(finish => sub { $self->emit(finish => @_) });

  return $self;
}

sub acknowledge {
  my ($self, $topic, $payload, $cb) = @_;
  $payload = defined($payload) ? $payload ? ',true' : ',false' : '';
  $self->_send("ack,$topic$payload", $cb);
}

sub send {
  my ($self, $topic, $payload, $cb) = @_;
  $self->_send("msg,$topic,$payload", $cb);
}

sub send_error {
  my ($self, $topic, $payload, $cb) = @_;
  $self->_send("err,$topic,$payload", $cb);
}

sub _send {
  my ($self, $msg, $cb) = @_;
  return unless my $tx = $self->tx;
  $tx->send($msg, $cb ? sub { $self->$cb() } : ());
}

1;

=head1 NAME

Mojo::Transaction::WebSocket::Multiplex - Dispatcher class for multiplexing websockets

=head1 SYNOPSIS

  # a simple single-threaded message relay example

  use Mojo::Transaction::WebSocket::Multiplex;
  my $multiplex = Mojo::Transaction::WebSocket::Multiplex->new(tx => $tx);

  my %topics;
  $multiplex->on(message => sub {
    my ($multiplex, $topic, $payload) = @_;
    return unless my $cb = $topics{$topic};
    $multiplex->$cb($topic, $payload);
  });

  $multiplex->on(subscribe => sub {
    my ($multiplex, $topic) = @_;
    $topics{$topic} = sub { shift->send(@_) };
    $multiplex->acknowledge($topic, 1);
  });

  $multiplex->on(unsubscribe => sub {
    my ($multiplex, $topic) = @_;
    delete $topics{$topic};
    $multiplex->acknowledge($topic, 0);
  });

=head1 DESCRIPTION

This class sends and receives messages over a L<websocket transaction|Mojo::Transaction::WebSocket> using a variant of the sockjs websocket multiplex protocol.
This variant defines five message types, they are: C<subscribe>, C<message>, C<unsubscribe>, C<acknowledge>, C<error>.
Note that though the protocol defines an error message, the emitted event is called C<client_error> since L<Mojo::EventEmitter> has a specific meaning for an C<error> event.
Further each message is assigned to a topic (channel) which is used to separate messages by subscribed listener.

=head1 PLEASE NOTE

This class is rather low level and is useful for writing bindings to backend message services like brokers.
Notice that it does not store any connection state information either, which would be the responsibility of the consuming module or script.
An example is given in the distribution for using this class with L<Mojo::Pg::PubSub> to relay JSON messages between web-based chat clients.

As this module is low level it does no character encoding or decoding.
If a topic or payload contains non ascii characters it must be manually encoded or decoded as necessary.
Note further that topics cannot contain a comma due to the limitations of the simple protocol.

=head1 EVENTS

Inherits all of the events from L<Mojo::EventEmitted> and implements the following new ones.

=head2 subscribe / unsubscribe

  $multiplex->on(subscribe => sub { my ($multiplex, $topic) = @_; ... });

Emitted with a topic when the client expresses an interest in subscribing to or leaving the given topic.

A server should respond to this message event with a L</acknowledge> reply indicating the new subscription state.

=head2 message

  $multiplex->on(message => sub { my ($multiplex, $topic, $payload) = @_; ... });

Emitted when a message is received from the client.
It is passed the topic and the payload in original encoded form (bytes).

=head2 acknowledge

  $multiplex->on(acknowledge => sub { my ($multiplex, $topic, $payload) = @_; ... });

Emitted when a client attempts to indicate its own subscription status of a topic (rare) or else requests the subscription status for a given topic.
Emitted with a topic name and either true or false (but defined) value when indicating the state or undefined when requesting a state.

The server may reply to these requests but none is required.
For agreement with an indicated state or sending the requested current state, use L</acknowledge>.
For disagreeing with the indicated state, an error should be sent with L</send_error>.

=head2 client_error

  $multiplex->on(client_error => sub { my ($multiplex, $topic, $payload) = @_; ... });

Emitted when a client sends an error message.
Passed the topic and payload from the message.
The response and handling is up to the particular server implementation and is not specified in the protocol.

=head2 message_error

  $multiplex->on(message_error => sub { my ($multiplex, $topic, $payload) = @_; ... });

Emitted when a client sends a message which is not understood.
Passed the topic and generated error message.
The response and handling is up to the particular server implementation and is not specified in the protocol.

=head2 finish

  $multiplex->on(finish => sub { my ($multiplex, $tx, $code, $reason) = @_; ... });

Emitted when the websocket connection is finished.
This event is proxied from the transaction for convenience.

=head1 ATTRIBUTES

Inherits all of the attributes from L<Mojo::EventEmitter> and implements the following new ones.

=head2 tx

The transaction associated with the websocket.
This should be an instance of L<Mojo::Transaction::WebSocket>.

=head1 METHODS

Inherits all of the methods from L<Mojo::EventEmitter> and implements the following new ones.

=head2 acknowledge

  $multiplex->acknowledge($topic, $state, $cb);

Send the current state of a topic subscription (as in the response from L</subscribe> and L<unsubscrive> or request the client's subscription state (rare).
Takes a topic, a state, and an optional drain callback.
The state variable will be coerced from any true, false or undefined values, where true and false values indicate subscribed or not subscribed respectively.
Undefined propts the client to respond with its own notion of the subscription state, which is a rare thing for a server to do; additionally the client may not implement the response to the request.

=head2 send

  $multiplex->send($topic, $payload, $cb);

Send a message to the client on the given topic.
Takes a topic, a payload, and an optional drain callback.
As mentioned above, neither the topic name or payload are encoded before sending, so be sure to do so manually if necessary.

=head2 send_error

  $multiplex->send_error($topic, $payload, $cb);

Send an error message to the client on the given topic.
Takes a topic, a payload, and an optional drain callback.

