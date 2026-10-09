(function(){try{
var d=document,s=d.getElementById('ad7604-pdp-viewport-finish');
if(!s){s=d.createElement('style');s.id='ad7604-pdp-viewport-finish';(d.head||d.documentElement||d).appendChild(s);}
/* Four independent v7.602 viewport captures: r1 similar-products grid,
   r2 played sponsored video, r3/r4 House of Cards top highlights.
   Do not synthesize dividers or circles. Preserve dynamic Prime/stars/badges.
   The overlay lives inside the video click-through (not around the card),
   so the separate sponsored and player controls remain readable. */
var css=`
/* Top highlights: recolor ONLY the existing one-pixel authored divider. */
#dp#dp #topHighlights > hr.a-divider-normal.hoc-divider{
 border-top-color:#494d4d!important;
 background-color:#494d4d!important;
}
/* The See more icon is an Amazon sprite with dark CSS border ink; change paint,
   not the established 11x11 chevron dimensions, geometry, or click target. */
#dp#dp #hoc-topHighlights-expander .hoc-see-more-expander i.a-icon-extender-expand{
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
/* Video tag is hardware-composited in iOS WKWebView when play starts. A CSS
   filter applied only to the poster is not sufficient: use a click-through
   overlay with non-interactive dark alpha over moving pixels, no DOM work. */
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_videoWrapper__"] a[class*="_single-video-ads-card_style_clickThrough__"]{
 position:relative!important;
}
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_videoWrapper__"] a[class*="_single-video-ads-card_style_clickThrough__"]::after{
 content:"";position:absolute;inset:0;z-index:1;pointer-events:none;
 background:rgba(0,0,0,__OVERLAY__)!important;
}
/* Keep overlay beneath sibling chrome without repositioning the stock controls. */
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_widgetLabelContainer__"],
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_buttonTray__"]{
 z-index:3!important;
}
/* Sponsored chip uses the same translucent black as the play/mute circles.
   Supersedes inherited v7.574 and v7.7482 .9-alpha overrides. */
#dp#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_sponsoredBadge__"]{
 background-color:rgba(0,0,0,.55)!important;
}
/* Video-ad price ink was stock #0f1111 on OLED. Scope to price row only:
   the orange tick, blue Prime, star fills, badges are intentionally exempt. */
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_priceRow__"]{
 color:#fff!important;
}
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_priceRow__"] :is(.a-price,.a-price-symbol,.a-price-whole,.a-price-fraction,.a-color-price,[class*="_single-video-ads-card_style_price__"],[class*="_single-video-ads-card_style_priceText__"],[class*="_single-video-ads-card_style_priceValue__"],[class*="priceAmount"]),
#dp#dp #ape_detail_btf_mshop_placement [class*="_single-video-ads-card_style_priceRow__"] .a-price *{
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Similar-products cards: actual probed .a-price.aok-align-center rendered
   rgb(15,17,17), including its nested number glyphs. Only prices changed. */
#dp#dp #sims-substitutes_feature_div_0 .p13n-mobile-grid .a-price,
#dp#dp #sims-substitutes_feature_div_0 .p13n-mobile-grid .a-price :is(.a-price-symbol,.a-price-whole,.a-price-decimal,.a-price-fraction,.a-offscreen,span){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Two observed 32x32 circular CTAs were white, unlike dark product art.
   Alter fill/border colors only, never size, radii, box shadows or offsets. */
#dp#dp #sims-substitutes_feature_div_0 a[class*="_cDEzb_mltIngressIcon_"]{
 background-color:#383c3e!important;background-image:none!important;border-color:#747a7c!important;
}
/* Their plus/cart glyph is drawn separately; keep it legible on gray without
   recoloring the product image, rating stars or other original dynamic icons. */
#dp#dp #sims-substitutes_feature_div_0 a[class*="_cDEzb_mltIngressIcon_"] :is(svg,i,img){
 filter:invert(1)!important;-webkit-filter:invert(1)!important;
}
#dp#dp #sims-substitutes_feature_div_0 a[class*="_cDEzb_mltIngressIcon_"]::before{
 filter:invert(1)!important;-webkit-filter:invert(1)!important;
}
`;
if(s.textContent!==css)s.textContent=css;
}catch(_){}})();
