const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const code=fs.readFileSync(__dirname+'/../src/ADKeepShopping7613.js','utf8').replace('__FACTOR__','0.58');
function exercise(withHeading){
  const styles=[],setAttrs=[];
  const image={nodeName:'IMG'};
  const root={parentElement:null,children:[], getBoundingClientRect(){return {width:405,height:570}},
    querySelectorAll(sel){return sel.includes('style*')&&sel.startsWith('[style')?[]:[image,image,image,image,image]},
    setAttribute(k,v){setAttrs.push([k,v]);this[k]=v}};
  const titleRow={parentElement:root,children:[],getBoundingClientRect(){return {width:405,height:70}},querySelectorAll(){return []}};
  const heading={parentElement:titleRow,children:[],textContent:'Keep shopping for'};
  const document={readyState:'complete',getElementById(){return null},createElement(){return {textContent:'',id:''}},head:{appendChild(s){styles.push(s)}},
    querySelectorAll(){return withHeading?[heading]:[]}};
  const context={document,window:{addEventListener(){throw Error('Unexpected scheduling')}},console};
  vm.runInNewContext(code,context,{timeout:1000});
  assert.equal(styles.length,1);
  assert.match(styles[0].textContent,/brightness\(0\.58\)/);
  assert.match(styles[0].textContent,/visibility:visible!important/);
  assert.match(styles[0].textContent,/color:#fff!important/);
  // All styling selectors remain descendants of the explicit marker or authored keeper identifier.
  assert.match(styles[0].textContent,/:is\(\[data-ad7613-keep-shopping-for="1"\]/);
  assert.doesNotMatch(styles[0].textContent,/\],\s*:is\(/);
  assert.deepEqual(setAttrs,withHeading?[['data-ad7613-keep-shopping-for','1']]:[]);
}
exercise(true);exercise(false);
console.log('PASS v7.613: simulated section heading marks local 5-image owner; missing heading remains inert except authored IDs');
