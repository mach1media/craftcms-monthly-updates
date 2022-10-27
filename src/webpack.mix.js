// webpack.mix.js

let mix = require('laravel-mix');

mix.autoload({
    jquery: ['$', 'window.jQuery', 'jQuery']
  })
  .js([
      'js/app.js'
    ], 
    'js/app.js')
  .sass(`css/app.scss`, 'css')
  .setPublicPath('../cms/web/dist');

// Copy Vendor libraries
mix.copy(`vendor`,'../cms/web/dist/vendor');
