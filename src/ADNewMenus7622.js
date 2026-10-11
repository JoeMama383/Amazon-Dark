(function () {
  'use strict';
  function install() {
  try {
    var doc = document, html = doc.documentElement;
    if (!html) return;
    var styleId = 'ad7622-alexa-feedback-article';
    var s = doc.getElementById(styleId);
    if (!s) {
      s = doc.createElement('style');
      s.id = styleId;
      (doc.head || html).appendChild(s);
    }
    // The Alexa explanation is a separate Octopus editorial page in FULL r5,
    // NOT the home ad raster. Keep all raster geometry and graphics unchanged.
    s.textContent = `
    #a-page:has(>.a-container.octopus-page-style),
    #a-page>.a-container.octopus-page-style,
    #a-page>.a-container.octopus-page-style [data-csa-c-painter="content-grid-card-cards"],
    #a-page>.a-container.octopus-page-style [class*="_Y29ud_bxcGridContent_"] {
      background-color:#000!important;
    }
    #a-page>.a-container.octopus-page-style [class*="_Y29ud_bxcGridText_"] :is(h1,h2,h3,h4,p,span,li):not(a):not(.a-color-link){
      color:#fff!important;-webkit-text-fill-color:#fff!important;
    }
    #a-page>.a-container.octopus-page-style [class*="_Y29ud_bxcGridText_"] a {
      -webkit-text-fill-color:currentColor!important;
    }
    /* The r5 page has genuine media leaves in full-width GridImage panels;
       never set a parent filter or force image visibility/object-fit. */
    html[data-ad7622-feedback="1"],
    html[data-ad7622-feedback="1"] body,
    html[data-ad7622-feedback="1"] :is(main,article,section,form,[role=dialog]),
    html[data-ad7622-feedback="1"] :is(main,article,section,form,[role=dialog]) :is(div,header,footer),
    html[data-ad7622-feedback="1"] .a-box,
    html[data-ad7622-feedback="1"] .a-box-inner {
      background-color:#000!important;
    }
    html[data-ad7622-feedback="1"] :is(h1,h2,h3,h4,h5,h6,label,legend,p,li,span,strong,b):not([class*=link]):not(.a-color-link):not(a):not(a *) {
      color:#fff!important;-webkit-text-fill-color:#fff!important;
    }
    html[data-ad7622-feedback="1"] :is(button,[role=button],textarea,input[type=text],.a-button,.a-button-inner) {
      background:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;
      border-color:#747a7c!important;box-shadow:none!important;
    }
    html[data-ad7622-feedback="1"] :is(input[type=checkbox],input[type=radio]) {
      background-color:#000!important;border-color:#747a7c!important;
      accent-color:#167ed1!important;
    }
    html[data-ad7622-feedback="1"] :is(hr,.a-divider,[role=separator]) {border-color:#494d4d!important;}
    html[data-ad7622-feedback="1"] a,
    html[data-ad7622-feedback="1"] .a-color-link { -webkit-text-fill-color:currentColor!important; }
    html[data-ad7622-feedback="1"] :is(.a-button-primary,.a-button-oneclick,.a-button-primary>.a-button-inner) {
      background:#000!important;border-color:#747a7c!important;
    }
    html[data-ad7622-feedback="1"] :is(button:disabled,.a-button-disabled,.a-button-disabled>.a-button-inner) {
      background:#000!important;border-color:#747a7c!important;color:#b7baba!important;
    }
    `;
    var tameEnabled = __TAME__, tameFactor = '__FACTOR__';
    if (tameEnabled) {
      s.textContent += '#a-page>.a-container.octopus-page-style [class*="_Y29ud_bxcGridImage_"] img {filter:brightness('+tameFactor+')!important;-webkit-filter:brightness('+tameFactor+')!important;mix-blend-mode:normal!important;}';
    }
    function recognizeFeedback(fromInteraction) {
      try {
        // Do not synchronously layout an entire Search/PDP document at
        // DOMContentLoaded or pageshow merely to identify an unrelated ad form.
        // An actual ad-feedback click still invokes the original visible-text
        // classifier so hidden Home templates cannot be mistaken for the form.
        if (!fromInteraction) {
          var path = (typeof location !== 'undefined' && location.pathname) || '';
          if (path === '/s' || path.indexOf('/s/') === 0 ||
              path === '/dp' || path.indexOf('/dp/') === 0 ||
              path.indexOf('/gp/product/') === 0 || path.indexOf('/gp/aw/d/') === 0) return;
        }
        var txt = ((doc.body && doc.body.innerText) || '').toLowerCase();
        // Own only the actively rendered advertising feedback form (r1),
        // never its underlying Home product grid or sponsored raster.
        if (txt.indexOf('leave feedback') >= 0 && txt.indexOf('this ad is') >= 0)
          html.setAttribute('data-ad7622-feedback','1');
        else html.removeAttribute('data-ad7622-feedback');
      } catch (_) {}
    }
    if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded',recognizeFeedback,{once:true});
    else recognizeFeedback();
    window.addEventListener('pageshow',recognizeFeedback,{once:true});
    // User-triggered feedback is inserted after document load. Check only the
    // exact click family and on completion of that interaction; never poll.
    doc.addEventListener('click',function (e) {
      try {
        var t=e.target;
        if (t && t.closest && t.closest('[id^="ad-feedback-"],[class*="ad-feedback-primary-link"],[id^="af-label-primary-link-"]')) {
          setTimeout(function(){recognizeFeedback(true);},200);
          setTimeout(function(){recognizeFeedback(true);},700);
        }
      } catch (_) {}
    },true);
  } catch (_) {}
  }
  // WebKit document-start occasionally precedes documentElement creation.
  // Use exactly one DOMContentLoaded fallback, not a recurring observer.
  if (document.documentElement) install();
  else document.addEventListener('DOMContentLoaded',install,{once:true});
})();
