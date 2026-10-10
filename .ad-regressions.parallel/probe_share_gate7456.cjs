const fs=require('fs'),vm=require('vm'),assert=require('assert');
const R=process.argv[2],decode=n=>fs.readFileSync(R+'/src/'+n,'utf8').trim().split('\n').map(JSON.parse).join('');
const gate=decode('ADPDPShareGate7456.js.inc'),walk=decode('ADUIProbeScroll7446.js.inc');
function fixture(){
 let now=0,locked=false,active=false,clicks=0,removed=0,other=false,closeWorks=true,missing=false;
 const page={classList:{contains:()=>locked},scrollHeight:14405};
 const root={isConnected:true,tagName:'HTML',clientWidth:430,clientHeight:779,scrollWidth:430,scrollLeft:0,scrollTop:2424,get scrollHeight(){return locked?779:14405;}};
 const button={disabled:false,click(){clicks++;if(closeWorks){locked=false;active=false;}}};
 const sheet={querySelector:s=>s.includes('ssf-customize')?{}:s==='button.a-sheet-close'&&!missing?button:null};
 const alien={querySelector:s=>s==='.a-sheet-web'?{}:null};
 const c={Date:{now:()=>now},document:{hidden:false,body:{},documentElement:root,scrollingElement:root,getElementById:id=>id==='dp'?{}:id==='a-page'?page:id==='ad7403-share-probe-suppress'&&!removed?{remove(){removed++;}}:null,querySelectorAll:()=>other?[alien]:active?[sheet]:[],getElementsByTagName:()=>Array(7190)},innerWidth:430,innerHeight:813,__adPDPGateNonce7456:'one',__adUIProbeScrollOwners7449:[]};c.window=c;vm.createContext(c);
 return {c,root,page,gate:()=>vm.runInContext(gate,c),walk(cmd){c.__adUIWalkCommand7449=cmd;return vm.runInContext(walk,c);},tick(ms){now+=ms;},open(){locked=true;active=true;},other(){other=true;locked=true;},breakClose(){closeWorks=false;},missing(){missing=true;},get clicks(){return clicks;},get removed(){return removed;},get locked(){return locked;}};
}
// Reproduce five captured failures: full product remains tall while locked root becomes 779.
{
 const f=fixture();assert(!f.gate().ready);f.tick(500);f.open();assert.equal(f.root.scrollHeight,779);assert.equal(f.page.scrollHeight,14405);
 assert.equal(f.walk('initroot').error,'pdp-modal-locked');assert.equal(f.root.scrollTop,2424,'blocked init must not reset scroll');
 assert.equal(f.gate().reason,'stock-share-close');assert.equal(f.clicks,1);assert.equal(f.removed,1);assert(!f.locked);
 f.tick(1500);assert(f.gate().ready);assert.equal(f.walk('initroot').y,0);
 for(let y=600;y<15000;y+=600)assert(!f.walk(y).error);
 assert.equal(f.walk('coverage').unvisitedOwners,0);assert(f.walk('next').done);f.walk('restore');assert.equal(f.root.scrollTop,2424);
}
// Modal can arrive after preflight. Same gate repairs it, without resetting traversal.
{
 const f=fixture();f.gate();f.tick(1600);assert(f.gate().ready);f.walk('initroot');f.walk(600);f.open();
 assert.equal(f.walk(1200).error,'pdp-modal-locked');assert.equal(f.root.scrollTop,600);f.gate();f.tick(700);assert(f.gate().ready);assert.equal(f.walk(1200).y,1200);f.walk('restore');
}
// Unrelated sheets, absent/broken close handlers, backgrounding and stale sessions are not success.
{
 const f=fixture();f.other();assert.equal(f.gate().error,'other-modal-open');assert.equal(f.clicks,0);assert(f.locked);
}
{
 const f=fixture();f.open();f.missing();assert.equal(f.gate().error,'share-close-unavailable');assert.equal(f.removed,1);assert(f.locked);
}
{
 const f=fixture();f.open();f.breakClose();for(let i=0;i<8;i++){f.gate();f.tick(1000);}assert.equal(f.clicks,3);assert.equal(f.gate().error,'share-unlock-timeout');assert(f.locked);
 assert.equal(f.walk('restore').skipped,1,'do not jump behind an unresolved modal');
}
{
 const f=fixture();f.gate();f.tick(1500);assert(f.gate().ready);f.c.__adPDPGateNonce7456='two';assert(!f.gate().ready);f.c.document.hidden=true;assert.equal(f.gate().error,'document-backgrounded');
}
console.log('PASS: PDP modal-lock reproduction, automatic full traversal after stock close, late modal recovery, safe failure, session reset');
