/* Explicitly armed diagnostic only. No polling, prototype hooks or DOM walk. */
function ad7643StartupIsolation(mode, deadline) {
  var entries=[], floor=null, active=false, closed=false, late=0, failures=0;
  var calls=0, bytes=0, restored=0, restoreMs=0;
  var rulesAtStop=-1,adoptedAtStop=-1;
  var hot=false;
  try { hot=window.top===window && /^\/(?:s(?:\/|$)|dp(?:\/|$)|gp\/(?:product|aw\/d)\/)/.test(location.pathname); } catch (_) {}
  if (mode && hot) {
    // Never retrospectively strip an already themed document. Its earlier
    // loading cost cannot be attributed to an experiment armed afterwards.
    late=document.readyState!=='loading'?1:0;
    var sheets=document.styleSheets||[];
    for(var i=0;i<sheets.length&&i<128&&!late;i++) {
      var owner=sheets[i].ownerNode;
      if(owner && /^ad[0-9]/.test(owner.id||''))late=1;
    }
    active=!late && Date.now()<deadline;
  }
  function matches(id) {
    var core=id==='ad7-menu-theme'||id==='ad7-product-feed-theme';
    return mode===1 || (mode===2&&core) || (mode===3&&!core);
  }
  function intercept(style, css, apply) {
    if(!active||closed||Date.now()>=deadline||!style||!matches(style.id||''))return false;
    var index=-1;
    for(var i=0;i<entries.length;i++)if(entries[i].node===style){index=i;break;}
    if(index<0 && entries.length>=128){failures++;return false;}
    if(!floor) {
      floor=document.createElement('style');floor.id='ad7643-isolation-floor';
      // A simple black diagnostic floor, not a replacement production theme.
      // No geometry, image filters or relational selectors in this control.
      floor.textContent='html,body,#a-page,#search,#dp,#ppd{background-color:#000!important;color:#fff!important;color-scheme:dark!important}';
      (document.head||document.documentElement).appendChild(floor);
    }
    calls++;
    if(index<0){index=entries.length;entries.push({node:style,apply:apply,bytes:css.length});bytes+=css.length;}
    else {bytes+=css.length-entries[index].bytes;entries[index].apply=apply;entries[index].bytes=css.length;}
    style.textContent='';return true;
  }
  function snapshot() {
    return {isolationMode:mode,isolationEligible:active?1:0,isolationLate:late,
      isolationStyles:entries.length,isolationCalls:calls,isolationBytes:bytes,
      isolationFailures:failures,isolationRestored:restored,isolationRestoreMs:restoreMs,
      isolationRulesAtStop:rulesAtStop,isolationAdoptedAtStop:adoptedAtStop};
  }
  function restore(rules,adopted) {
    if(closed)return;closed=true;
    rulesAtStop=Math.max(0,(rules||0)-(floor?1:0));adoptedAtStop=adopted||0;
    var start=performance.now();
    for(var i=0;i<entries.length;i++) {
      try { entries[i].apply();restored++; } catch (_) {failures++;}
      entries[i].apply=null;entries[i].node=null;
    }
    if(floor){floor.remove();floor=null;}
    restoreMs=performance.now()-start;
  }
  return {style:active?intercept:null,snapshot:snapshot,restore:restore};
}
