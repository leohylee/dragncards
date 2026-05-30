const webpack = require('webpack');

module.exports = {
  // Dev server: never let the browser cache the bundle. The CRA dev server
  // otherwise sends only an ETag with no Cache-Control, and Safari (desktop +
  // iOS) heuristic-caches the JS, so devices keep running a stale bundle.js
  // (e.g. an old WebSocket URL or a missing settings control) even after edits.
  devServer: (devServerConfig) => {
    devServerConfig.headers = {
      ...(devServerConfig.headers || {}),
      "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
      "Pragma": "no-cache",
      "Expires": "0",
    };
    return devServerConfig;
  },
  webpack: {
    configure: (webpackConfig) => {
      // Add Node.js polyfills for webpack 5
      webpackConfig.resolve.fallback = {
        ...webpackConfig.resolve.fallback,
        "http": require.resolve("stream-http"),
        "constants": require.resolve("constants-browserify"),
        "buffer": require.resolve("buffer/"),
        "timers": require.resolve("timers-browserify"),
        "stream": require.resolve("stream-browserify"),
        "util": require.resolve("util/"),
        "assert": require.resolve("assert/"),
        "url": require.resolve("url/"),
        "fs": false,
        "net": false,
        "tls": false
      };

      // Provide Buffer globally
      webpackConfig.plugins = [
        ...webpackConfig.plugins,
        new webpack.ProvidePlugin({
          Buffer: ['buffer', 'Buffer'],
          process: 'process/browser'
        })
      ];

      return webpackConfig;
    }
  }
};