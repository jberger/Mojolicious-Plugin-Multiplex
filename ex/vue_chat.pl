use Mojolicious::Lite;
use Mojo::Pg;

plugin 'Multiplex';
helper pg => sub { state $pg = Mojo::Pg->new('postgresql://hubble:hubble@/hubble') };

get '/' => 'chat';

websocket '/channel' => sub {
  my $c = shift;
  $c->inactivity_timeout(3600);

  my $pubsub = $c->pg->pubsub;
  my $events = $c->multiplex->attach;

  my %channels;
  $events->on(sub => sub {
    my (undef, $channel) = @_;
    return if exists $channels{$channel};
    $channels{$channel} = $pubsub->listen($channel => sub {
      my ($pubsub, $payload) = @_;
      $c->multiplex->send($channel => $payload);
    });
  });

  $events->on(msg => sub {
    my (undef, $channel, $payload) = @_;
    $pubsub->notify($channel => $payload);
  });

  $events->on(uns => sub {
    my (undef, $channel) = @_;
    return unless my $cb = delete $channels{$channel};
    $pubsub->unlisten($channel => $cb);
  });

  $c->on(finish => sub {
    $pubsub->unlisten($_ => $channels{$_}) for keys %channels;
  });
};

app->start;

__DATA__

@@ chat.html.ep
%= javascript 'https://cdnjs.cloudflare.com/ajax/libs/vue/1.0.20/vue.js'
%= javascript 'https://cdn.rawgit.com/sockjs/websocket-multiplex/master/multiplex_client.js'
%= stylesheet begin
  .chat-pane {
    border-style: solid;
    border-color: black;
    border-width: thin;
    padding: 5px;
  }
  form {
    display: inline;
  }
% end
<div id="chat">
  Username: <input v-model="username"><br>
  Add Channel: <form @submit.prevent="add_channel"><input v-model="new_channel"></form></br>
  <template v-for="name in channels">
    <chat-pane :name="name"></chat-pane>
  </template>
</div>
<template id="chat-template">
  <div class="chat-pane">
    <span>
      Send to {{name}}: <form @submit.prevent="send"><input v-model="current"></form>
      <button @click.prevent="close">x</button>
    </span>
    <div id="log"><p v-for="m in messages">{{m.username}}: {{m.message}}</p></div>
  </div>
</template>

<script>
  Vue.component('chat-pane', {
    template: '#chat-template',
    data: function() { return {
      current: '',
      messages: [],
    }},
    props: {
      name: {
        type: String,
        required: true,
      }
    },
    computed: {
      socket: function() {
        var self = this;
        var socket = self.$parent.multiplexer.channel(self.name);
        socket.onmessage = function (e) { self.messages.push(JSON.parse(e.data)) };
        return socket;
      },
    },
    methods: {
      close: function(){
        this.socket.close();
        this.$parent.channels.$remove(this.name);
      },
      send: function() {
        this.socket.send(JSON.stringify({username: this.$parent.username, message: this.current}));
        this.current = '';
      },
    },
    ready: function() { this.socket },
  });

  var vm = new Vue({
    el: '#chat',
    data: {
      username: '',
      new_channel: '',
      url: '<%= url_for('channel')->to_abs %>',
      channels: [],
    },
    computed: {
      ws: function() {
        var ws = new WebSocket(this.url);
        ws.onopen = function() { console.log('websocket open') };
        return ws;
      },
      multiplexer: function() { return new WebSocketMultiplex(this.ws) },
    },
    methods: {
      add_channel: function() {
        this.channels.push(this.new_channel);
        this.new_channel = '';
      },
    },
    ready: function() { this.ws; }
  });
</script>
