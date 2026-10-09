(function(){try{
var d=document,s=d.getElementById('ad7607-pdp-last-mile');
if(!s){s=d.createElement('style');s.id='ad7607-pdp-last-mile';(d.head||d.documentElement).appendChild(s);}
/* v7.605 VIEWPORT r2 captured #value-pick-size-view with black computed ink:
   rgb(15,17,17). This is the secondary size/pack-count line under the
   blue linked recommendation title; use a readable secondary gray on OLED.
   Do not recolor the title, Amazon's Choice badge or dynamic attributes.

   v7.605 VIEWPORT r1 identified the remaining bright divider below
   "Summarized from product information": it is the BOTTOM border of
   .dpx-insights-multi-row-carousel-container, 1px rgb(213,217,217).
   It is NOT the top hr.hoc-divider corrected in v7.604.
   Recolor the exact authored border only; don't draw a second divider. */
s.textContent=`
#dp#dp #value-pick-size-view.a-size-small.a-text-bold{
 color:#b0b3b5!important;-webkit-text-fill-color:#b0b3b5!important;
}
#dp#dp#dp #topHighlights #nile-inline-insights_feature_div .dpx-insights-multi-row-carousel-container{
 border-bottom-color:#494d4d!important;
}
`;
}catch(_){}})();
