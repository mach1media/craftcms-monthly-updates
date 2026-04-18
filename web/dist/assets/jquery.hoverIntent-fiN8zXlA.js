/*!
 * hoverIntent v1.10.2 // 2019.10.05 // jQuery v1.7.0+
 * http://briancherne.github.io/hoverIntent/
 *
 * You may use hoverIntent under the terms of the MIT license. Basically that
 * means you are free to use hoverIntent as long as this header is left intact.
 * Copyright 2007-2019 Brian Cherne
 */(function(r){var X={interval:100,sensitivity:6,timeout:0},Y=0,a,f,c=function(i){a=i.pageX,f=i.pageY},s=function(i,v,e,n){if(Math.sqrt((e.pX-a)*(e.pX-a)+(e.pY-f)*(e.pY-f))<n.sensitivity)return v.off(e.event,c),delete e.timeoutId,e.isActive=!0,delete e.pX,delete e.pY,n.over.apply(v[0],[i]);e.pX=a,e.pY=f,e.timeoutId=setTimeout(function(){s(i,v,e,n)},n.interval)},h=function(i,v,e,n){return delete v.data("hoverIntent")[e.id],n.apply(v[0],[i])};r.fn.hoverIntent=function(i,v,e){var n=Y++,t=r.extend({},X);r.isPlainObject(i)?(t=r.extend(t,i),r.isFunction(t.out)||(t.out=t.over)):r.isFunction(v)?t=r.extend(t,{over:i,out:v,selector:e}):t=r.extend(t,{over:i,out:i,selector:v});var I=function(l){var m=r.extend({},l),u=r(this),p=u.data("hoverIntent");p||u.data("hoverIntent",p={});var o=p[n];o||(p[n]=o={id:n}),o.timeoutId&&(o.timeoutId=clearTimeout(o.timeoutId));var d=o.event="mousemove.hoverIntent.hoverIntent"+n;if(l.type==="mouseenter"){if(o.isActive)return;o.pX=m.pageX,o.pY=m.pageY,u.off(d,c).on(d,c),o.timeoutId=setTimeout(function(){s(m,u,o,t)},t.interval)}else{if(!o.isActive)return;u.off(d,c),o.timeoutId=setTimeout(function(){h(m,u,o,t.out)},t.timeout)}};return this.on({"mouseenter.hoverIntent":I,"mouseleave.hoverIntent":I},t.selector)}})(jQuery);
