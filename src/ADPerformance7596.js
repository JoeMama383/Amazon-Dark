/* Armed diagnostic only. No DOM scan, selectors, content, URL or input values. */
(function(session, deadline) {
  'use strict';
  if (Date.now() >= deadline) return;
  var old = window.__adPerformance7596;
  if (old && old.session === session && !old.stopped) return;
  if (old) old.stop('replaced');
  var now = function() { return performance.now(); };
  var started = now(), stopped = false, raf = 0, timer = 0, last = 0;
  var observers = [], pending = [], listeners = [], resourceSeen = 0;
  function metric() { return {count:0,totalMs:0,maxMs:0,buckets:[0,0,0,0,0,0,0,0]}; }
  var frames=metric(), inputFrame=metric(), eventTiming=metric(), longTasks=metric(), resources=metric();
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
    pending.push(Number.isFinite(t)&&t>=0&&t<=n?t:n);
  }
  on('pointerdown',input);on('keydown',input);
  function tick(t) {
    if(stopped)return;
    if(Date.now()>=deadline){stop('deadline');return;}
    if(!document.hidden && last) add(frames,t-last);
    last=document.hidden?0:t;
    if(!document.hidden){pending.forEach(function(p){add(inputFrame,t-p);});pending=[];}
    raf=requestAnimationFrame(tick);
  }
  function stop(reason) {
    if(stopped)return;
    observers.forEach(function(x){try{entries(x.kind,x.ob.takeRecords());x.ob.disconnect();}catch(_){}});
    stopped=true; if(window.__adPerformance7596)window.__adPerformance7596.stopped=true; cancelAnimationFrame(raf);clearTimeout(timer);
    listeners.forEach(function(x){window.removeEventListener(x[0],x[1],true);});
    var nav={};
    try{var e=performance.getEntriesByType('navigation')[0]; if(e)['responseStart','responseEnd','domInteractive','domContentLoadedEventEnd','loadEventEnd'].forEach(function(k){if(Number.isFinite(e[k]))nav[k]=e[k];});}catch(_){}
    var result={session:session,reason:reason,durationMs:now()-started,supported:types,frames:frames,inputToNextRAF:inputFrame,eventTiming:eventTiming,longTasks:longTasks,resources:resources,resourceKinds:resourceKinds,resourceEntriesDropped:Math.max(0,resourceSeen-4096),pendingInputs:pending.length,inputDropped:inputDropped,navigationMs:nav};
    try{window.webkit.messageHandlers.adPerformance7596.postMessage(result);}catch(_){}
    return result;
  }
  on('pagehide',function(){stop('pagehide');});
  window.__adPerformance7596={session:session,stop:stop};
  timer=setTimeout(function(){stop('deadline');},Math.max(0,deadline-Date.now()));
  raf=requestAnimationFrame(tick);
})(__SESSION__, __DEADLINE__);
