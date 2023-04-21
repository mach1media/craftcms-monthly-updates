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
	//
	// mega menu toggle hovers
	//
	$('.js-nav-item').mouseenter(function(){
		// reset all other open megamenus
		$('.js-nav-item').attr('aria-expanded','false');
		$('.c-header__mega-menu.show').removeClass('show');
		
		// open the corresponding megamenu
		var megaMenuId = $(this).attr('data-bs-target');
		if (megaMenuId) {
			$(megaMenuId).addClass('show');
			$(this).attr('aria-expanded','true');
		}
	});
	$(document).click(function(event) { 
		var $target = $(event.target);
		if(!$target.closest('.c-header__mega-menu.show').length && 
		$('.c-header__mega-menu.show').is(":visible")) {
			$('.c-header__mega-menu.show').removeClass('show');
			$('.js-nav-item').attr('aria-expanded','false');
		}
	});
	
	
	// responsive video embeds
	$(".js-fitvids").fitVids();
	
	// scroll to anchor when landing on page with hash in url
	if (window.location.hash) {
		$('a[href^="'+window.location.hash+'"]').first().trigger('click');
	}
});
