(function(){try{
var d=document,s=d.getElementById('ad7608-review-filter-menu');
if(!s){s=d.createElement('style');s.id='ad7608-review-filter-menu';(d.head||d.documentElement).appendChild(s);}
/* v7.605 FULL r4 identified the reviews filter secondary-view popover.
   Floors were already OLED. Remaining issue: neutral button surfaces stayed
   stock white/yellow. Recolor only the existing Clear All, Apply and exact
   filter option owners to neutral dark-mode button treatments, while leaving
   the existing checkbox/radio sprites and geometry intact. */
s.textContent=`
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view),
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) .a-popover-wrapper,
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) .a-popover-inner,
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #a-popover-content-1.a-container.a-secondary-view-inner,
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-view{
 background:#000!important;background-color:#000!important;color-scheme:dark!important;box-shadow:none!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-clear{
 background:#303335!important;background-color:#303335!important;border:1px solid #747a7c!important;border-color:#747a7c!important;box-shadow:none!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-clear>.a-button-inner,
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-apply>.a-button-inner{
 background:transparent!important;background-color:transparent!important;border:0!important;box-shadow:none!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) :is(#reviews-filter-options-clear,#reviews-filter-options-apply) :is(.a-button-text,#reviews-filter-options-clear-announce,#reviews-filter-options-apply-announce){
 color:#fff!important;-webkit-text-fill-color:#fff!important;opacity:1!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-apply,
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-view :is(#reviews-media-checkbox,#reviews-format-checkbox,#reviews-avp-checkbox,#cm_cr_marp_incentivized_filter_settings,#star-filter-select,.a-touch-link.a-touch-multi-select.a-box-inner,.a-touch-link.a-box.a-touch-link-noborder.a-touch-select,.a-box.a-vertical,.a-box.a-box-group,.a-box-inner.a-padding-none,.a-unordered-list.a-nostyle.a-box-list,.a-nostyle.a-box-list){
 background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-view :is(.a-row,.a-list-item,hr,.a-divider-inner,[class*=divider],[class*=separator],#reviews-media-checkbox,#reviews-format-checkbox,#reviews-avp-checkbox,#cm_cr_marp_incentivized_filter_settings,#star-filter-select,.a-touch-link.a-touch-multi-select.a-box-inner,.a-touch-link.a-box.a-touch-link-noborder.a-touch-select,.a-box.a-vertical,.a-box.a-box-group,.a-box-inner.a-padding-none){
 border-color:#494d4d!important;box-shadow:none!important;
}
#a-popover-1.a-popover.a-popover-secondary.a-declarative:has(#reviews-filter-options-view) #reviews-filter-options-view :is(.a-touch-multi-select-item-label,.a-text-ellipsis,.a-text-bold,.a-form-label,.a-size-base,.a-size-small,h1,h2,h3,h4,h5,h6,p,label,strong,b,span,div):not(.a-icon):not(.a-offscreen){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
`;
}catch(_){}})();
