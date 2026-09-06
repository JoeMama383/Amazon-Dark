// Execute the shipped JS in a real browser. WK injection/physical iPhone painting
// still require device validation. Uses Playwright WebKit by default.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const pkg = process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const pw = require(pkg ? path.join(pkg, 'playwright') : 'playwright');
const engine = process.env.AD_PROBE_BROWSER || 'webkit';
const raw = fs.readFileSync(path.join(root,'src/ADSkeletonProbe7339.js.inc'),'utf8');
const code = raw.match(/^R"AD7339JS\(\n([\s\S]*)\n\)AD7339JS"\s*$/)[1];

async function server() {
    const s=http.createServer((req,res)=>{
        res.setHeader('Content-Type','text/html');
        res.end('<!doctype html><html><head><style>body{background:#000;color:#fff;margin:0}'+
            '#sc-saved-cart{height:0;border-top:13px solid white;border-bottom:13px solid white}'+
            ':is(#sc-saved-cart,.absent)::before{content:"";background:white}'+
            '.hero-skeleton{width:230px;height:300px;background:white}'+
            '.shimmer{width:90%;height:45px;background:linear-gradient(90deg,#ccc,#aaa)}'+
            '</style></head><body><div id="sc-saved-cart"></div>'+ 
            '<div class="hero-skeleton"><div class="shimmer"></div></div>'+ 
            '<div>PRIVATE-ACCOUNT-TEXT</div><input value="PRIVATE-INPUT">'+
            '</body></html>');
    });
    await new Promise(resolve=>s.listen(0,'127.0.0.1',resolve));
    return {s,url:`http://127.0.0.1:${s.address().port}`};
}
async function run() {
    const a=await server(), b=await server();
    let browser;
    const logs=[], errors=[];
    try {
        browser=await pw[engine].launch({headless:true,
            ...(process.env.AD_PROBE_BROWSER_PATH ? {executablePath:process.env.AD_PROBE_BROWSER_PATH} : {})});
        const context=await browser.newContext({viewport:{width:430,height:932}});
        await context.exposeBinding('adCapture',(_source,s)=>logs.push(...JSON.parse(s).events));
        await context.addInitScript({content:`window.webkit={messageHandlers:{adSkeleton7339:{postMessage:s=>window.adCapture(s)}}};`+
            code.replace('__AD_CONFIG__',JSON.stringify({session:'fixture',until:Date.now()+15000}))});
        const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
        await page.goto(a.url);
        await page.waitForTimeout(180);
        assert.equal(await page.locator('.hero-skeleton').evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(255, 255, 255)');
        await page.evaluate(async url=>{
            // White for one rendered frame, then hydrated/black. No screenshot trigger.
            const x=document.createElement('div');x.id='single-frame-skeleton';
            Object.assign(x.style,{position:'fixed',top:'60px',left:'10px',width:'180px',height:'180px',background:'white'});
            document.body.appendChild(x);
            await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
            x.style.background='black';
            const host=document.createElement('div');document.body.appendChild(host);
            const shadow=host.attachShadow({mode:'open'});
            shadow.innerHTML='<div id="shadow-skeleton" style="position:fixed;left:0;top:330px;width:120px;height:40px;background:white"></div>';
            const frame=document.createElement('iframe');frame.src=url;frame.width='260';frame.height='380';document.body.appendChild(frame);
        },b.url);
        await page.waitForTimeout(650);
        const white=logs.find(e=>e.event==='NODE'&&e.id==='single-frame-skeleton'&&e.paint['background-color']==='rgb(255, 255, 255)');
        const black=logs.find(e=>e.event==='NODE'&&e.id==='single-frame-skeleton'&&e.paint['background-color']==='rgb(0, 0, 0)');
        assert(white&&black&&white.epoch<=black.epoch,'short-lived white and hydrated states captured');
        assert(logs.some(e=>e.event==='NODE'&&e.id==='sc-saved-cart'&&e.paint['border-top-width']==='13px'));
        assert(logs.some(e=>e.event==='NODE'&&e.cls==='shimmer'&&e.paint['background-image'].includes('linear-gradient')));
        assert(logs.some(e=>e.event==='NODE'&&e.id==='shadow-skeleton'),'open shadow owner captured');
        assert(logs.some(e=>e.event==='FRAME_START'&&!e.main),'cross-origin child instrumented');
        assert(logs.some(e=>e.event==='RULES'&&e.matchedDeclarations.some(r=>r.selector.includes('sc-saved-cart'))));
        assert(logs.some(e=>e.event==='RULES'&&e.matchedDeclarations.some(r=>r.selector.includes(':is('))));
        const text=JSON.stringify(logs);
        assert(!text.includes('PRIVATE-ACCOUNT-TEXT')&&!text.includes('PRIVATE-INPUT')&&!text.includes(a.url));
        assert.equal(await page.evaluate(()=>scrollY),0,'no probe scrolling');
        // Test the actual registered back-forward event handlers while the bridge
        // still has a live page. Playwright's asynchronous binding may discard an
        // unload message after destroying its context; WK delivery is device QA.
        await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pagehide',{persisted:true})));
        await page.waitForTimeout(30);assert(logs.some(e=>e.event==='FRAME_PAUSE'));
        await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
        await page.waitForTimeout(30);assert(logs.some(e=>e.event==='FRAME_RESUME'));
        await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pagehide',{persisted:false})));
        await page.waitForTimeout(30);assert(logs.some(e=>e.event==='FRAME_END'&&e.reason==='pagehide'));
        const docs=new Set(logs.filter(e=>e.event==='FRAME_START').map(e=>e.doc));
        await page.goto(a.url+'/next');await page.waitForTimeout(150);
        assert(logs.some(e=>e.event==='FRAME_START'&&!docs.has(e.doc)),'new navigation starts capture');
        assert.equal(errors.length,0,errors.join('\n'));
        console.log('PASS: actual probe captures document-start, one-frame white/black, border strip, gradient, open shadow, cross-origin frame, rules and navigation cleanup');
        console.log('PASS: observed UI remains unchanged; no text/input/URL values in log');
        console.log('Fixture observation max milliseconds:',Math.max(...logs.filter(e=>e.event==='HEARTBEAT').map(e=>e.maxMS),0));
        await context.close();

        const exp=await browser.newContext(), ended=[];
        await exp.exposeBinding('adCapture',(_s,t)=>ended.push(...JSON.parse(t).events));
        const expPage=await exp.newPage();await expPage.goto(a.url);
        await expPage.evaluate(source=>{
            window.webkit={messageHandlers:{adSkeleton7339:{postMessage:s=>window.adCapture(s)}}};
            (0,eval)(source);
        },code.replace('__AD_CONFIG__',JSON.stringify({session:'expiry',until:Date.now()+450})));
        await expPage.waitForTimeout(700);
        assert(ended.some(e=>e.event==='FRAME_END'&&e.reason==='expiry'));
        const count=ended.length;
        await expPage.evaluate(()=>document.body.innerHTML='<div class="skeleton" style="background:white;width:200px;height:200px"></div>');
        await expPage.waitForTimeout(120);assert.equal(ended.length,count,'no work after expiry');
        await exp.close();
        const inactive=await browser.newContext();const none=[];
        await inactive.exposeBinding('adCapture',(_s,t)=>none.push(t));
        await inactive.addInitScript({content:`window.webkit={messageHandlers:{adSkeleton7339:{postMessage:s=>window.adCapture(s)}}};`+
            code.replace('__AD_CONFIG__',JSON.stringify({session:'expired',until:Date.now()-1}))});
        const ip=await inactive.newPage();await ip.goto(a.url);await ip.waitForTimeout(150);
        assert.equal(none.length,0,'expired script is dormant');await inactive.close();
        console.log('PASS: deadline disconnects observers/RAF; stale scripts perform no capture');
    } finally {if(browser)await browser.close();a.s.close();b.s.close();}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
