// inspired by and forked from https://github.com/sockjs/websocket-multiplex/blob/master/multiplex_client.js

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
        if (ws instanceof WebSocket) {
            this.ws = ws;
        } else {
            this.ws = null;
            this._url = ws;
        }
        this.channels = {};
        this.open();
    };

    Object.defineProperty(WebSocketMultiplex.prototype, 'url', {
        get: function() { return this._url || this.ws.url },
        set: function(url) { this._url = url },
    });

    WebSocketMultiplex.prototype.open = function() {
        var multiplex = this;

        if (!multiplex.ws || multiplex.ws.readyState > WebSocket.OPEN) {
          multiplex.ws = new WebSocket(multiplex.url);

          multiplex.ws.addEventListener('open', function(e) {
              multiplex.eachChannel(function(channel) {
                  setTimeout(function(){ channel.subscribe() }, 0);
              });
          });
        }

        multiplex.ws.addEventListener('close', function(e) {
            multiplex.eachChannel(function(channel) {
                channel.readyState = WebSocket.CONNECTING;
            });
            setTimeout(function(){ multiplex.open() }, 500);
        });

        multiplex.ws.addEventListener('message', function(e) {
            var t = e.data.split(',');
            var type = t.shift(), name = t.shift(),  payload = t.join();
            if(!(name in multiplex.channels)) {
                return;
            }
            var sub = multiplex.channels[name];

            switch(type) {
            case 'sta':
                if (payload === 'true') {
                    var was_open = sub.readyState === WebSocket.OPEN;
                    sub.readyState = WebSocket.OPEN;
                    if (! was_open) { sub.emit('open') }
                } else if (payload === 'false') {
                    var was_closed = sub.readyState === WebSocket.CLOSED;
                    sub.readyState = WebSocket.CLOSED;
                    delete multiplex.channels[name];
                    if (! was_closed) { sub.emit('close', {}) }
                }
                //TODO implement status request handler
                break;
            case 'uns':
                delete multiplex.channels[name];
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

    WebSocketMultiplex.prototype.eachChannel = function(cb) {
        for (var channel in this.channels) {
            if (this.channels.hasOwnProperty(channel)) {
                cb(this.channels[channel]);
            }
        }
    };

    WebSocketMultiplex.prototype.channel = function(raw_name) {
        var name = escape(raw_name);
        if (! this.channels[name] ) {
            this.channels[name] = new Channel(this, name);
        }
        return this.channels[name];
    };


    var Channel = function(multiplex, name) {
        DumbEventTarget.call(this);
        var that = this;
        this.multiplex = multiplex;
        var ws = multiplex.ws;
        this.name = name;
        this.readyState = WebSocket.CONNECTING;
        if(ws.readyState > WebSocket.CONNECTING) {
            setTimeout(function(){ that.subscribe() }, 0);
        } else {
            ws.addEventListener('open', function(){ that.subscribe() });
        }
    };
    Channel.prototype = new DumbEventTarget();

    Channel.prototype.subscribe = function () {
        this.multiplex.ws.send('sub,' + this.name);
    };
    Channel.prototype.send = function(data) {
        this.multiplex.ws.send('msg,' + this.name + ',' + data);
    };
    Channel.prototype.close = function() {
        this.readyState = WebSocket.CLOSING;
        this.multiplex.ws.send('uns,' + this.name);
    };

    return WebSocketMultiplex;
})();


