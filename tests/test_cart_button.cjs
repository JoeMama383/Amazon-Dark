// Render the actual shipped ADFloorJS against a captured Cart fixture.
// This test uses the raw Amazon-like fixture as the geometry/paint baseline so it
// does not depend on a historical source-reconstruction helper.
const fs=require('node:fs'),path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const modules=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const pw=require(modules?path.join(modules,'playwright'):'playwright');
const current=fs.readFileSync(path.join(root,'src/Tweak.xm'),'utf8');
function payload(source){
    const start=source.indexOf('static NSString *ADFloorJS(void){');
    const end=source.indexOf('// v7.191: cache the large strength-dependent TWB payloads.');
    assert(start>=0&&end>start,'ADFloorJS bounds');
    const area=source.slice(start,end);
    return [...area.matchAll(/@"((?:\\.|[^"\\])*)"/g)].map(m=>JSON.parse('"'+m[1]+'"')).join('');
}
const button=(id,primary=false)=>`<span id="${id}" class="a-button ${primary?'a-button-primary':'a-button-base'} a-button-small aok-inline-block"><span class="a-button-inner"><a class="a-button-text a-text-center">${primary?'Add to cart':'See all buying options'}</a></span></span>`;
const html=`<!doctype html><style>
body{margin:0;background:black;color:white}
.a-button{box-sizing:border-box;display:inline-block;width:150px;height:52px;border:1px solid rgb(136,140,140);border-radius:100px;background:white;color:rgb(15,17,17)}
.a-button-primary{background:#ffd814}
.a-button-inner{display:block;height:50px;border-radius:2px;background:transparent}
.a-button-text{display:block;font:16px Arial;text-align:center;color:rgb(15,17,17);padding:6px 10px}
#sc-recs-atf-shimmer-placeholder{border-top:13px solid rgb(234,237,237);background:#fff}
.sc-rec-card-shimmer{width:127px;height:250px;background:#fff}
.sc-rec-card-image-shimmer{width:100px;height:100px;background-image:url(data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='100'%20height='100'%3E%3Crect%20width='100'%20height='100'%20fill='white'/%3E%3C/svg%3E);background-color:#eee}
.a-loading-static-inner{width:50px;height:50px;background:transparent url(data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='50'%20height='50'%3E%3Cpath%20d='M5%2045L25%205L45%2045Z'%20fill='black'/%3E%3C/svg%3E)}
</style>
<div id="sc-page-container"><div id="p13n-uf-anchor"><div class="p13n-sc-uncoverable-faceout"><div class="p13n-sc-sunk-container"><div class="a-section a-spacing-base">${button('buying')}${button('primary',true)}</div></div></div>
<div class="a-loading-static"><div id="artwork" class="a-loading-static-inner"></div></div></div>
<div class="sc-item-actions">${button('item-action')}</div>
<div id="sc-recs-atf-shimmer-placeholder" class="sc-recs-section-shimmer"><div id="skeleton" class="sc-rec-card-shimmer"><div id="image-shimmer" class="sc-rec-card-image-shimmer"></div></div></div></div>
<div id="outside-cart">${button('outside-cart-button')}</div>`;
async function state(page){return page.evaluate(()=>{
    const read=e=>{const c=getComputedStyle(e),r=e.getBoundingClientRect();return {
        bg:c.backgroundColor,image:c.backgroundImage,color:c.color,textFill:c.webkitTextFillColor,
        border:c.borderTopColor,borderWidth:c.borderTopWidth,shadow:c.boxShadow,filter:c.filter,
        width:r.width,height:r.height,radius:c.borderRadius,padding:c.padding,opacity:c.opacity};};
    const selectors=['#buying','#buying>.a-button-inner','#buying .a-button-text','#primary',
        '#item-action','#outside-cart-button','#sc-recs-atf-shimmer-placeholder','#skeleton','#image-shimmer','#artwork'];
    return Object.fromEntries(selectors.map(s=>[s,read(document.querySelector(s))]));
});}
async function run(){
    const browser=await pw[process.env.AD_PROBE_BROWSER||'webkit'].launch({headless:true,
        ...(process.env.AD_PROBE_BROWSER_PATH?{executablePath:process.env.AD_PROBE_BROWSER_PATH}:{}),
        ...(process.env.AD_PROBE_BROWSER==='chromium'?{args:['--no-sandbox','--disable-gpu','--disable-dev-shm-usage']}:{}),});
    try{
        const page=await browser.newPage({viewport:{width:430,height:932}});
        await page.route('https://www.amazon.com/**',r=>r.fulfill({contentType:'text/html',body:html}));
        await page.goto('https://www.amazon.com/gp/cart/view.html');
        const before=await state(page);
        assert.equal(before['#buying'].bg,'rgb(255, 255, 255)','Fixture must reproduce stock white buying-options button');
        assert.equal(before['#sc-recs-atf-shimmer-placeholder'].border,'rgb(234, 237, 237)','Fixture must reproduce stock Cart strip');
        assert.equal(before['#sc-recs-atf-shimmer-placeholder'].borderWidth,'13px');
        assert.notEqual(before['#artwork'].image,'none','Fixture must carry authored loader artwork');
        assert.notEqual(before['#image-shimmer'].image,'none','Fixture must carry authored shimmer artwork');
        await page.evaluate(payload(current));
        const after=await state(page);
        assert.equal(after['#buying'].bg,'rgb(0, 0, 0)');
        assert.equal(after['#buying'].border,'rgb(116, 122, 124)');
        assert.equal(after['#buying .a-button-text'].color,'rgb(232, 230, 227)');
        assert.equal(after['#buying>.a-button-inner'].bg,'rgba(0, 0, 0, 0)');
        for(const s of ['#buying','#buying>.a-button-inner','#buying .a-button-text'])
            for(const p of ['width','height','radius','padding','borderWidth'])assert.equal(after[s][p],before[s][p],s+' '+p);
        assert.equal(after['#sc-recs-atf-shimmer-placeholder'].border,'rgb(0, 0, 0)');
        assert.equal(after['#sc-recs-atf-shimmer-placeholder'].borderWidth,before['#sc-recs-atf-shimmer-placeholder'].borderWidth);
        assert.notEqual(after['#artwork'].image,'none','Legacy authored loader artwork must survive');
        assert.equal(after['#artwork'].image,before['#artwork'].image,'Legacy loader artwork URL must be preserved');
        assert.notEqual(after['#image-shimmer'].image,'none','Current image-shimmer artwork must survive');
        assert.equal(after['#image-shimmer'].image,before['#image-shimmer'].image,'Current shimmer artwork URL must be preserved');
        assert.equal(after['#outside-cart-button'].bg,before['#outside-cart-button'].bg,'Cart selectors must remain scoped');
        await page.addStyleTag({content:'.a-button-base{background:white;color:black}.a-button-inner{background:white}.a-button-text{color:black}#sc-recs-atf-shimmer-placeholder{border-top-color:rgb(234,237,237)}'});
        const late=await state(page);
        assert.equal(late['#buying'].bg,'rgb(0, 0, 0)');
        assert.equal(late['#buying .a-button-text'].color,'rgb(232, 230, 227)');
        assert.equal(late['#sc-recs-atf-shimmer-placeholder'].border,'rgb(0, 0, 0)');
        console.log('PASS: current ADFloorJS fixes Cart buying-options paint and exact 13px shimmer strip');
        console.log('PASS: button geometry and authored loader/image-shimmer background images are preserved');
        console.log('PASS: late Amazon-style rules cannot restore the accepted white button/strip regression');
    }finally{await browser.close();}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
