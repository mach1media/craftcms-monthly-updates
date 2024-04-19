//
// APP.JS
//
var $ = require('jquery');

// make jQuery and $ available globally, i.e. outside app.js in Craft twig templates
global.$ = global.jQuery = require('jquery');

import AOS from 'aos';     // Import AOS library
import 'aos/dist/aos.css'; // Import AOS CSS

// Import our custom CSS
import '../css/app.scss';

// Import all of Bootstrap's JS
import * as bootstrap from 'bootstrap';
window.bootstrap = require('bootstrap');

// or, specify which plugins you need:
// import { Tooltip, Toast, Popover } from 'bootstrap';

// Import Plugins
import '../vendor/fitvids/fitvids.js';
import '../vendor/hoverIntent/jquery.hoverIntent.js';

// Simulate viewport resize
function simulateViewportResize() {
	// Create a new resize event
	var event = new Event('resize');
	
	// Dispatch the resize event on the window object
	window.dispatchEvent(event);
}

// check if all images and Vimeo videos are loaded
function checkAllLoaded(callback) {
	var images = document.querySelectorAll('img');
	var iframes = document.querySelectorAll('iframe');
	var totalElements = images.length + iframes.length;
	var loadedElements = 0;

	function handleLoad() {
			loadedElements++;
			if (loadedElements >= totalElements) {
					// All images and videos are loaded, trigger the callback
					callback();
			}
	}

	// Listen for load event on images
	images.forEach(function(img) {
			if (img.complete) {
					handleLoad();
			} else {
					img.addEventListener('load', handleLoad);
			}
	});

	// Listen for load event on iframes (Vimeo videos)
	iframes.forEach(function(iframe) {
			iframe.addEventListener('load', handleLoad);
	});
}

// Call the function to check if all images and Vimeo videos are loaded
checkAllLoaded(allLoadedCallback);

// callback function to be executed when all images and Vimeo videos are loaded
function allLoadedCallback() {
	// Call the function to simulate viewport resize
	// AOS seems to need this to initialize properly
	simulateViewportResize();

	// Remove the .d-none class from all elements with data-aos attributes using jQuery
	$('[data-aos]').removeClass('d-none');
	
	// Initialize AOS globally
	AOS.init();
}

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
