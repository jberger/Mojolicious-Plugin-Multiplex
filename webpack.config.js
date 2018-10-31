// npm install --save-dev webpack webpack-cli

const webpack = require('webpack');
const path = require('path')

module.exports = {
  entry: './share/websocket_multiplex.esm.js',
  mode: 'production',
  //mode: 'development',
  devtool: 'source-map',
  output: {
    path: path.resolve(__dirname, 'share'),
    filename: 'websocket_multiplex.js',
    library: 'WebSocketMultiplex',
    libraryTarget: 'var',
    libraryExport: 'default',
  },
};
