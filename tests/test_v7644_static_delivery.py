"""Owned sheets avoid Amazon DOM mutations; isolation append and fallback work."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
helper = (root / 'src/ADRenderScope7640.js').read_text()
isolation = (root / 'src/ADStartupIsolation7643.js').read_text()
js = r'''
const vm=require('vm'),assert=require('assert');
function setup(mode=0){
 let calls=0,mutations=0;
 class Sheet {replaceSync(css){this.css=css;calls++;}}
 const c={location:{pathname:'/s'},CSSStyleSheet:Sheet,
 performance:{now:()=>0},Date:{now:()=>0},document:{readyState:'loading',styleSheets:[],adoptedStyleSheets:[],
 createDocumentFragment:()=>({empty:true}),createElement:()=>({remove(){}}),
 head:{appendChild(){mutations++}},getElementById:()=>null}};
 c.window=c;c.top=c;vm.createContext(c);vm.runInContext(SOURCE,c);vm.runInContext(ISOLATION,c);
 if(mode){const i=c.ad7643StartupIsolation(mode,100);c.__adThemeWork7637={style:i.style,styleText:i.styleText};c.isolation=i;}
 return {c,counts:()=>({calls,mutations})};
}
const f=setup(),c=f.c,s={id:'ad7-menu-theme',tagName:'STYLE',textContent:''};
assert(c.ad7644AppendStyle(s).empty);
c.ad7640Style(s).textContent='body{color:white}';
assert.equal(c.document.adoptedStyleSheets.length,1);
const first=c.document.adoptedStyleSheets[0],before=f.counts().calls;
c.ad7640Style(s).textContent='body{color:white}';assert.equal(f.counts().calls,before);
c.ad7640Style(s).textContent+='body{background:black}';assert.equal(first.css,'body{color:white}body{background:black}');
assert.equal(f.counts().mutations,0);
const replacement={id:s.id,tagName:'STYLE',textContent:'body{color:white}'};
assert(c.ad7644AppendStyle(replacement).empty);assert.equal(c.document.adoptedStyleSheets.length,1);
assert.equal(c.__ad7644StaticSheets.entries.length,1);
const app={id:'amazon-owned',tagName:'STYLE'};assert.equal(c.ad7644AppendStyle(app),app);
c.location.pathname='/';assert.equal(c.ad7644AppendStyle(s),s);
const f2=setup(1),d=f2.c,t={id:'ad7-menu-theme',tagName:'STYLE',textContent:''};
d.ad7644AppendStyle(t);d.ad7640Style(t).textContent='body{color:white}';
d.ad7640Style(t).textContent+='body{background:black}';
assert.equal(t.textContent,'');assert.equal(d.document.adoptedStyleSheets.length,0);
assert.equal(d.ad7640Style(t).textContent,'body{color:white}body{background:black}');
d.isolation.restore(0,0);assert.equal(d.document.adoptedStyleSheets[0].css,'body{color:white}body{background:black}');
assert.equal(d.isolation.snapshot().isolationFailures,0);
// Restoring an earlier withheld sheet must not change the owned cascade order
// or the relative order of Amazon's existing sheets.
const f4=setup(),h=f4.c,amazon1={app:1},amazon2={app:2};
h.document.adoptedStyleSheets=[amazon1];
const ordered=[1,2,3].map(n=>({id:'ad7-order-'+n,tagName:'STYLE',textContent:''}));
ordered.forEach(node=>h.ad7644AppendStyle(node));
h.ad7640Style(ordered[2]).textContent='body{color:blue}';
h.document.adoptedStyleSheets=h.document.adoptedStyleSheets.concat(amazon2);
h.ad7640Style(ordered[1]).textContent='body{color:red}';
h.ad7640Style(ordered[0]).textContent='body{color:white}';
assert.deepEqual(h.document.adoptedStyleSheets,[amazon1,...h.__ad7644StaticSheets.entries.map(x=>x.sheet),amazon2]);
assert.equal(f4.counts().mutations,0);
const f3=setup(),e=f3.c;e.CSSStyleSheet.prototype.replaceSync=function(){throw Error('unavailable')};
const fallback={id:'ad7-fallback',tagName:'STYLE',textContent:'body{color:white}'};
assert.equal(e.ad7644UpdateStyle(fallback,true),false);
delete e.CSSStyleSheet.prototype.replaceSync;assert.equal(e.ad7644SheetRegistry(),null);
console.log('PASS: constructed delivery, no live DOM changes, duplicate suppression, append/restore in original order, route and capability fallback');
'''.replace('SOURCE',json.dumps(helper)).replace('ISOLATION',json.dumps(isolation))
subprocess.run(['node'],input=js,text=True,check=True)
