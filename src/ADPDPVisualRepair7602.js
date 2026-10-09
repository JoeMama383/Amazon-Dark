(function(){try{
var d=document,s=d.getElementById('ad7602-pdp-visual-repair');
if(!s){s=d.createElement('style');s.id='ad7602-pdp-visual-repair';(d.head||d.documentElement||d).appendChild(s);}
var css=`
/* v7.602: v7.602 completed FULL capture. Preserve stock sizes and radii. */
/* Buy-all price/label descendants were painted black by broad bundle floor rules. */
#dp#dp [class*="_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_v3-total-box-"] .a-button-text,
#dp#dp [class*="_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_v3-total-box-"] .a-button-text *{background:transparent!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}
/* The captured square is the celwidget inside the circular-button form. */
#dp#dp .mosaic-atc-container [id^="sp-mobile-dp-mosaic-atc-button-"],
#dp#dp .mosaic-atc-container :is(.add-to-cart-section,form.add-to-cart-data,.atc-spot-button-container){background:transparent!important;box-shadow:none!important;}
/* A loaded/tamed IMG cannot override MULTIPLY on its parent. Fix the actual parent. */
#dp#dp [class*="_cDEzb_imageDisplay_"],
#dp#dp [class*="_cDEzb_imageContainer_"]{mix-blend-mode:normal!important;background-color:transparent!important;}
#dp#dp [class*="_cDEzb_imageDisplay_"] img.p13n-product-image{filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;mix-blend-mode:normal!important;opacity:1!important;}
/* Captured Similar products CTA is a SPAN.a-button, not a button element. */
#dp#dp [class*="_cDEzb_faceoutContainer_"] .p13n-sc-atc-container,
#dp#dp [class*="_cDEzb_faceoutContainer_"] [id="AddToCartLibrary-AddToCartButton-Personalization"]{background:transparent!important;box-shadow:none!important;}
#dp#dp [class*="_cDEzb_faceoutContainer_"] .a-button.add-to-cart-button,
#dp#dp [class*="_cDEzb_faceoutContainer_"] .a-button.add-to-cart-button:is(:active,:focus,:hover){background:#000!important;background-image:none!important;border:1px solid #747a7c!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}
#dp#dp [class*="_cDEzb_faceoutContainer_"] .a-button.add-to-cart-button :is(.a-button-inner,.a-button-text,.a-button-input,span){background:transparent!important;background-image:none!important;border:0!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}
/* Review header from the earlier FULL review capture: a bare h4 inside a link.
   The broad review-heading rule excludes link descendants, and guessed title classes miss it. */
#mobile-product-reviews#mobile-product-reviews > .a-subheader > a,
#mobile-product-reviews#mobile-product-reviews > .a-subheader > a > h4,
#mobile-product-reviews#mobile-product-reviews > .a-subheader > a > h4 *{background:transparent!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}
`;
if(s.textContent!==css)s.textContent=css;
}catch(_){}})();
