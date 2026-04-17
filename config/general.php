<?php
/**
 * General Configuration
 *
 * All of your system's general configuration settings go in here. You can see a
 * list of the available settings in vendor/craftcms/cms/src/config/GeneralConfig.php.
 *
 * @see \craft\config\GeneralConfig
 */

use craft\config\GeneralConfig;
use craft\helpers\App;

return GeneralConfig::create()
    // Set the default week start day for date pickers (0 = Sunday, 1 = Monday, etc.)
    ->defaultWeekStartDay(0)

    // Prevent generated URLs from including "index.php"
    ->omitScriptNameInUrls()

	// Disable 'X-Powered-By: Craft CMS' header
	->sendPoweredByHeader(false)

	// Preload Single entries as Twig variables
	->preloadSingles()

	// Prevent user enumeration attacks
	->preventUserEnumeration()

	// Security settings
	->enableTwigSandbox()
	->sendPoweredByHeader(false)
	->maxInvalidLogins(5)
	->invalidLoginWindowDuration(600)
	->cooldownDuration(300)

	// don't attempt to transform SVGs or GIFs
	->transformSvgs(false)
	->transformGifs(false)

	// Disable GraphQL
	->enableGql(false)

	// Add trailing slashes to generated URLs
	->addTrailingSlashesToUrls()

	// Allow tokens to last 7 days
	->defaultTokenDuration(604800)

    // Extra file extensions allowed to be uploaded
    ->extraAllowedFileExtensions(['ics'])
    
	// Aliases for CP settings
	->aliases([
		'@webroot' => dirname(__DIR__) . '/web',
		'@web' => App::env('PRIMARY_SITE_URL'),
	])
;
