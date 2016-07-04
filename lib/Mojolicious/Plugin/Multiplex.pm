package Mojolicious::Plugin::Multiplex;

use Mojo::Base 'Mojolicious::Plugin';

use Mojolicious::Plugin::Multiplex::Multiplexer;

sub register {
  my ($plugin, $app, $conf) = @_;

  push @{ $app->static->classes }, __PACKAGE__;

  $app->helper(multiplex => sub {
    my $c = shift;
    my $tx = $c->tx;
    return undef unless $tx->is_websocket;
    $c->rendered(101) unless $tx->established;
    return $c->stash->{'multiplex.multiplexer'} ||= Mojolicious::Plugin::Multiplex::Multiplexer->new(tx => $tx);
  });
}

1;

__DATA__

@@ websocket_multiplex.js

// original at https://github.com/sockjs/websocket-multiplex/blob/master/multiplex_client.js

var WebSocketMultiplex = (function(){


    // ****

    var DumbEventTarget = function() {
        this._listeners = {};
    };
    DumbEventTarget.prototype._ensure = function(type) {
        if(!(type in this._listeners)) this._listeners[type] = [];
    };
    DumbEventTarget.prototype.addEventListener = function(type, listener) {
        this._ensure(type);
        this._listeners[type].push(listener);
    };
    DumbEventTarget.prototype.emit = function(type) {
        this._ensure(type);
        var args = Array.prototype.slice.call(arguments, 1);
        if(this['on' + type]) this['on' + type].apply(this, args);
        for(var i=0; i < this._listeners[type].length; i++) {
            this._listeners[type][i].apply(this, args);
        }
    };


    // ****

    var WebSocketMultiplex = function(ws) {
        var that = this;
        this.ws = ws;
        this.channels = {};
        this.ws.addEventListener('message', function(e) {
            var t = e.data.split(',');
            var type = t.shift(), name = t.shift(),  payload = t.join();
            if(!(name in that.channels)) {
                return;
            }
            var sub = that.channels[name];

            switch(type) {
            case 'sta':
                if (payload === 'true') {
                    var was_open = sub.readyState === WebSocket.OPEN;
                    sub.readyState = WebSocket.OPEN;
                    if (! was_open) { sub.emit('open') }
                } else if (payload === 'false') {
                    var was_closed = sub.readyState === WebSocket.CLOSED;
                    sub.readyState = WebSocket.CLOSED;
                    delete that.channels[name];
                    if (! was_closed) { sub.emit('close', {}) }
                }
                //TODO implement status request handler
                break;
            case 'uns':
                delete that.channels[name];
                sub.emit('close', {});
                break;
            case 'msg':
                sub.emit('message', {data: payload});
                break;
            case 'err':
                sub.emit('error', payload);
                break;
            }
        });
    };
    WebSocketMultiplex.prototype.channel = function(raw_name) {
        return this.channels[escape(raw_name)] =
            new Channel(this.ws, escape(raw_name), this.channels);
    };


    var Channel = function(ws, name, channels) {
        DumbEventTarget.call(this);
        var that = this;
        this.ws = ws;
        this.name = name;
        this.channels = channels;
        this.readyState = WebSocket.CONNECTING;
        var onopen = function() { that.ws.send('sub,' + that.name) };
        if(ws.readyState > WebSocket.CONNECTING) {
            setTimeout(onopen, 0);
        } else {
            this.ws.addEventListener('open', onopen);
        }
    };
    Channel.prototype = new DumbEventTarget();

    Channel.prototype.send = function(data) {
        this.ws.send('msg,' + this.name + ',' + data);
    };
    Channel.prototype.close = function() {
        this.readyState = WebSocket.CLOSING;
        this.ws.send('uns,' + this.name);
    };

    return WebSocketMultiplex;
})();

