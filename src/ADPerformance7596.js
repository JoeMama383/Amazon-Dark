/* Armed diagnostic only. No DOM scan, selectors, content, URL or input values. */
(function(session, deadline) {
  'use strict';
  if (Date.now() >= deadline) return;
  var old = window.__adPerformance7596;
  if (old && old.session === session && !old.stopped) return;
  if (old) old.stop('replaced');
  var now = function() { return performance.now(); };
  var started = now(), stopped = false, raf = 0, timer = 0, snapshotTimer = 0, heartbeatTimer = 0, last = 0;
  var observers = [], pending = [], listeners = [], resourceSeen = 0;
  function metric() { return {count:0,totalMs:0,maxMs:0,buckets:[0,0,0,0,0,0,0,0]}; }
  var frames=metric(), inputFrame=metric(), eventTiming=metric(), longTasks=metric(), resources=metric();
  var inputArrival=metric(), taskDelay=metric(), eventLoopLag=metric(), inputKinds={}, slowEvents=[];
  var taskPending=false, taskTimer=0, expectedBeat=0;
  var scrollFromMove=metric(), scrollFromTouch=metric();
  var scrollGestures=0, scrollStarted=0, touchAt=-1, movedAt=-1;
  // Opaque session-local document key; no page URL or content is recorded.
  var documentId=Math.floor(Math.random()*1000000000), initialSent=false;
  var types=[], supported=(window.PerformanceObserver && PerformanceObserver.supportedEntryTypes)||[];
  var resourceKinds={}, inputDropped=0;
  function add(m,v) {
    if (!Number.isFinite(v) || v < 0) return;
    m.count++; m.totalMs+=v; m.maxMs=Math.max(m.maxMs,v);
    var bounds=[1,4,8,16.7,33.4,50,100], i=0;
    while(i<bounds.length && v>bounds[i]) i++;
    m.buckets[i]++;
  }
  function entries(kind,list) {
    list.forEach(function(e) {
      if(kind==='resource') {
        if(resourceSeen++>=4096) return;
        add(resources,e.duration);
        var key=['img','script','css','fetch','xmlhttprequest'].indexOf(e.initiatorType)>=0?e.initiatorType:'other';
        resourceKinds[key]=(resourceKinds[key]||0)+1;
      } else if(kind==='event') add(eventTiming,e.duration);
      else add(longTasks,e.duration);
    });
  }
  ['longtask','event','resource'].forEach(function(kind) {
    if(supported.indexOf(kind)<0) return;
    try {
      var ob=new PerformanceObserver(function(list){if(!stopped)entries(kind,list.getEntries());});
      ob.observe(kind==='event'?{type:kind,durationThreshold:16}:{type:kind});
      observers.push({ob:ob,kind:kind});types.push(kind);
    } catch(_) {}
  });
  function on(type,fn) { window.addEventListener(type,fn,{capture:true,passive:true}); listeners.push([type,fn]); }
  function input(e) {
    if(pending.length>=64){inputDropped++;return;}
    // Timestamp-to-next-RAF is a responsiveness proxy, not actual display latency.
    var t=Number(e.timeStamp), n=now();
    if(t>1e12) t-=performance.timeOrigin || (Date.now()-n);
    t=Number.isFinite(t)&&t>=0&&t<=n?t:n;
    add(inputArrival,n-t);inputKinds[e.type]=(inputKinds[e.type]||0)+1;
    if(n-t>50 && slowEvents.length<64)slowEvents.push({atMs:n-started,delayMs:n-t,kind:1});
    pending.push(t);
    if(!taskPending){taskPending=true;taskTimer=setTimeout(function(){taskPending=false;if(!stopped)add(taskDelay,now()-n);},0);}
  }
  on('pointerdown',input);on('pointerup',input);on('keydown',input);on('click',input);
  // Safari fallback. Avoid counting the same down twice when Pointer Events exist.
  if(!window.PointerEvent)on('touchstart',input);
  function heartbeat(){
    if(stopped)return;
    var n=now();
    if(!document.hidden && expectedBeat){var lag=Math.max(0,n-expectedBeat);add(eventLoopLag,lag);if(lag>50&&slowEvents.length<64)slowEvents.push({atMs:n-started,delayMs:lag,kind:2});}
    expectedBeat=n+250;heartbeatTimer=setTimeout(heartbeat,250);
  }
  on('visibilitychange',function(){expectedBeat=0;last=0;});
  on('touchstart',function(){touchAt=now();movedAt=-1;});
  on('touchmove',function(){if(touchAt>=0 && movedAt<0){movedAt=now();scrollGestures++;}});
  on('scroll',function(){
    if(movedAt<0)return;var t=now();
    add(scrollFromMove,t-movedAt);add(scrollFromTouch,t-touchAt);
    scrollStarted++;movedAt=-1;touchAt=-1;
  });
  function tick(t) {
    if(stopped)return;
    if(Date.now()>=deadline){stop('deadline');return;}
    if(!document.hidden && last) add(frames,t-last);
    last=document.hidden?0:t;
    if(!document.hidden){pending.forEach(function(p){add(inputFrame,t-p);});pending=[];}
    raf=requestAnimationFrame(tick);
  }
  function report(reason, sendToBridge) {
    var nav={};
    try{var e=performance.getEntriesByType('navigation')[0]; if(e)['responseStart','responseEnd','domInteractive','domContentLoadedEventEnd','loadEventEnd'].forEach(function(k){if(Number.isFinite(e[k]))nav[k]=e[k];});}catch(_){}
    var result={session:session,timeOriginMs:performance.timeOrigin||0,documentId:documentId,reason:reason,durationMs:now()-started,
      supported:types,inputArrival:inputArrival,inputTaskDelay:taskDelay,eventLoopLag:eventLoopLag,inputKinds:inputKinds,slowEvents:slowEvents,frames:frames,inputToNextRAF:inputFrame,eventTiming:eventTiming,
      longTasks:longTasks,resources:resources,resourceKinds:resourceKinds,
      scrollFromMove:scrollFromMove,scrollFromTouch:scrollFromTouch,
      scrollGestures:scrollGestures,scrollStarted:scrollStarted,
      resourceEntriesDropped:Math.max(0,resourceSeen-4096),pendingInputs:pending.length,
      inputDropped:inputDropped,navigationMs:nav};
    // The evaluateJavaScript completion returns this very same bounded data
    // even if WKScriptMessageHandler fails or is unavailable in the document.
    // Do not treat a successful eval callback as successful bridge delivery.
    result.bridgeAttempted=(sendToBridge!==false)?1:0;
    result.bridgeFailed=0;
    if(sendToBridge!==false){
      try{window.webkit.messageHandlers.adPerformance7596.postMessage(result);}
      catch(_){result.bridgeFailed=1;}
    }
    return result;
  }
  function snapshotInitial() {
    if(stopped)return report('snapshot',false);
    if(initialSent)return report('snapshot',false);
    initialSent=true;return report('snapshot');
  }
  function snapshot() {
    if(stopped)return;
    if(Date.now()>=deadline){stop('deadline');return;}
    report('snapshot');
    // Opt-in only, one tiny aggregate every 5s; no DOM traversal or mutation.
    snapshotTimer=setTimeout(snapshot,5000);
  }
  function stop(reason) {
    if(stopped)return;
    observers.forEach(function(x){try{entries(x.kind,x.ob.takeRecords());x.ob.disconnect();}catch(_){}});
    stopped=true;if(window.__adPerformance7596)window.__adPerformance7596.stopped=true;
    cancelAnimationFrame(raf);clearTimeout(timer);clearTimeout(snapshotTimer);clearTimeout(heartbeatTimer);clearTimeout(taskTimer);
    listeners.forEach(function(x){window.removeEventListener(x[0],x[1],true);});
    return report(reason);
  }
  on('pagehide',function(){stop('pagehide');});
  window.__adPerformance7596={session:session,stop:stop,snapshotInitial:snapshotInitial};
  timer=setTimeout(function(){stop('deadline');},Math.max(0,deadline-Date.now()));
  heartbeat();
  raf=requestAnimationFrame(tick);
  snapshotTimer=setTimeout(snapshot,5000);
})(__SESSION__, __DEADLINE__);
