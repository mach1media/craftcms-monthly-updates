//
// APP.JS
//

// jQuery (ES module import, assign to window before any plugins load)
import jQuery from 'jquery';
window.$ = window.jQuery = jQuery;

import AOS from 'aos';
import 'aos/dist/aos.css';

// Import our custom CSS
import '../css/app.scss';

// Import Bootstrap JS and assign to window
import * as bootstrap from 'bootstrap';
window.bootstrap = bootstrap;

// Import jQuery Plugins (must use dynamic import after jQuery is on window)
await Promise.all([
	import('../vendor/fitvids/fitvids.js'),
	import('../vendor/hoverIntent/jquery.hoverIntent.js')
]);

// Simulate viewport resize
function simulateViewportResize() {
	var event = new Event('resize');
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
			callback();
		}
	}

	images.forEach(function(img) {
		if (img.complete) {
			handleLoad();
		} else {
			img.addEventListener('load', handleLoad);
		}
	});

	iframes.forEach(function(iframe) {
		iframe.addEventListener('load', handleLoad);
	});
}

// Call the function to check if all images and Vimeo videos are loaded
checkAllLoaded(allLoadedCallback);

// callback function to be executed when all images and Vimeo videos are loaded
function allLoadedCallback() {
	simulateViewportResize();
	$('[data-aos]').removeClass('d-none');
	AOS.init();
}

$(function() {
	//
	// mega menu toggle hovers
	//
	$('.js-nav-item').hoverIntent(function(){
		$(this).trigger('click');
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
