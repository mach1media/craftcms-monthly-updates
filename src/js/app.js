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
import '../vendor/hoverIntent/jquery.hoverIntent.js';


$(function() {
	//
	// mega menu toggle hovers
	//
	$('.js-nav-item').hoverIntent(function(){
		$(this).trigger('click');
		// // reset all other open megamenus
		// $('.js-nav-item').attr('aria-expanded','false');
		// $('.c-header__mega-menu.show').removeClass('show');
		
		// // open the corresponding megamenu
		// var megaMenuId = $(this).attr('data-bs-target');
		// if (megaMenuId) {
		// 	$(megaMenuId).addClass('show');
		// 	$(this).attr('aria-expanded','true');
		// }
	}, function(){
		// do nothing
	});

	$('.js-megamenu').hoverIntent({
		over: function(){
			// do nothing
		},
		out: function(){
			// reset all other open megamenus
			$('.js-nav-item').attr('aria-expanded','false');
			$('.c-header__mega-menu.show').removeClass('show');
		},
		timeout: 0
	});

	$(document).click(function(event) { 
		var $target = $(event.target);
		if (!$target.closest('.c-header__mega-menu.show').length && $('.c-header__mega-menu.show').is(":visible")) {
			console.log($target);
			$('.c-header__mega-menu.show').removeClass('show');
			$('.js-nav-item').attr('aria-expanded','false');
		}
	});
	
	// search bar toggle
	$('.js-modal-search-toggle').click(function(e){
		e.preventDefault();

		if ($('#search-bar').hasClass('show')) {
			$('#search-bar').removeClass('show');
		}
		else {
			$('#search-bar').addClass('show');
		}
	});
	
	// responsive video embeds
	$(".js-fitvids").fitVids();
	
	// scroll to anchor when landing on page with hash in url
	if (window.location.hash) {
		var anchorLink;
		
		if ($('a[href^="'+window.location.hash+'"]') === undefined) {
			anchorLink = $('a[href^="'+window.location.hash+'"]');
		}
		else {
			anchorLink = $('a[href^="'+window.location.hash+'"]').first();
		}
		
		anchorLink.trigger('click');
	}
});
