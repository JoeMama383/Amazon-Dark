(function(){try{
var d=document,s=d.getElementById('ad7611-your-saves');
if(!s){s=d.createElement('style');s.id='ad7611-your-saves';(d.head||d.documentElement).appendChild(s);}
/* r8 VIEWPORT: actual post-update Lists and Registries + Your Saves DOM.
   Only activate when BOTH owners exist; no scan or runtime mutation. */
s.textContent=`
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(.lists-carousel-container,.lists-list-carousel-container,.lists-list-carousel-header-button-row,.lists-list-carousel-image-container,.lists-alexa-list-carousel-image-container,.your-stuff-items-container,#items-menu-header-button-row,.lists-saves-item-info,.awl-item-wrapper,.a-carousel-container){
 background-color:#000!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-carousel-container,
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(.lists-list-carousel-card>.a-box,.lists-carousel-element .a-box){
 background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(.lists-list-carousel-card .a-box-inner,.lists-list-carousel-card-text,.lists-list-carousel-image-container,.lists-alexa-list-carousel-image-container){
 background:transparent!important;background-color:transparent!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(.your-saves-h4,.lists-list-carousel-card-text,.lists-list-carousel-card-text p,#items-menu-header-button-row h4,.lists-saves-item-title,.lists-saves-item-title :is(a,span,div),.lists-saves-item-price-delivery :is(.a-price,.a-price-whole,.a-price-symbol,.a-price-fraction,.a-offscreen,.a-color-base,.a-text-bold),.lists-saves-item-price-delivery .udm-primary-delivery-message,.lists-saves-item-price-delivery .udm-supplemental-primary-delivery-message){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .awl-item-wrapper :is(.a-color-secondary,.a-color-tertiary,.puis-light-weight-text,[id^=review_count_]){
 color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;
}
/* Neutral dark filter pills. Amazon's selected blue OUTER stroke remains blue. */
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #ys-filters-scroller :is(.a-button.a-button-toggle,.a-button.a-button-selected),
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #keyword-filter-tooltip-anchor .a-button{
 background:#303335!important;background-color:#303335!important;border-color:#747a7c!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #ys-filters-scroller .a-button.a-button-selected{
 border-color:#2162a1!important;outline-color:#2162a1!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #ys-filters-scroller :is(.a-button.a-button-toggle,.a-button.a-button-selected)>.a-button-inner,
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #keyword-filter-tooltip-anchor .a-button>.a-button-inner{
 background:transparent!important;background-color:transparent!important;border-color:transparent!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #ys-filters-scroller :is(.a-button-text,.ys-filter-pill-button-text,.a-text-bold),
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) #keyword-filter-tooltip-anchor :is(.a-button-text,.a-text-bold){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Restore the original icon, recoloring only the dark neutral filter chevron. */
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) img#ys-filters-pill-button-icon{
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
/* Plus/create is an icon-only link. Its glyph may be currentColor or an SVG. */
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-list-carousel-create-button{
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-list-carousel-create-button :is(i,svg){
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;color:#fff!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(button[aria-label="Close"],button[aria-label="Dismiss"],a[aria-label="Close"],[role=button][aria-label="Close"]){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(button[aria-label="Close"],button[aria-label="Dismiss"],a[aria-label="Close"],[role=button][aria-label="Close"]) :is(svg,i,img){
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
/* Existing product actions only: do not rewrite their dimensions or rounding. */
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-saves-item-actions-wrapper :is(.a-button.a-button-primary,.a-button.a-button-normal,.a-button.a-button-base),
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-saves-item-actions-wrapper :is(.a-button,button,[role=button]){
 background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-saves-item-actions-wrapper .a-button>.a-button-inner{
 background:transparent!important;background-color:transparent!important;border-color:transparent!important;box-shadow:none!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-saves-item-actions-wrapper .a-button :is(.a-button-text,.a-button-inner>span){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) .lists-saves-item-actions-wrapper :is(i.a-icon,a[aria-label*="More"] svg,button[aria-label*="More"] svg){
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
/* Recolor real authored dividers; never draw additional lines. */
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(.lists-carousel-container,#awl-list-items,.your-stuff-items-container) :is(hr,.a-divider-inner,.a-divider-normal,.a-box,.a-box-inner){
 border-color:#494d4d!important;
}
/* Product/link/sale/stars/Prime/selected blue remain authored. */
`;
if(__TAME__){s.textContent+=`
body:has(#lists-list-carousel-header-button-row):has(#awl-list-items) :is(img.lists-list-carousel-image,.lists-saves-item-image img,.lists-saves-item-image-link img){
 filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;mix-blend-mode:normal!important;opacity:1!important;
}
`;}
}catch(_){}})();
