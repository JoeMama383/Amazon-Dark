// Render the actual shipped ADFloorJS against the captured Cart button owner.
// Compare with the exact v7.344 payload, verified by the full-source baseline test.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const modules=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const pw=require(modules?path.join(modules,'playwright'):'playwright');
const current=fs.readFileSync(path.join(root,'src/Tweak.xm'),'utf8');
const baseline=cp.execFileSync('python3',['-c',
    'import runpy,pathlib; r=pathlib.Path.cwd(); m=runpy.run_path(str(r/"tests/test_cold_launch_policy.py")); print(m["without_cart_changes"]((r/"src/Tweak.xm").read_text()),end="")'],
    {cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
const manifest=JSON.parse(fs.readFileSync(path.join(root,'SOURCE-BASELINE.json'),'utf8'));
assert.equal(require('node:crypto').createHash('sha256').update(baseline).digest('hex'),manifest.baseline_sha256['src/Tweak.xm']);
function payload(source){
    const area=source.slice(source.indexOf('static NSString *ADFloorJS(void){'),
        source.indexOf('// v7.191: cache the large strength-dependent TWB payloads.'));
    return [...area.matchAll(/@"((?:\\.|[^"\\])*)"/g)].map(m=>JSON.parse('"'+m[1]+'"')).join('');
}
const button=(id,primary=false)=>`<span id="${id}" class="a-button ${primary?'a-button-primary':'a-button-base'} a-button-small aok-inline-block"><span class="a-button-inner"><a class="a-button-text a-text-center">${primary?'Add to cart':'See all buying options'}</a></span></span>`;
const html=`<!doctype html><style>
body{margin:0;background:black;color:white}
.a-button{box-sizing:border-box;display:inline-block;width:150px;height:52px;border:1px solid rgb(136,140,140);border-radius:100px;background:white;color:rgb(15,17,17)}
.a-button-primary{background:#ffd814}
.a-button-inner{display:block;height:50px;border-radius:2px;background:transparent}
.a-button-text{display:block;font:16px Arial;text-align:center;color:rgb(15,17,17);padding:6px 10px}
.gwm-window-skeleton{width:280px;height:400px;background:white}
.SkeletonAnimation{height:80px;background:linear-gradient(90deg,#ccc,#999)}
.a-loading-static-inner{width:50px;height:50px;background:transparent url(data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='50'%20height='50'%3E%3Cpath%20d='M5%2045L25%205L45%2045Z'%20fill='black'/%3E%3C/svg%3E)}
</style><div id="gwm-window"><div id="hero" class="gwm-window-tile gwm-window-skeleton"><div class="SkeletonAnimation"></div></div></div>
<div id="sc-page-container"><div id="p13n-uf-anchor"><div class="p13n-sc-uncoverable-faceout"><div class="p13n-sc-sunk-container"><div class="a-section a-spacing-base">${button('buying')}${button('primary',true)}</div></div></div>
<div id="other-owner">${button('outside-owner')}</div><div class="a-loading-static"><div id="artwork" class="a-loading-static-inner"></div></div></div>
<div class="sc-item-actions">${button('item-action')}</div>
<div id="sc-recs-atf-shimmer-placeholder" class="sc-recs-section-shimmer"><div id="skeleton" class="sc-rec-card-shimmer"><div class="sc-rec-card-image-shimmer"></div></div></div></div>
<div id="outside-cart">${button('outside-cart-button')}</div>`;
async function state(page){return page.evaluate(()=>{
    const read=e=>{const c=getComputedStyle(e),r=e.getBoundingClientRect();return {
        bg:c.backgroundColor,image:c.backgroundImage,color:c.color,textFill:c.webkitTextFillColor,
        border:c.borderTopColor,borderWidth:c.borderTopWidth,shadow:c.boxShadow,filter:c.filter,
        width:r.width,height:r.height,radius:c.borderRadius,padding:c.padding,opacity:c.opacity};};
    const selectors=['#buying','#buying>.a-button-inner','#buying .a-button-text','#primary',
        '#outside-owner','#item-action','#outside-cart-button','#hero','#artwork','#skeleton'];
    return Object.fromEntries(selectors.map(s=>[s,read(document.querySelector(s))]));
});}
async function run(){
    const browser=await pw[process.env.AD_PROBE_BROWSER||'webkit'].launch({headless:true,
        ...(process.env.AD_PROBE_BROWSER_PATH?{executablePath:process.env.AD_PROBE_BROWSER_PATH}:{}),
        ...(process.env.AD_PROBE_BROWSER==='chromium'?{args:['--no-sandbox','--disable-gpu','--disable-dev-shm-usage']}:{}),});
    try{
        const result=[];
        for(const text of [baseline,current]){
            const page=await browser.newPage({viewport:{width:430,height:932}});
            await page.route('https://www.amazon.com/**',r=>r.fulfill({contentType:'text/html',body:html}));
            await page.goto('https://www.amazon.com/gp/cart/view.html');
            await page.evaluate(payload(text));
            result.push({page,paint:await state(page)});
        }
        const a=result[0].paint,b=result[1].paint;
        assert.equal(a['#buying'].bg,'rgb(255, 255, 255)','Fixture must reproduce v7.344 white button');
        assert.equal(b['#buying'].bg,'rgb(0, 0, 0)');
        assert.equal(b['#buying'].border,'rgb(116, 122, 124)');
        assert.equal(b['#buying .a-button-text'].color,'rgb(232, 230, 227)');
        assert.equal(b['#buying>.a-button-inner'].bg,'rgba(0, 0, 0, 0)');
        for(const s of ['#buying','#buying>.a-button-inner','#buying .a-button-text'])
            for(const p of ['width','height','radius','padding','borderWidth'])assert.equal(b[s][p],a[s][p],s+' '+p);
        for(const s of Object.keys(a).filter(s=>!s.startsWith('#buying')))assert.deepEqual(b[s],a[s],s);
        await result[1].page.addStyleTag({content:'.a-button-base{background:white;color:black}.a-button-inner{background:white}.a-button-text{color:black}'});
        const late=await state(result[1].page);
        assert.equal(late['#buying'].bg,'rgb(0, 0, 0)');
        assert.equal(late['#buying .a-button-text'].color,'rgb(232, 230, 227)');
        console.log('PASS: actual v7.344 white button reproduces; v7.346 paints OLED black with matching border/text');
        console.log('PASS: dimensions, pill/inner radius and padding unchanged; primary/item/other buttons, skeleton and artwork equal v7.344');
        console.log('PASS: late Amazon-style rules cannot restore white buying-options paint');
    }finally{await browser.close();}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
