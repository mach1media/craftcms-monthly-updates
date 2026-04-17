<?php

use craft\helpers\App;

return [
    'useDevServer' => App::env('ENVIRONMENT') === 'dev' || App::env('CRAFT_ENVIRONMENT') === 'dev',
    'manifestPath' => '@webroot/dist/.vite/manifest.json',
    'devServerInternal' => 'http://localhost:3000',
    'devServerPublic' => rtrim(preg_replace('/:\d+$/', '', App::env('PRIMARY_SITE_URL')), '/') . ':3000',
    'serverPublic' => rtrim(App::env('PRIMARY_SITE_URL'), '/') . '/dist/',
];
