/* Armed page-world attribution only; no selectors, layout reads or content. */
(function(session,deadline){
  'use strict';
  if(Date.now()>=deadline)return;
  var old=window.__adThemeWork7637;
  if(old&&old.session===session&&!old.stopped)return;
  if(old)old.stop();
  var metrics=Object.create(null),order=[],slow=[],dropped=0,stopped=false,timer=0,deadlineTimer=0,dirty=false;
  var styleTrials=[],styleState=0,styleQueue=[],styleIndex=0,styleTimer=0,styleSpent=0;
  var styleMode=__STYLE_TRIALS__ && window.top===window;
  var started=performance.now(),documentId=Math.floor(Math.random()*1000000000);
  function begin(name){
    if(stopped||Date.now()>=deadline)return null;
    if(typeof name!=='string'||!/^[a-zA-Z0-9_/#-]{1,96}$/.test(name))return null;
    return {name:name,at:performance.now()};
  }
  function end(token){
    if(!token||stopped)return;
    var n=performance.now(),ms=n-token.at;if(!Number.isFinite(ms)||ms<0)return;
    var m=metrics[token.name];
    if(!m){if(order.length>=96){dropped++;return;}order.push(token.name);m=metrics[token.name]={name:token.name,count:0,totalMs:0,maxMs:0};}
    m.count++;m.totalMs+=ms;m.maxMs=Math.max(m.maxMs,ms);dirty=true;
    if(ms>=8&&slow.length<64)slow.push({name:token.name,atMs:token.at,durationMs:ms});
    if(!timer)timer=setTimeout(function(){timer=0;if(!stopped&&dirty)publish();},1000);
  }
  function run(name,fn,receiver,args){var token=begin(name);try{return fn.apply(receiver,args);}finally{end(token);}}
  // Explicit "arm styles" experiment. Never runs in a normal capture. One
  // sheet is disabled, flushed, restored and flushed in the SAME task; finally
  // restores its prior state before yielding, including every error path.
  // This measures style reapplication cost, not ordinary input latency.
  function trial(){
    styleTimer=0;
    if(stopped||document.hidden||Date.now()>=deadline){styleState=3;return;}
    if(styleIndex>=styleQueue.length){styleState=1;publish();return;}
    if(styleSpent>=1500){styleState=2;publish();return;}
    var entry=styleQueue[styleIndex++],sheet=entry.sheet,prior=sheet.disabled;
    var start=performance.now(),off=0,on=0,failed=0;
    try{
      // Settle earlier work before starting the paired measurements.
      void document.documentElement.offsetHeight;
      var t=performance.now();sheet.disabled=true;void document.documentElement.offsetHeight;off=performance.now()-t;
      t=performance.now();sheet.disabled=prior;void document.documentElement.offsetHeight;on=performance.now()-t;
    }catch(_){failed=1;}finally{sheet.disabled=prior;}
    styleSpent+=performance.now()-start;
    styleTrials.push({name:entry.name,rules:entry.rules,disableMs:off,restoreMs:on,failed:failed});
    dirty=true;publish();styleTimer=setTimeout(trial,100);
  }
  function scheduleTrials(){
    if(!styleMode||styleState||styleQueue.length||stopped)return;
    try{
      var list=document.styleSheets||[];
      for(var i=0;i<list.length&&i<128;i++){
        var sheet=list[i],owner=sheet.ownerNode,id=owner&&owner.id;
        if(sheet.disabled||typeof id!=='string'||!/^ad[0-9][a-zA-Z0-9_-]{0,94}$/.test(id))continue;
        try{styleQueue.push({sheet:sheet,name:id,rules:sheet.cssRules.length});}catch(_){}
      }
      styleQueue.sort(function(a,b){return b.rules-a.rules;});styleQueue=styleQueue.slice(0,24);
      styleTimer=setTimeout(trial,2000);
    }catch(_){styleState=3;}
  }
  function snapshot(){
    // Stylesheet metadata only, capped at 128 sheets; no selector matching or
    // forced layout. Counts also expose duplicated physical theme sheets.
    var sheets=0,rules=0,unreadable=0;
    try{var list=document.styleSheets||[];for(var i=0;i<list.length&&i<128;i++){
      var sh=list[i],owner=sh.ownerNode,id=owner&&owner.id;
      if(typeof id!=='string'||!/^ad[0-9-]/.test(id))continue;
      sheets++;try{rules+=sh.cssRules.length;}catch(_){unreadable++;}
    }}catch(_){}
    var path='';try{path=location.pathname||'';}catch(_){}
    var route=/^\/s(?:\/|$)/.test(path)?1:/^\/(?:dp(?:\/|$)|gp\/(?:product|aw\/d)\/)/.test(path)?2:0;
    return {session:session,documentId:documentId,timeOriginMs:performance.timeOrigin||0,route:route,
      durationMs:performance.now()-started,themeSheets:sheets,themeRules:rules,unreadableSheets:unreadable,
      adoptedSheets:(document.adoptedStyleSheets||[]).length,dropped:dropped,
      styleMode:styleMode?1:0,styleState:styleState,styleSpentMs:styleSpent,styleTrials:styleTrials,
      metrics:order.map(function(k){return metrics[k];}),slowCalls:slow};
  }
  function publish(){var result=snapshot();dirty=false;try{window.webkit.messageHandlers.adThemeWork7637.postMessage(result);}catch(_){}return result;}
  function stop(){
    if(stopped)return snapshot();stopped=true;
    clearTimeout(timer);clearTimeout(deadlineTimer);clearTimeout(styleTimer);timer=0;
    if(styleMode&&!styleState)styleState=3;
    window.removeEventListener('pagehide',stop,true);
    window.removeEventListener('load',publish,true);
    window.removeEventListener('load',scheduleTrials,true);
    api.stopped=true;var result=publish();
    if(window.__adThemeWork7637===api)delete window.__adThemeWork7637;
    return result;
  }
  var api={session:session,stopped:false,begin:begin,end:end,run:run,snapshot:publish,stop:stop};
  window.__adThemeWork7637=api;
  window.addEventListener('load',publish,{capture:true,passive:true,once:true});
  window.addEventListener('pagehide',stop,{capture:true,passive:true,once:true});
  if(styleMode){if(document.readyState==='complete')scheduleTrials();else window.addEventListener('load',scheduleTrials,{capture:true,passive:true,once:true});}
  deadlineTimer=setTimeout(stop,Math.max(0,deadline-Date.now()));
})(__SESSION__,__DEADLINE__);
