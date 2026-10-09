(function(){try{
'use strict';
var d=document,styleId='ad7613-keep-shopping-for',scope='[data-ad7613-keep-shopping-for="1"]';
var factor=__FACTOR__,tone='brightness('+factor+')';
var s=d.getElementById(styleId);
if(!s){s=d.createElement('style');s.id=styleId;(d.head||d.documentElement).appendChild(s);}
/* Exact local section once identified by its visible title; alternate structural
   owner handles Amazon variants with keep-shopping in authored identifiers.
   No card resizing, new dividers, observers, RAF, or repeated scanning. */
var owners=':is('+scope+',[id*="keep-shopping" i],[class*="keep-shopping" i],[class*="keepShopping"],[data-testid*="keep-shopping" i],[data-csa-c-painter*="keep-shopping" i])';
var css='';
css+=owners+' :is(h1,h2,h3,h4,h5,h6,p,span,div,a,strong,b,small,label):not([class*="prime" i]):not([class*="star" i]):not([class*="badge" i]):not([class*="price" i]):not(.a-color-link):not(:where(.a-color-link *)){color:#fff!important;-webkit-text-fill-color:#fff!important;}';
css+=owners+' :is(.a-color-secondary,.a-color-tertiary,.a-color-base,.a-text-normal,[class*="viewed" i],[class*="subtitle" i],[class*="count" i]){color:#fff!important;-webkit-text-fill-color:#fff!important;}';
css+=owners+' :is([class*="header" i],[class*="title" i]) :is(svg,svg *,i[class*="chevron" i],i[class*="arrow" i]){color:#fff!important;fill:#fff!important;stroke:#fff!important;}';
css+=owners+' :is(img,picture img,canvas){visibility:visible!important;opacity:1!important;mix-blend-mode:normal!important;filter:'+tone+'!important;-webkit-filter:'+tone+'!important;}';
css+=owners+' :is([class*="image-container" i],[class*="image-wrapper" i],[class*="imageContainer"],[class*="imageWrapper"],[class*="thumbnail-container" i]){background-color:transparent!important;}';
css+=owners+' :is([style*="background-image" i],[data-background-image],[class*="background-image" i]):not(:has(img,p,span,a,h1,h2,h3,h4)){visibility:visible!important;opacity:1!important;mix-blend-mode:normal!important;filter:'+tone+'!important;-webkit-filter:'+tone+'!important;}';
s.textContent=css;
var finished=false;
function markKeepShopping(){
 if(finished)return;
 try{
  var heads=d.querySelectorAll('h1,h2,h3,h4,h5,h6,[role="heading"],[class*="header" i],[class*="title" i],.a-text-bold');
  for(var i=0;i<heads.length&&i<750;i++){
   var e=heads[i];if(!e||e.children.length>4)continue;
   var label=(e.textContent||'').replace(/\s+/g,' ').trim();
   if(!/^keep shopping for\s*:?$/i.test(label))continue;
   var target=null,cur=e.parentElement;
   for(var up=0;cur&&up<9;up++,cur=cur.parentElement){
    var r=cur.getBoundingClientRect();
    if(r.width<250||r.height<150||r.height>1160)continue;
    /* Require the caption and its media tiles together; never mark the
       entire main page or any neighboring PDP recommendation carousel. */
    var media=cur.querySelectorAll('img,picture,[style*="background-image" i],[class*="image" i]');
    if(media.length>=3&&media.length<=75){target=cur;break;}
   }
   if(!target)continue;
   target.setAttribute('data-ad7613-keep-shopping-for','1');
   /* An inline image declaration can have been masked by an earlier
      high-priority background shorthand. Reassert only the same authored URL. */
   var pics=target.querySelectorAll('img,picture img');
   for(var k=0;k<pics.length&&k<75;k++){
    var photo=pics[k];
    if(window.getComputedStyle&&window.getComputedStyle(photo).display==='none'&&
       (photo.currentSrc||photo.getAttribute('src')||photo.getAttribute('data-src')))
       photo.style.setProperty('display','block','important');
   }
   var bg=target.querySelectorAll('[style*="background-image" i]');
   for(var j=0;j<bg.length&&j<75;j++){
    var node=bg[j],im=node.style&&node.style.backgroundImage;
    if(im&&im!=='none')node.style.setProperty('background-image',im,'important');
   }
   finished=true;return;
  }
 }catch(_){}
}
if(d.readyState==='loading'){
 d.addEventListener('DOMContentLoaded',markKeepShopping,{once:true});
 if(window&&window.addEventListener)window.addEventListener('load',markKeepShopping,{once:true});
}else{
 markKeepShopping();
 if(d.readyState!=='complete'&&window&&window.addEventListener)window.addEventListener('load',markKeepShopping,{once:true});
}
}catch(_){}})();
