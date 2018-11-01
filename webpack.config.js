// To build run:
// $ npm install --save-dev webpack webpack-cli babel-loader @babel/core @babel/preset-env
// $ ./node_modules/.bin/webpack

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
  module: {
    rules: [
      {
        test: /\.m?js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env'],
          }
        }
      }
    ]
  }
};
