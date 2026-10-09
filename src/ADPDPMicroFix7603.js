(function(){try{
var d=document;
/* Restore authored success-alert border on the one recorded PDP card. The
   inherited floor sheets hard-force #494d4d on *all* #dp .a-box. Exclude
   this semantic card from those two declarations, preserving Amazon CSS's
   current border colors, widths and radii instead of guessing a new color. */
var ids=['ad7-search-pane-theme','ad7-menu-theme'];
for(var i=0;i<ids.length;i++){
 var floor=d.getElementById(ids[i]);
 if(!floor)continue;
 var raw=floor.textContent||'';
 var fixed=raw.replace(/#dp\s+\.a-box(?=\s*,)/g,'#dp .a-box:not(.ripers-lrr-badge)');
 if(raw!==fixed)floor.textContent=fixed;
}
var s=d.getElementById('ad7603-pdp-accent-preservation');
if(!s){s=d.createElement('style');s.id='ad7603-pdp-accent-preservation';(d.head||d.documentElement||d).appendChild(s);}
var css=`
/* v7.603: two captured PDP viewport scenes. Recolor the exact neutral text,
   not the authored sustainability leaf image or the parent badge. */
#dp #climatePledgeFriendlyATF_feature_div #climatePledgeFriendlyBadge .climatePledgeFriendlyProgramName.badgeTreatmentT1,
#dp #climatePledgeFriendlyATF_feature_div #climatePledgeFriendlyBadge .climatePledgeFriendlyProgramName.badgeTreatmentT1 *{
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Subscribe nudge's 26x26 IMG is a composite orange-ring+dark-cart artwork,
   NOT an inline SVG. Only the dark ink becomes white; preserve orange ring.
   No layout, dimensions, asset URL, or content is changed. */
#dp #subscribe-and-save-nudge-container img.sns-nudge-logo-image{
 filter:url(#ad7603-sns-dark-ink-to-white)!important;
 -webkit-filter:url(#ad7603-sns-dark-ink-to-white)!important;
}
`;
if(s.textContent!==css)s.textContent=css;
/* One permanent SVG paint filter, never a live DOM scan or observer.
   R-B discriminates orange from neutral/dark ink, and SourceAlpha clips to
   original image shape, so the transparent 26x26 art stays transparent. */
if(typeof d.createElementNS==='function'&&!d.getElementById('ad7603-sns-filter-defs')){
 var ns='http://www.w3.org/2000/svg';
 var svg=d.createElementNS(ns,'svg');svg.setAttribute('id','ad7603-sns-filter-defs');
 svg.setAttribute('aria-hidden','true');svg.setAttribute('width','0');svg.setAttribute('height','0');
 svg.style.cssText='position:absolute;width:0;height:0;overflow:hidden;pointer-events:none';
 var defs=d.createElementNS(ns,'defs'),filter=d.createElementNS(ns,'filter');
 filter.setAttribute('id','ad7603-sns-dark-ink-to-white');
 filter.setAttribute('color-interpolation-filters','sRGB');
 var matrix=d.createElementNS(ns,'feColorMatrix');
 matrix.setAttribute('in','SourceGraphic');matrix.setAttribute('type','matrix');
 matrix.setAttribute('values','0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  -3.20 0 3.20 0 0.97');
 matrix.setAttribute('result','white-ink');
 var clip=d.createElementNS(ns,'feComposite');clip.setAttribute('in','white-ink');
 clip.setAttribute('in2','SourceAlpha');clip.setAttribute('operator','in');clip.setAttribute('result','masked-ink');
 var merge=d.createElementNS(ns,'feMerge'),original=d.createElementNS(ns,'feMergeNode'),white=d.createElementNS(ns,'feMergeNode');
 original.setAttribute('in','SourceGraphic');white.setAttribute('in','masked-ink');
 merge.appendChild(original);merge.appendChild(white);
 filter.appendChild(matrix);filter.appendChild(clip);filter.appendChild(merge);
 defs.appendChild(filter);svg.appendChild(defs);(d.documentElement||d.body).appendChild(svg);
}
}catch(_){}})();
