(function(){
  try {
    'use strict';

    var d=document;
    var de=d.documentElement;
    var STYLE_ID='ad7620-menu-repair-style';
    var FOLLOWUP_MS=900;
    var whiteTameFactor=0.684; // matches the current native/web taming strength family closely enough for repair work.

    function ensureStyle(){
      if(d.getElementById(STYLE_ID)) return;
      var style=d.createElement('style');
      style.id=STYLE_ID;
      style.textContent='\
html[data-ad7620-order-detail="1"],\
html[data-ad7620-order-detail="1"] body,\
html[data-ad7620-order-detail="1"] #a-page,\
html[data-ad7620-order-detail="1"] .od-container,\
html[data-ad7620-order-detail="1"] .od-modernized { background:#000 !important; color:#fff !important; color-scheme:dark !important; }\
html[data-ad7620-order-detail="1"] .a-subheader { background:#000 !important; border-bottom:1px solid #5a5f61 !important; }\
html[data-ad7620-order-detail="1"] .a-subheader :is(h1,h2,h3,h4,h5,h6,span,div,p),\
html[data-ad7620-order-detail="1"] .od-container :is(h1,h2,h3,h4,h5,h6,p,span,div,li,strong,b) { color:#fff !important; }\
html[data-ad7620-order-detail="1"] .od-container :is(.a-color-secondary,.a-size-small,.a-size-mini,.a-color-tertiary) { color:#c8cccc !important; }\
html[data-ad7620-order-detail="1"] .od-container a:not(.a-button-text):not(.a-link-normal),\
html[data-ad7620-order-detail="1"] .od-container .a-link-normal,\
html[data-ad7620-order-detail="1"] .od-container .a-link-emphasis { color:#5fa7ff !important; }\
html[data-ad7620-order-detail="1"] .od-container :is(.a-box,.a-box-inner,.a-cardui,.a-cardui-body,.a-cardui-deck,.a-box-group,.oui-shipment-card,.a-expander-container,.a-expander-content,.a-row,.a-section,.a-fixed-left-grid, .a-fixed-right-grid, .a-fixed-right-grid-inner, .a-fixed-left-grid-col, .a-fixed-right-grid-col) { background:#000 !important; box-shadow:none !important; }\
html[data-ad7620-order-detail="1"] .od-container :is(.a-box,.a-cardui,.a-box-title,.a-box-group,.a-expander-container,.a-expander-inner,.a-popover-inner,.a-divider) { border-color:#5a5f61 !important; }\
html[data-ad7620-order-detail="1"] .od-container hr,\
html[data-ad7620-order-detail="1"] .od-container .a-divider.a-divider-section { border-color:#5a5f61 !important; background:#5a5f61 !important; }\
html[data-ad7620-order-detail="1"] .od-container :is(.a-button,.a-button-focus,.a-button-inner,.a-button-toggle,.a-declarative.a-button,.a-touch-link.a-box[role="button"]) { background:#000 !important; border-color:#7a8082 !important; box-shadow:none !important; }\
html[data-ad7620-order-detail="1"] .od-container :is(.a-button-text,.a-button-inner span,.a-touch-link.a-box[role="button"] span,.a-touch-link.a-box[role="button"] div) { color:#fff !important; }\
html[data-ad7620-order-detail="1"] .od-container .a-button:before,\
html[data-ad7620-order-detail="1"] .od-container .a-button:after { display:none !important; }\
html[data-ad7620-order-detail="1"] .od-container img { filter:brightness('+whiteTameFactor+') !important; }\
html[data-ad7620-order-detail="1"] .od-container svg,\
html[data-ad7620-order-detail="1"] .od-container i.a-icon,\
html[data-ad7620-order-detail="1"] .od-container [class*="icon"] { color:#fff !important; }\
html[data-ad7620-order-detail="1"] .od-container i.a-icon-touch-link { border-color:#fff !important; }\
html[data-ad7620-order-detail="1"] .od-container [style*="background-image"] { background-color:#000 !important; background-blend-mode:normal !important; }\
html[data-ad7620-order-detail="1"] .od-container .a-progress-bar,\
html[data-ad7620-order-detail="1"] .od-container [role="progressbar"] { background:#3e4446 !important; }\
html[data-ad7620-order-detail="1"] .od-container [class*="progress"] [style*="width"],\
html[data-ad7620-order-detail="1"] .od-container [class*="ordered"] { border-color:inherit !important; }\
html[data-ad7620-ad-prefs="1"],\
html[data-ad7620-ad-prefs="1"] body,\
html[data-ad7620-ad-prefs="1"] #a-page,\
html[data-ad7620-ad-prefs="1"] .a-container { background:#000 !important; color:#fff !important; color-scheme:dark !important; }\
html[data-ad7620-ad-prefs="1"] a.a-touch-link.a-box.back-button.a-color-alternate-background { background:#000 !important; border-bottom:1px solid #5a5f61 !important; }\
html[data-ad7620-ad-prefs="1"] :is(.back-button-text,.a-icon-touch-link, h1,h2,h3,h4,h5,h6,p,span,div,li,strong,b,label) { color:#fff !important; }\
html[data-ad7620-ad-prefs="1"] .a-color-link,\
html[data-ad7620-ad-prefs="1"] a:not(.a-button-text),\
html[data-ad7620-ad-prefs="1"] [class*="legal"] a { color:#5fa7ff !important; }\
html[data-ad7620-ad-prefs="1"] :is(.a-box,.a-box-inner,.a-box-group,.a-cardui,.a-cardui-body,.a-expander-container,.a-expander-content,.a-expander-partial-collapse-container,.a-section,.a-row,.a-radio,.a-radio-label,.a-fixed-left-grid, .a-fixed-right-grid, .a-fixed-right-grid-inner, .a-fixed-left-grid-col, .a-fixed-right-grid-col) { background:#000 !important; box-shadow:none !important; }\
html[data-ad7620-ad-prefs="1"] :is(.a-box,.a-box-group,.a-box-title,.a-cardui,.a-section,.a-expander-container,.a-radio, .a-radio-label, hr, .a-divider, .a-divider-section) { border-color:#5a5f61 !important; }\
html[data-ad7620-ad-prefs="1"] .a-box.a-first.a-box-title .a-box-inner { background:#232628 !important; }\
html[data-ad7620-ad-prefs="1"] .a-box-group > .a-box,\
html[data-ad7620-ad-prefs="1"] .a-box-group > .a-box > .a-box-inner,\
html[data-ad7620-ad-prefs="1"] .a-box-group > a.a-box,\
html[data-ad7620-ad-prefs="1"] .a-box-group > a.a-box > .a-box-inner { background:#232628 !important; }\
html[data-ad7620-ad-prefs="1"] .a-button,\
html[data-ad7620-ad-prefs="1"] .a-button-inner,\
html[data-ad7620-ad-prefs="1"] .a-button-focus,\
html[data-ad7620-ad-prefs="1"] .a-declarative.a-button { background:#000 !important; border-color:#7a8082 !important; box-shadow:none !important; }\
html[data-ad7620-ad-prefs="1"] .a-button-text,\
html[data-ad7620-ad-prefs="1"] .a-button-inner span { color:#fff !important; }\
html[data-ad7620-ad-prefs="1"] .a-radio .a-icon-radio,\
html[data-ad7620-ad-prefs="1"] .a-radio .a-icon-radio-inactive { filter:brightness(1) !important; }\
html[data-ad7620-ad-prefs="1"] .a-radio label,\
html[data-ad7620-ad-prefs="1"] .a-radio span { color:#fff !important; }\
html[data-ad7620-ad-prefs="1"] svg,\
html[data-ad7620-ad-prefs="1"] i.a-icon,\
html[data-ad7620-ad-prefs="1"] [class*="icon"] { color:#fff !important; }\
html[data-ad7620-ad-prefs="1"] i.a-icon-touch-link { border-color:#fff !important; }\
html[data-ad7620-ad-prefs="1"] img { filter:brightness('+whiteTameFactor+') !important; }\
html[data-ad7620-ad-prefs="1"] [style*="background-image"] { background-color:#000 !important; background-blend-mode:normal !important; }\
';
      (d.head||d.documentElement).appendChild(style);
    }

    function normText(v){ return String(v||'').replace(/\s+/g,' ').trim().toLowerCase(); }
    function bodyText(){ return normText((d.body && (d.body.innerText||d.body.textContent)) || ''); }
    function hasAny(txt, arr){ for(var i=0;i<arr.length;i++){ if(txt.indexOf(arr[i])!==-1) return true; } return false; }
    function setFlag(name, on){ if(on) de.setAttribute(name,'1'); else de.removeAttribute(name); }

    function detectRoutes(){
      var txt=bodyText();
      var orderRoute=!!(d.querySelector('.od-container, .od-modernized, .od-card-deck, .oui-shipment-card') || (txt.indexOf('order details')!==-1 && hasAny(txt,['track package','update delivery instructions','order summary','buy it again','change payment method'])));
      var adPrefsRoute=!!(
        (d.querySelector('a.back-button') && hasAny(txt,['amazon advertising preferences','advertising privacy and preferences','interest-based ad preferences','delete ad data'])) ||
        hasAny(txt,['delete your personal information from our ad systems','show me interest-based ads provided by amazon'])
      );
      setFlag('data-ad7620-order-detail', orderRoute);
      setFlag('data-ad7620-ad-prefs', adPrefsRoute);
    }

    function visibleRect(el){
      try {
        if(!el || !el.getBoundingClientRect) return null;
        var r=el.getBoundingClientRect();
        if(r.width<1 || r.height<1) return null;
        return r;
      } catch(_){ return null; }
    }

    function setVisible(el){
      try {
        if(!el || !el.style) return;
        el.style.setProperty('opacity','1','important');
        el.style.setProperty('visibility','visible','important');
      } catch(_){ }
    }

    function tameVisual(el){
      try {
        if(!el || !el.style) return;
        setVisible(el);
        if(/^(IMG|VIDEO|CANVAS)$/i.test(el.tagName)){
          el.style.setProperty('filter','brightness('+whiteTameFactor+')','important');
          if(el.tagName==='IMG' || el.tagName==='VIDEO') el.style.setProperty('object-fit','cover','important');
          var cs=window.getComputedStyle ? getComputedStyle(el) : null;
          if(cs && cs.display==='none') el.style.setProperty('display','block','important');
        }
        var bg='';
        try {
          bg=(window.getComputedStyle ? getComputedStyle(el).backgroundImage : '') || el.style.backgroundImage || '';
        } catch(__){ bg=el.style.backgroundImage || ''; }
        if(bg && bg!=='none'){
          el.style.setProperty('background-image',bg,'important');
          el.style.setProperty('background-position','center center','important');
          el.style.setProperty('background-size','cover','important');
          el.style.setProperty('background-repeat','no-repeat','important');
          el.style.setProperty('background-color','#000','important');
        }
      } catch(_){ }
    }

    function restoreLargeRasterAds(){
      try {
        var candidates=d.querySelectorAll('[class*="single-creative-card" i],[class*="single-video-card" i],[class*="theming-card" i],[class*="canvas-card" i],[class*="canvas-container" i],[class*="billboard" i],[class*="hero" i],[class*="sponsored" i],[data-card-type],[data-testid]');
        if(!candidates || !candidates.length) return;
        for(var i=0;i<candidates.length;i++){
          var card=candidates[i];
          var r=visibleRect(card);
          if(!r || r.width<140 || r.height<120) continue;
          var text=normText(card.innerText||card.textContent);
          if(!(text.indexOf('sponsored')!==-1 || text.indexOf('interest')!==-1 || text.indexOf('new items in your')!==-1)) continue;
          var media=card.querySelectorAll('img,video,canvas,[style*="background-image" i],[class*="poster" i],[class*="hero" i],[class*="background" i]');
          for(var m=0;m<media.length;m++){
            var node=media[m];
            var mr=visibleRect(node);
            if(mr && mr.width>=60 && mr.height>=40) tameVisual(node);
          }
          tameVisual(card);
        }
      } catch(_){ }
    }

    function runRepair(){
      ensureStyle();
      detectRoutes();
      restoreLargeRasterAds();
    }

    if(d.readyState==='loading'){
      d.addEventListener('DOMContentLoaded', runRepair, {once:true});
    } else {
      runRepair();
    }
    window.addEventListener('load', function(){ runRepair(); setTimeout(runRepair, FOLLOWUP_MS); }, {once:true});
    window.addEventListener('pageshow', function(){ runRepair(); setTimeout(runRepair, FOLLOWUP_MS); }, {once:true});
  } catch(_){ }
})();
