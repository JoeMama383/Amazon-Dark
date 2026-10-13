/* v7.638: probe-owned Lists/Registry, Your Saves, list-details, modal sheets and
 * independently exported OMG list. Declarative CSS, zero document walking. */
(function(){try{
  var d=document, s=d.getElementById('ad7633-lists-registry');
  if(!s){s=d.createElement('style');s.id='ad7633-lists-registry';(d.head||d.documentElement).appendChild(s);}
  s.textContent=`
/* r2/r3: Lists & Registry listing. Do not style unrelated a-box or tabs. */
body:has(#awl-lol-lists-header):has(#wishlistAndFriendsLists) :is(#a-page,#awl-lol-your-lists-tab-content,#awl-lol-your-lists-tab-content>.a-box-inner,#wishlistAndFriendsLists,.awl-lol-box-group){background:#000!important;box-shadow:none!important;}
body:has(#wishlistAndFriendsLists) :is(#awl-lol-lists-header,.awl-lol-tab-heading-text:not(.a-active),#wishlistAndFriendsLists :is(.a-color-base,.a-color-secondary,.a-size-medium,.a-size-base,.a-size-small)){color:#f5f5f5!important;-webkit-text-fill-color:#f5f5f5!important;}
body:has(#wishlistAndFriendsLists) .awl-lol-tab-heading-text:not(.a-active) {color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}
body:is(*,#wishlistAndFriendsLists) #wishlistAndFriendsLists :is(a.awl-link-to-list,.awl-lol-box-group .a-box){background:#303335!important;border-color:#494d4d!important;box-shadow:none!important;}
body:is(*,#wishlistAndFriendsLists) #wishlistAndFriendsLists a.awl-link-to-list>.a-box-inner{background:transparent!important;box-shadow:none!important;}
body:is(*,#wishlistAndFriendsLists) #wishlistAndFriendsLists :is(.awl-list-name,.awl-lol-list-name,.a-text-bold,.a-color-base){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:is(*,#wishlistAndFriendsLists) #wishlistAndFriendsLists :is(.a-color-secondary,.a-color-tertiary,.awl-lol-list-description){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}
body:has(#wishlistAndFriendsLists) :is(#lol-create-list-link,.awl-lol-title-create,.awl-lol-tab-heading-text.a-active){color:#4699e5!important;-webkit-text-fill-color:#4699e5!important;}
body:has(#wishlistAndFriendsLists) .awl-modern-tab-set{border-color:#494d4d!important;}
/* r3: Create List sheet. Its author controls height, spacing and pill corners. */
body:has(#createlist-form-container) :is(.a-sheet-web,.a-sheet-content-container,#create-list-view,#create-list-form-wrapper,#createlist-form-container){background:#000!important;box-shadow:none!important;}
body:has(#createlist-form-container) :is(#createlist-form-heading,#createlist-form-container h1,#createlist-form-container h2,#createlist-form-container label,#createlist-form-container p,#createlist-form-container .a-color-base){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:has(#createlist-form-container) :is(#createlist-list-name-textinput,.a-input-text-wrapper:has(#createlist-list-name-textinput),#createlist-form-container input[type=text]){background:#303335!important;color:#fff!important;-webkit-text-fill-color:#fff!important;border-color:#747a7c!important;box-shadow:none!important;}
body:is(*,#createlist-form-container) #createlist-form-container :is(.a-button-primary,.a-button-primary>.a-button-inner,button[type=submit]){background:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;border-color:#747a7c!important;box-shadow:none!important;}
body:is(*,#createlist-form-container) #createlist-form-container .a-button-primary .a-button-text{color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:is(*,#createlist-form-container) #createlist-form-container :is(a,.a-color-link){-webkit-text-fill-color:currentColor!important;}
/* r1/r2: Your Saves Add Content bottom sheet, its options and icon glyphs. */
body:has(#lists-list-carousel-header-button-row) .a-sheet-web:has(#external-saves-add-content-content),
body:has(#lists-list-carousel-header-button-row) .a-sheet-web:has(#external-saves-add-content-content) .a-sheet-content-container,
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content{background:#000!important;box-shadow:none!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content :is(.a-color-base,.external-saves-option-text,.a-text-bold){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content :is(.a-color-secondary,.a-color-tertiary){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content .external-saves-option-row{background:transparent!important;color:#fff!important;border-color:#494d4d!important;box-shadow:none!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content :is(.external-saves-options-divider,hr){border-color:#494d4d!important;background-color:#494d4d!important;box-shadow:none!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content .external-saves-option-icon{color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:has(#lists-list-carousel-header-button-row) #external-saves-add-content-content .external-saves-option-icon img{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
/* r5 full mounted-DOM sweep: detailed Shopping List, all visible items + hidden sheets. */
body:has(.awl-list-view-page-container):has(#wl-item-view) :is(.awl-list-view-page-container,#lv-ov-list-hdr,#list-details,#mobile-list-header-action-bar,#wl-item-view,#awl-list-items,.awl-item-wrapper,[id^=itemWrapper_],[id^=item_detail_]){background:#000!important;box-shadow:none!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) :is([id^=listTitle_],.awl-list-title,[id^=item_title_],.awl-item-name,.awl-item-title,[id^=item-byline-],.a-color-base,.a-text-bold,.a-price-whole,.a-price-symbol,.a-price-fraction){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) :is(.a-color-secondary,.a-color-tertiary,.a-size-mini.a-color-secondary,.puis-light-weight-text,[id^=review_count_]){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) :is(.a-color-link,.a-color-price,.a-color-success,.a-color-error,[class*=prime],[class*=star],[class*=rating],[class*=badge],[class*=coupon]){-webkit-text-fill-color:currentColor!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) #awl-list-items :is([id^=pab-],.a-button.a-button-primary,[id^=awl-item-overflow-menu-]){background:#000!important;border-color:#747a7c!important;box-shadow:none!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) #awl-list-items :is([id^=pab-],.a-button.a-button-primary,[id^=awl-item-overflow-menu-])>.a-button-inner{background:transparent!important;border-color:transparent!important;box-shadow:none!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) #awl-list-items :is(.a-button-text,[id^=awl-item-overflow-menu-] .a-button-text){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) #awl-list-items [id^=awl-item-overflow-menu-] img{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
body:has(.awl-list-view-page-container):has(#wl-item-view) :is(.a-divider-inner,hr,.a-divider-normal){border-color:#494d4d!important;}
/* r1/r2 peripheral WebKit OMG quick-list surface. */
body.omg-body:has(#omg-matc-top-section-id) :is(#a-page,.empty-list-section,.empty-list-section-inner,#reorderSection,.omg-matc-bottom){background:#000!important;box-shadow:none!important;}
body.omg-body:has(#omg-matc-top-section-id) :is(#omg-matc-top-section-id,.empty-list-section,.empty-list-section-inner,.a-color-base,.a-text-bold){color:#fff!important;-webkit-text-fill-color:#fff!important;}
body.omg-body:has(#omg-matc-top-section-id) :is(.a-color-secondary,.a-color-tertiary){color:#b1b5b5!important;-webkit-text-fill-color:#b1b5b5!important;}
body.omg-body:has(#omg-matc-top-section-id) [id^=omg-multi-add-to-cart-].a-button{background:#000!important;border-color:#747a7c!important;box-shadow:none!important;}
body.omg-body:has(#omg-matc-top-section-id) [id^=omg-multi-add-to-cart-].a-button>.a-button-inner{background:transparent!important;box-shadow:none!important;}
`;
  if(__TAME__){s.textContent+=`
body:is(*,#wishlistAndFriendsLists) #wishlistAndFriendsLists img:not([class*=logo]):not([class*=icon]),
body:has(.awl-list-view-page-container):has(#wl-item-view) #awl-list-items [id^=image_] img:not([class*=icon]){
  filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;
  mix-blend-mode:normal!important;opacity:1!important;
}
`;}
}catch(_){}})();
