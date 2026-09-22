const fs=require('fs'),vm=require('vm'),assert=require('assert');
const R=process.argv[2];
const code=fs.readFileSync(R+'/src/ADUIProbeScroll7446.js.inc','utf8').trim().split('\n').map(JSON.parse).join('');
function fixture(pdp=false,fixed=false){
 function element(h,ch,w=430){return {isConnected:true,tagName:'DIV',scrollHeight:h,clientHeight:ch,scrollWidth:w,clientWidth:w,scrollLeft:0,scrollTop:90,getBoundingClientRect:()=>({width:w,height:ch,top:0,bottom:ch})};}
 const root=element(fixed?800:6000,800),inner=element(3000,600),horizontal=element(100,100);horizontal.scrollWidth=2000;
 const c={document:{scrollingElement:root,documentElement:root,hidden:false,getElementsByTagName:()=>Array(50),getElementById:()=>pdp?root:null},innerWidth:430,innerHeight:800,__adUIProbeScrollOwners7449:[root,inner,horizontal]};c.window=c;
 vm.createContext(c);return {c,root,inner,cmd(x){c.__adUIWalkCommand7449=x;return vm.runInContext(code,c);}};
}
for(const pdp of [false,true]){
 const f=fixture(pdp);assert.equal(f.cmd('initroot').y,0);
 for(let y=600;y<=5400;y+=600)assert(!f.cmd(y).error);
 assert(f.cmd('next').done);assert.equal(f.root.scrollTop,5200,'root stays in place through final inventory');
 assert.equal(f.cmd('initowners').total,1,'ignore horizontal owner');
 assert.equal(f.cmd(2400).y,2400);assert(f.cmd('next').done);
 assert.equal(f.cmd('coverage').unvisitedOwners,0);
 f.root.scrollHeight+=1000;assert.equal(f.cmd('coverage').unvisitedOwners,1,'growth must not be reported complete');
 const r=f.cmd('restore');assert.equal(r.restored,2);assert.equal(f.root.scrollTop,90);assert.equal(f.inner.scrollTop,90);
 assert.equal(f.cmd('restore').restored,0,'restore is idempotent');
}
{
 const f=fixture(true,true);assert.equal(f.cmd('initroot').max,2400,'fixed shell uses actual scroll owner');f.cmd(600);assert.equal(f.inner.scrollTop,600);f.cmd('restore');assert.equal(f.inner.scrollTop,90);
}
{
 const f=fixture(true);f.cmd('initroot');f.cmd(1200);f.root.scrollHeight=800;
 assert.equal(f.cmd('read').error,'renderer-height-collapse');assert.equal(f.cmd('restore').skipped,1,'never jump into collapsed renderer');
}
{
 const f=fixture();f.cmd('initroot');f.c.document.hidden=true;assert.equal(f.cmd(1000).error,'document-backgrounded');assert.equal(f.root.scrollTop,0);f.cmd('restore');
}
{
 const f=fixture();f.cmd('initroot');f.root.isConnected=false;assert.equal(f.cmd(1000).error,'scroll-owner-detached');assert.equal(f.cmd('restore').skipped,1);
}
console.log('PASS: universal PDP/search walk, real overflow owner, lazy growth accounting, single restore, collapse/background/detachment guards');
