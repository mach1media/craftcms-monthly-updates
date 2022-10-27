//
// APP.JS
//
var $ = require('jquery');

// Import our custom CSS
import '../css/app.scss';

// Import all of Bootstrap's JS
import * as bootstrap from 'bootstrap';

// or, specify which plugins you need:
// import { Tooltip, Toast, Popover } from 'bootstrap';

// Import Plugins
import '../vendor/fitvids/fitvids.js';


$(function() {
	
	// responsive video embeds
	$(".js-fitvids").fitVids();
	
	// scroll to anchor when landing on page with hash in url
	if (window.location.hash) {
		$('a[href^="'+window.location.hash+'"]').first().trigger('click');
	}
});
