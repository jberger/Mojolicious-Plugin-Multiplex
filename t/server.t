use Mojolicious::Lite;

use Test::More;
use Test::Mojo;

plugin 'Multiplex';

my ($event, $topic, $data);

websocket '/socket' => sub {
  my $c = shift;;
  my $m = $c->multiplex;

  for my $e (qw/subscribe message unsubscribe acknowledge error/) {
    $m->on($e => sub {
      $event = $e;
      (undef, $topic, $data) = @_;
    });
  }
};

my $send_event_ok = sub {
  my ($t, $message, $desc) = @_;
  $desc ||= 'event sent';
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  $event = undef;
  $topic = undef;
  $data  = undef;
  my $sent = 0;
  $t->tx->send($message, sub { $sent = 1 });
  my $timeout = Mojo::IOLoop->timer(1 => sub { $event = 'TIMEOUT' });
  Mojo::IOLoop->one_tick until $event;
  Mojo::IOLoop->remove($timeout);
  $t->success(ok $sent && $event ne 'TIMEOUT');
};

my $t = Test::Mojo->new;
$t->websocket_ok('/socket')
  ->$send_event_ok('sub,mytopic');
is $event, 'subscribe', 'right event';
is $topic, 'mytopic',   'right topic';

$t->$send_event_ok('msg,mytopic,hello world');
is $event, 'message', 'right event';
is $topic, 'mytopic', 'right topic';
is $data, 'hello world', 'right payload';

$t->$send_event_ok('uns,mytopic');
is $event, 'unsubscribe', 'right event';
is $topic, 'mytopic',     'right topic';

$t->$send_event_ok('ack,mytopic,true');
is $event, 'acknowledge', 'right event';
is $topic, 'mytopic',     'right topic';
ok $data, 'right payload';

$t->$send_event_ok('ack,mytopic,false');
is $event, 'acknowledge', 'right event';
is $topic, 'mytopic',     'right topic';
ok defined $data && !$data, 'right payload';

$t->$send_event_ok('ack,mytopic');
is $event, 'acknowledge', 'right event';
is $topic, 'mytopic',     'right topic';
ok !defined $data, 'right payload';

$t->$send_event_ok('ack,mytopic,wat');
is $event, 'error',   'right event';
is $topic, 'mytopic', 'right topic';
is $data->{error}, 'Ack payload not understood', 'correct error message';

$t->$send_event_ok('err,mytopic,argh');
is $event, 'error',   'right event';
is $topic, 'mytopic', 'right topic';
is $data->{error}, 'Client error', 'correct error message';
is $data->{message}{payload}, 'argh', 'correct error payload';

$t->$send_event_ok('wat,mytopic,argh');
is $event, 'error',   'right event';
is $topic, 'mytopic', 'right topic';
is $data->{error}, 'Message type not understood', 'correct error message';

$t->finish_ok;

done_testing;

