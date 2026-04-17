<?php
/**
 * Shared bootstrap file
 */

// Define path constants
define('CRAFT_BASE_PATH', __DIR__);
define('CRAFT_VENDOR_PATH', CRAFT_BASE_PATH . '/vendor');

// Suppress PHP 8.4 deprecation warnings from voku/portable-utf8
// https://github.com/craftcms/cms/issues/16606 - will be fixed in Craft 6
error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

// Load Composer's autoloader
require_once CRAFT_VENDOR_PATH . '/autoload.php';

// Load dotenv?
if (class_exists(Dotenv\Dotenv::class)) {
    // By default, this will allow .env file values to override environment variables
    // with matching names. Use `createUnsafeImmutable` to disable this.
    Dotenv\Dotenv::createUnsafeMutable(CRAFT_BASE_PATH)->safeLoad();
}
