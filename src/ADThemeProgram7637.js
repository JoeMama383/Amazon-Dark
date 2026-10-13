/* Only AmazonDark-authored calls are wrapped. No browser/app monkey-patching. */
(function(){
  var slot=__SLOT__, serial=0, probe=window.__adThemeWork7637;
  function ad7637Listen(target,type,callback,options){
    var index=++serial;
    if(!probe||typeof callback!=='function')return target.addEventListener(type,callback,options);
    // Keep once/passive/capture/this/event/return/throw behavior. These programs
    // have no removeEventListener calls; a source test enforces that constraint.
    var name='s'+slot+'/'+type+'#'+index+'/'+(callback.name||'anonymous');
    return target.addEventListener(type,function(){
      var p=window.__adThemeWork7637;
      if(!p)return callback.apply(this,arguments);
      return p.run(name,callback,this,arguments);
    },options);
  }
  function ad7637Computed(){
    var p=window.__adThemeWork7637,t=p&&p.begin('s'+slot+'/computed-style');
    try{return window.getComputedStyle.apply(window,arguments);}
    finally{if(p)p.end(t);}
  }
  var token=probe&&probe.begin('s'+slot+'/install');
  try{
__PROGRAM__
  }finally{if(probe)probe.end(token);}
})();
