(function(){try{
var d=document,s=d.getElementById('ad7601-pdp-probe-owners');
if(!s){s=d.createElement('style');s.id='ad7601-pdp-probe-owners';(d.head||d.documentElement||d).appendChild(s);}
var css=`
/* v7.601: actual v7.600 FULL/VIEWPORT evidence, not synthetic ownership guesses. */
/* Shop by brand: the white floor was a background-image GRADIENT on the real card, not background-color. */
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"],
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"]:is(:hover,:focus,:active){background:#000!important;background-image:none!important;border-color:#494d4d!important;box-shadow:none!important;}
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"] :is([class*="_c2Itb_brandName_"],[class*="_c2Itb_proofPointText_"],[class*="_c2Itb_productMeta_"],[class*="_c2Itb_priceRow_"],[class*="_c2Itb_deliveryBlock_"],[class*="_c2Itb_truncate_"],.a-price,.a-price-symbol,.a-price-whole,.a-price-fraction,.udm-primary-delivery-message){color:#fff!important;-webkit-text-fill-color:#fff!important;}
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"] :is([class*="_c2Itb_brandName_"],[class*="_c2Itb_proofPointText_"]){color:#c8cccd!important;-webkit-text-fill-color:#c8cccd!important;}
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"] [class*="_c2Itb_shopLink_"]{color:#368bd1!important;-webkit-text-fill-color:#368bd1!important;}
#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"] :is([class*="_c2Itb_separator_"],[class*="_c2Itb_separator_"]::before){background:#494d4d!important;border-color:#494d4d!important;}
/* Product art, brand logos, stars, Prime and other dynamic colors retain their inherited treatment. */

/* Actual FBT carousel owner is sims-multiProductBundle, not the old multi-bundle-container-t3. */
#dp [id^="sims-multiProductBundle_feature_div_"] img.p13n-product-image,
#dp [class*="_p13n-mobile-sims-multi-bundle_multi-bundle-mobile_image-display__"] img.a-dynamic-image{filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;mix-blend-mode:normal!important;opacity:1!important;}
/* Complementary mosaic cards: exact probe owner, not a guessed generic product grid. */
#dp #sims-complements_feature_div_0 [class*="_c3Atb_image-display-"] img.p13n-product-image,
#dp #sims-complements_feature_div_0 [class*="_c3Atb_image-display-"] img.a-dynamic-image{filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;mix-blend-mode:normal!important;opacity:1!important;}
#dp #sims-complements_feature_div_0 .atc-spot-button-container button.add-to-cart-button,
#dp .mosaic-atc-container .atc-spot-button-container button.add-to-cart-button{background:#303335!important;background-image:none!important;border-color:#202324!important;border-style:solid!important;border-width:2px!important;box-shadow:none!important;color:#fff!important;-webkit-text-fill-color:#fff!important;}
#dp #sims-complements_feature_div_0 .atc-spot-button-container button.add-to-cart-button .a-icon-small-add,
#dp .mosaic-atc-container .atc-spot-button-container button.add-to-cart-button .a-icon-small-add{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
/* Actual bundles divider was gray in background but had a bright white TOP BORDER. Recolor, never redraw. */
#dp #bundles-feature hr.bundles-bottom-divider{border-top-color:#494d4d!important;border-right-color:#494d4d!important;border-bottom-color:#494d4d!important;border-left-color:#494d4d!important;background-color:#494d4d!important;}

/* Actual Shop Aisles tile images are bare IMG descendants of this image owner. */
#ax-mbs #ee-aisles-on-uss-widget-container [class*="_everyday-essentials-aisles_AisleImage_eeAisleImageContainer__"] > img{filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;mix-blend-mode:normal!important;opacity:1!important;}
/* Existing progress geometry: restore the rounded TRACK and FILL, keep the original dimensions. */
#ax-mbs .tpb-progress-bar-meter{background:transparent!important;border-radius:999px!important;overflow:hidden!important;}
#ax-mbs .tpb-progress-bar-meter .a-progress-bar{border-radius:999px!important;overflow:hidden!important;}
#ax-mbs .tpb-progress-bar-meter .a-meter{background:#44494b!important;border-radius:999px!important;overflow:hidden!important;}
#ax-mbs .tpb-progress-bar-meter .a-meter-bar{border-radius:999px 0 0 999px!important;}
#ax-mbs .tpb-progress-bar-meter .a-meter-bar[style*="100%"]{border-radius:999px!important;}
/* The purple close rectangle is a focused OUTLINE on the exact stock button. */
#ax-mbs button#ax-mbs-close-white,
#ax-mbs button#ax-mbs-close-white:is(:focus,:focus-visible,:active),
#ax-mbs button#ax-mbs-close-white.a-focus-hidden{outline:none!important;outline-width:0!important;outline-color:transparent!important;box-shadow:none!important;-webkit-tap-highlight-color:transparent!important;}
#ax-mbs button#ax-mbs-close-white i.a-icon-close-white{filter:none!important;-webkit-filter:none!important;}
`;
if(s.textContent!==css)s.textContent=css;
}catch(_){}})();
