(function(){try{
  'use strict';
  var doc=document;
  var marker='data-ad7620-adprefs';
  var cssId='ad7620-order-ads-privacy';
  var style=doc.getElementById(cssId);
  if(!style){style=doc.createElement('style');style.id=cssId;(doc.head||doc.documentElement).appendChild(style);}
  // v7.620: All floors are OLED.  Gray is limited to Amazon's EXISTING borders,
  // separators, and unselected progress geometry.  No new border widths/radii.
  // The source of this page ownership is the 10/10/26 FULL DOM probe r1/r5/r6.
  style.textContent=`
/* Your Orders > Order details; exact observed .od-container / .od-modernized. */
#a-page .od-modernized .od-container,
#a-page .od-modernized .od-card-deck,
#a-page .od-modernized .a-cardui,
#a-page .od-modernized .a-cardui-body,
#a-page .od-modernized .oui-shipment-card,
#a-page .od-modernized .a-box,
#a-page .od-modernized .a-box-inner,
#a-page .od-modernized .oui-shipment-expander,
#a-page .od-modernized .oui-shipment-expander-header,
#a-page .od-modernized .a-expander-content,
#a-page .od-modernized .a-expander-container,
#a-page .od-modernized .a-expander-header.a-expander-section-header,
#a-page .od-modernized .a-subheader {background:#000!important;background-color:#000!important;box-shadow:none!important;}
#a-page .od-modernized .od-container,
#a-page .od-modernized .od-container :is(.a-box,.a-cardui,.oui-shipment-expander-header,.a-expander-container,.oui-shipment-card),
#a-page .od-modernized .a-subheader {border-color:#494d4d!important;}
#a-page .od-modernized .a-subheader{border-bottom-color:#494d4d!important;}
#a-page .od-modernized .a-subheader :is(h1,h2,h3,h4,span){color:#fff!important;-webkit-text-fill-color:#fff!important;}
#a-page .od-modernized .oui-shipment-expander-header :is(span,div,strong,b){color:#fff!important;-webkit-text-fill-color:#fff!important;}
#a-page .od-modernized .od-container :is(hr,.a-divider-inner){border-color:#494d4d!important;}
/* Existing borders, not a duplicated surrounding line. */
#a-page .od-modernized .od-container :is(.a-button,.a-button-primary,.a-button-base,.a-button-small){background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;}
#a-page .od-modernized .od-container .a-button>.a-button-inner{background:transparent!important;background-color:transparent!important;box-shadow:none!important;}
#a-page .od-modernized .od-container .a-button .a-button-text,
#a-page .od-modernized .od-container .a-button .a-button-text *{color:#fff!important;-webkit-text-fill-color:#fff!important;}
/* Standard neutral copy: protect authored links, statuses, and tracked progress. */
#a-page .od-modernized :is(h1,h2,h3,h4,h5,h6,p,span,div,strong,b,label,.a-color-base,.a-color-secondary,.a-color-tertiary):not(.a-color-link):not(.a-color-price):not(.a-color-error):not(.a-color-success):not(.a-color-state):not([class*=active]):not([class*=success]):not([class*=alert]):not(:where(a *)):not(:where(.a-color-link *)) {color:#fff!important;-webkit-text-fill-color:#fff!important;}
#a-page .od-modernized .od-container :is(.a-color-link,a.a-link-normal,.a-link-emphasis){-webkit-text-fill-color:currentColor!important;}
#a-page .od-modernized .oui-item-card :is(.a-text-bold,.a-color-base):not(.a-color-link){color:#fff!important;-webkit-text-fill-color:#fff!important;}
#a-page .od-modernized .od-container .od-milestone-marker:not(.active){background:#000!important;background-color:#000!important;border-color:#888c8c!important;}
#a-page .od-modernized .od-container .od-milestone-marker.active,
#a-page .od-modernized .od-container .od-milestone-bar.active{filter:none!important;-webkit-filter:none!important;}
#a-page .od-modernized .od-container :is(.a-icon-page-back,.a-subheader-back,.a-icon-touch-link,.a-icon-section-collapse,.a-icon-section-expand){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
#a-page .od-modernized .od-container .od-milestone-bar:not(.active){background:#888c8c!important;}
/* Only product photos, never icon/sprites; tame intensity comes from pref input. */
__AD7620_ORDER_IMAGES__

/* Amazon Advertising Preferences landing / delete-ad-data / interest opt-in. */
html[data-ad7620-adprefs="1"] body,
html[data-ad7620-adprefs="1"] #a-page,
html[data-ad7620-adprefs="1"] #a-page>.a-container{background:#000!important;background-color:#000!important;color-scheme:dark!important;}
html[data-ad7620-adprefs="1"] #a-page a.a-touch-link.a-box.back-button.a-color-alternate-background,
html[data-ad7620-adprefs="1"] #a-page a.a-touch-link.a-box.back-button.a-color-alternate-background>.a-box-inner{background:#000!important;background-color:#000!important;}
html[data-ad7620-adprefs="1"] #a-page a.back-button .back-button-text{color:#fff!important;-webkit-text-fill-color:#fff!important;}
html[data-ad7620-adprefs="1"] #a-page a.back-button i.a-icon-touch-link{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
/* r2 landing ownership: the page has NO a.back-button.  Both actual IDs
   are mandatory before the landing owner is activated. */
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background{
  background:#000!important;background-color:#000!important;color:#fff!important;
}
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background>.a-box-group,
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background>.a-box-group>.a-box.a-box-normal,
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background>.a-box-group>.a-box.a-box-normal>.a-box-inner,
html[data-ad7620-adprefs="1"] #a-page :is(#mobileDataDeleteButton,#mobileAdPreferenceButton),
html[data-ad7620-adprefs="1"] #a-page :is(#mobileDataDeleteButton,#mobileAdPreferenceButton)>.a-box-inner{
 background:#000!important;background-color:#000!important;box-shadow:none!important;
}
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background>.a-box-group>.a-box.a-box-normal{
 border-color:#494d4d!important;
}
html[data-ad7620-adprefs="1"] #a-page :is(#mobileDataDeleteButton,#mobileAdPreferenceButton) :is(span,.a-box-inner){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
html[data-ad7620-adprefs="1"] #a-page :is(#mobileDataDeleteButton,#mobileAdPreferenceButton) .a-icon-touch-link{
 color:#fff!important;border-color:#fff!important;
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background .column-text>.a-size-large{
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Links under Legal policies retain authored blue instead of being whitened. */
html[data-ad7620-adprefs="1"] #a-page>.a-container.container-background .column-text a{
 -webkit-text-fill-color:currentColor!important;
}
/* Preserve the page's authored teal header background; title is already white. */
html[data-ad7620-adprefs="1"] #a-page>h1.header-text-mobile{
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* Exact r6 preference card, r5 expanded deletion, and collapsed delete card. */
html[data-ad7620-adprefs="1"] #a-page :is(.a-box-group.a-spacing-base,.a-box-group.a-spacing-base>.a-box,.a-box-group.a-spacing-base>.a-box>.a-box-inner,
.a-box.a-first.a-box-title,.a-box.a-first.a-box-title>.a-box-inner,.a-box.a-last,.a-box.a-last>.a-box-inner,
.a-box-group.a-form-control-group,.a-expander-container.a-expander-extend-container,.a-expander-content.a-expander-extend-content){background:#000!important;background-color:#000!important;box-shadow:none!important;}
html[data-ad7620-adprefs="1"] #a-page :is(.a-box,.a-box-group,.a-subheader,hr,.a-divider-inner){border-color:#494d4d!important;}
/* Neutral text only.  Blue links, opt-in radio color, and teal brand header stay authored. */
html[data-ad7620-adprefs="1"] #a-page :is(h1,h2,h3,h4,h5,h6,p,li,label,span,strong,b,div):not(a):not(:where(a *)):not(.a-color-link):not(.a-expander-prompt):not(.a-color-price):not([class*=radio]):not([class*=teal]):not([class*=header-brand]){color:#fff!important;-webkit-text-fill-color:#fff!important;}
html[data-ad7620-adprefs="1"] #a-page :is(a.a-color-link,.a-expander-header,.a-expander-prompt,a.a-link-normal){-webkit-text-fill-color:currentColor!important;}
html[data-ad7620-adprefs="1"] #a-page :is(.a-expander-header i.a-icon,.a-expander-header .a-icon-collapse,.a-expander-header .a-icon-expand){filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
/* Submit / Delete ad data buttons: OLED + existing gray perimeter, white copy. */
html[data-ad7620-adprefs="1"] #a-page :is(.a-button,.a-button-base,.a-button-primary,.a-button-small,#optOutControl){background:#000!important;background-color:#000!important;border-color:#747a7c!important;box-shadow:none!important;}
html[data-ad7620-adprefs="1"] #a-page :is(.a-button,.a-button-base,.a-button-primary,.a-button-small)>.a-button-inner{background:transparent!important;background-color:transparent!important;box-shadow:none!important;}
html[data-ad7620-adprefs="1"] #a-page :is(.a-button-text,#optOutControl .a-button-text,.a-button .a-button-text *){color:#fff!important;-webkit-text-fill-color:#fff!important;}
/* Preserve the Amazon blue selected-radio asset; only white radio *floor* becomes OLED. */
html[data-ad7620-adprefs="1"] #a-page .a-radio.a-radio-fancy{background:#000!important;background-color:#000!important;}
/* Landing page: neutral link-row floors, not the separate teal identity banner. */
html[data-ad7620-adprefs="1"] #a-page :is(.a-box-group>.a-box,.a-box-group>.a-box>.a-box-inner,a.a-touch-link.a-box:not(.back-button),a.a-touch-link.a-box:not(.back-button)>.a-box-inner){background:#000!important;background-color:#000!important;border-color:#494d4d!important;}
html[data-ad7620-adprefs="1"] #a-page a.a-touch-link.a-box:not(.back-button) :is(.a-box-inner,span,strong,b){color:#fff!important;-webkit-text-fill-color:#fff!important;}
html[data-ad7620-adprefs="1"] #a-page a.a-touch-link.a-box:not(.back-button) i.a-icon-touch-link{filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;}
`;
  // Native r2 has #mobileDataDeleteButton and #mobileAdPreferenceButton but no
  // a.back-button: use those exact owners. r5/r6 have a.back-button and a
  // page-specific expander/radio layout. No foreground scans or polling.
  if(typeof ad7640HotRoute==='function' && ad7640HotRoute())return;
  function owner(){
    try{
      var page=doc.getElementById('a-page');
      if(!page)return;
      var hasOrders=!!page.querySelector('.od-modernized .od-container');
      if(hasOrders){doc.documentElement.removeAttribute(marker);return;}
      var landing=!!page.querySelector('#mobileDataDeleteButton')&&
                  !!page.querySelector('#mobileAdPreferenceButton');
      var preferenceRadio=!!page.querySelector('#optOutControl') &&
                          !!page.querySelector('.a-radio.a-radio-fancy');
      var hasAdPreferenceHeader=!!page.querySelector('a.back-button .back-button-text');
      var titleText=(page.querySelector('a.back-button .back-button-text')||{}).textContent||'';
      var heading=page.querySelector('.a-size-large');
      var headingText=heading?(heading.textContent||''):'';
      var words=(titleText+' '+headingText).toLowerCase();
      var expandedDeletion=hasAdPreferenceHeader&&(
        words.indexOf('advertising preferences')!==-1 ||
        words.indexOf('delete your personal information from our ad systems')!==-1);
      var prefs=landing||preferenceRadio||expandedDeletion;
      if(prefs)doc.documentElement.setAttribute(marker,'1');
      else doc.documentElement.removeAttribute(marker);
    }catch(_e){}
  }
  if(doc.readyState==='loading')doc.addEventListener('DOMContentLoaded',owner,{once:true});
  else owner();
  window.addEventListener('load',owner,{once:true});
  window.addEventListener('pageshow',owner,{once:true});
}catch(_e){}})();
