const fs=require('fs'),vm=require('vm'),assert=require('assert');
const root=process.argv[2];
function source(n){return fs.readFileSync(root+'/src/'+n,'utf8').trim().split('\n').map(JSON.parse).join('');}
let id=0;function el(){return {nodeType:1,tagName:'DIV',id:'n'+id++,className:'',attributes:[],firstChild:null,parentElement:null,isConnected:true,scrollTop:0,scrollLeft:0,scrollHeight:100,scrollWidth:430,clientHeight:100,clientWidth:430,hasAttribute:()=>false,getAttribute:()=>'',getBoundingClientRect:()=>({x:0,y:0,top:0,left:0,right:430,bottom:100,width:430,height:100}),scrollTo(p){this.scrollTop=Math.max(0,Math.min(p.top,this.scrollHeight-this.clientHeight));this.scrollLeft=p.left;}};}
let elements=Array.from({length:400},el),html=elements[0],inner=elements[10];html.scrollHeight=5000;html.clientHeight=800;html.scrollTop=122;inner.scrollHeight=2400;inner.clientHeight=500;inner.scrollTop=77;elements.forEach(e=>Object.defineProperty(e,'textContent',{get(){throw Error('subtree text read');}}));
let tasks=[],messages=[],listener;
const context={document:{documentElement:html,scrollingElement:html,body:html,readyState:'complete',referrer:'',querySelectorAll:()=>[],querySelector:()=>null,elementsFromPoint:()=>[],createTreeWalker(){let i=0;return {nextNode:()=>elements[++i]||null};}},location:{pathname:'/dp/x',origin:'https://example.test'},getComputedStyle(e){return {display:'block',visibility:'visible',opacity:'1',overflowY:e===inner?'auto':'visible',overflowX:'visible',backgroundColor:'rgb(0, 0, 0)',color:'rgb(255, 255, 255)'};},performance:{timeOrigin:1},setTimeout(f){tasks.push(f);},console};
context.window=context;context.innerWidth=430;context.innerHeight=800;context.addEventListener=(name,f)=>{listener=f;};context.webkit={messageHandlers:{adUniversalUI7433:{postMessage:m=>messages.push(m)}}};vm.createContext(context);

elements[399].getBoundingClientRect=()=>({x:0,y:9000,left:0,top:9000,right:100,bottom:9100,width:100,height:100});
context.document.getElementById=()=>null;
context.__adPDPStreamNonce7451='test';context.__adPDPStreamCapture7451='run';
const code=source('ADPDPMainStream7451.js.inc');
const saved=context.webkit;delete context.webkit;
assert.equal(vm.runInContext(code,context),'pdp-stream-bridge-unavailable');assert.equal(tasks.length,0);
context.webkit=saved;
assert.equal(vm.runInContext(code,context),'pdp-stream-started');
assert.equal(messages.length,0,'start must return before rich traversal');
let iterations=0;while(tasks.length){tasks.shift()();assert(++iterations<500);}
let groups={};messages.forEach(m=>{(groups[m.captureId] ||= [])[m.seq]=m.payload;});
let payloads=Object.values(groups).map(chunks=>JSON.parse(chunks.join('')));
assert.equal(payloads.reduce((n,p)=>n+p.nodes.length,0),400);
assert.equal(payloads.at(-1).more,false);assert.equal(payloads.at(-1).counts.truncated,false);
assert(payloads.some(p=>p.nodes.some(n=>n.rect.y>800)),'offscreen nodes must be captured');
assert.equal(html.scrollTop,122);assert.equal(inner.scrollTop,77);
// Same full inventory for PDP, without mutating either scroll owner.
context.document.getElementById=()=>html;messages=[];
vm.runInContext(code,context);while(tasks.length)tasks.shift()();
assert(messages.some(m=>m.payload.includes('"routeClass":"pdp"')));
assert.equal(html.scrollTop,122);
// Expired diagnostic stops page work and reports a terminal partial batch.
messages=[];vm.runInContext(code,context);context.__adPDPStreamState7451.deadline=0;
while(tasks.length)tasks.shift()();
assert(messages.some(m=>m.payload.includes('"reason":"deadline"')));
console.log('PASS: missing bridge, full offscreen inventory on both routes, yielding, no offset mutation, deadline');
