// Exercise the actual shipped document-start payloads, not hand-copied fix CSS.
// Fixtures reproduce the six v7.360 probes' DOM owners and three heart paint paths.
// Artwork is a synthetic monochrome test vector; no product/account data is included.
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const modules = process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const pw = require(modules ? path.join(modules, 'playwright') : 'playwright');
const source = fs.readFileSync(path.join(root, 'src/Tweak.xm'), 'utf8');
function strings(s) { return [...s.matchAll(/@"((?:\\.|[^"\\])*)"/g)].map(m => JSON.parse('"' + m[1] + '"')).join(''); }
function payloads(s, factor = .42) {
    const floor = strings(s.slice(s.indexOf('static NSString *ADFloorJS(void){'), s.indexOf('// v7.191: cache the large strength-dependent TWB payloads.')));
    const twb = strings(s.slice(s.indexOf('static NSString *ADTWBJS(void){'), s.indexOf('static NSString *ADPrivacyModeJS7117(void){')));
    assert.equal((twb.match(/%\.3f/g) || []).length, 14, 'TWB format arity must stay 14');
    return floor + twb.replaceAll('%.3f', factor.toFixed(3)).replaceAll('%%', '%');
}
const svg = body => 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">${body}</svg>`);
const heart = svg('<path d="M16 26L5 14C-1 4 11 0 16 9C21 0 33 4 27 14Z" transform="translate(6 6) scale(.625)" fill="none" stroke="black" stroke-width="3"/>');
const heartLeaf = svg('<path d="M16 28L5 16C-1 6 11 2 16 11C21 2 33 6 27 16Z" fill="none" stroke="black" stroke-width="4"/>');
const filled = svg('<path d="M16 26L5 14C-1 4 11 0 16 9C21 0 33 4 27 14Z" transform="translate(6 6) scale(.625)" fill="black"/>');
const checkbox = svg('<path d="M5 5H27V27H5Z" fill="none" stroke="black" stroke-width="3"/>');
const product = svg('<path fill="white" d="M0 0H32V32H0Z"/><path fill="#04a8ff" d="M12 12H20V20H12Z"/>');
const brand = '_featured-brands-search-top-mobile_';
const img = (id, cls) => `<img id="${id}" class="${cls}" src="${product}">`;
function heartButton(id, variant) {
    if (variant === 'placeholder') return `<div class="lists-framework-action-button puis-heart-icon-container"><span id="${id}" class="puis-heart-placeholder-container"><img class="puis-heart-placeholder-icon" src="${heartLeaf}"></span></div>`;
    return `<div class="lists-framework-action-button puis-heart-icon-container ${variant === 'parent' ? 'lists-framework-replaced' : 'legacy'}"><span id="${id}" class="lists-framework-heart-background"><span class="lists-framework-unfilled-heart"><div class="lists-framework-unfilled-heart-accessibility-wrapper" role="button" aria-pressed="false"><i class="lists-framework-unfilled-heart-icon" role="img" aria-label="Save"></i></div></span></span></div>`;
}
const mlt = id => `<div class="more-like-this-container"><div id="${id}" class="mlt-icon-container"><img class="s-image" src="${checkbox}"></div></div>`;
const fixture = `<!doctype html><meta name="viewport" content="width=device-width"><style>
body{margin:0;background:black;color:#e8e6e3;font:14px Arial}*{box-sizing:border-box}
.row{display:flex;gap:15px;padding:8px}.a-color-base,.a-color-secondary{color:#b1b5b5}.a-price{color:#e8e6e3}.a-color-success{color:#008000}.a-color-price{color:#b12704}
[class*=_AsinContainer_container__]{width:155px;background:white;border-radius:5px}
[class*=_AsinContainer_imageContainer]{background:white;height:134px;padding:4px}
[class*=_AsinContainer_productImage]{width:147px;height:126px;object-fit:cover}
[class*=_AsinContainer_infoContainer]{background:white;padding:4px}
.a-icon-prime,.a-icon-star-mini{display:inline-block;width:22px;height:16px}
.a-icon-prime{background:#0088ff}.a-icon-star-mini{background:#ff8000}
.nice-cat-card_image{width:76px;height:56px;object-fit:cover}.rufus-alexa-icon{width:20px;height:20px}
.mlt-icon-container,.lists-framework-heart-background,.puis-heart-placeholder-container,.puis-mab-chevron{display:block;position:relative;width:32px;height:32px;border:1px solid #888c8c;border-radius:50%;background-color:white}
.mlt-icon-container img,.puis-heart-placeholder-icon{position:absolute;left:7px;top:7px;width:16px;height:16px}
.lists-framework-action-button{width:32px;height:32px}
.lists-framework-unfilled-heart{display:block}.lists-framework-unfilled-heart-accessibility-wrapper{width:30px;height:30px}
.lists-framework-unfilled-heart-icon{display:block;position:relative;left:7px;top:7px;width:16px;height:16px}
.legacy .lists-framework-unfilled-heart-icon{left:-1px;top:-1px;width:33px;height:33px;background-image:url("${heart}");background-size:contain}
.lists-framework-replaced .lists-framework-heart-background,.puis-heart-placeholder-container{background-image:url("${heart}");background-size:32px 32px;background-repeat:no-repeat;background-position:center}
.saved .lists-framework-heart-background{background-image:url("${filled}")}
.puis-mab-overlay{width:168px}.puis-mab-overlay-row{height:40px;display:flex;align-items:center;justify-content:space-between;padding:5px}
.puis-mab-overlay-heart{width:20px;height:20px;background:url("${heart}") center/contain}
.puis-mab-overlay-icon-share,.puis-mab-overlay-row-select i.a-icon-checkbox{width:16px;height:16px;display:block;background:black;mask:url("${checkbox}") center/contain no-repeat;-webkit-mask:url("${checkbox}") center/contain no-repeat}
.puis-mab-overlay .mlt-icon-container{border:none;background:none;width:20px;height:20px}
.puis-mab-overlay .mlt-icon-container img{left:2px;top:2px}
.apex-coupon-tile{display:inline-flex;align-items:center;background:#ffe3e3;border-radius:8px;padding:2px 8px;height:28px}
.apex-coupon-checkbox{width:16px;height:16px;accent-color:black}.apex-coupon-checkbox-label{padding-left:8px}
</style>INJECT
<div id="search"><section data-csa-c-painter="featured-brands-search-top-mobile-cards">
<div class="${brand}style_container__test">${img('brand-image',brand+'BrandLogoContainer_mobile-image__test')}<a id="heading" class="${brand}Title_title__test">Everyday</a><div class="${brand}MobileBody_carousel__test row">
<div id="card" class="${brand}AsinContainer_container__test"><div id="image-floor" class="${brand}AsinContainer_imageContainerMobile__test">${img('featured-image', brand + 'AsinContainer_productImageMobile__test')}</div><div id="info-floor" class="${brand}AsinContainer_infoContainer__test">
<a id="title" class="a-color-base">Product</a><span id="price" class="a-price"><span>12</span></span><span id="neutral" class="a-color-secondary">Reviews</span>
<span id="success" class="a-color-success">Green</span><span id="sale" class="a-color-price">Sale</span><span id="custom" style="color:#e7c400">Dynamic</span><span class="a-color-price"><span id="nested-color" class="a-color-base">Colored descendant</span></span>
<i id="prime" class="a-icon-prime"></i><i id="stars" class="a-icon-star-mini"></i><svg width="12" height="12"><path id="prime-svg" fill="#0088ff" d="M0 0h12v12H0z"/></svg>
</div></div></div></div></section>
<div class="nice-cat-carousel-container nile-category-cards-mobile-carousel row">${[1,2,3,4,5].map(n => img('nice-'+n,'nice-cat-card_image')).join('')}</div>${img('alexa','rufus-alexa-icon')}
<div class="row">${mlt('standalone')}${heartButton('old-heart','legacy')}${heartButton('placeholder','placeholder')}${heartButton('parent-heart','parent')}<div class="puis-mab-container puis-mab-open"><span id="chevron" class="puis-mab-chevron"></span></div></div>
<div class="puis-mab-overlay"><div class="puis-mab-overlay-row"><span>Save</span><i id="menu-heart" class="puis-mab-overlay-heart"></i></div><div class="puis-mab-overlay-row puis-mab-overlay-row-select"><span>Select</span><i id="select" class="a-icon a-icon-checkbox"></i></div><div class="puis-mab-overlay-row puis-mab-overlay-row-mlt"><span>More like this</span>${mlt('menu-mlt')}</div><div class="puis-mab-overlay-row puis-mab-overlay-row-share"><span>Share</span><i id="share" class="puis-mab-overlay-icon-share"></i></div></div>
<div id="new-controls" class="row"></div></div>
<div id="sc-page-container"><div class="apex-coupon-tile-container apex-coupon-tile-mobile"><div data-csa-c-painter="cart-coupon"><span class="a-declarative"><div><div id="coupon" class="apex-coupon-tile unclaimed red checkbox"><input id="coupon-check" class="apex-coupon-checkbox apex-coupon-checkbox-c" type="checkbox"><label class="a-form-label apex-coupon-checkbox-label"><span class="apex-coupon-tile-text-content"><span id="coupon-copy" class="a-color-base a-text-normal">Coupon price</span><span class="apex-coupon-tile-message-suffix"><span class="a-color-base apex-coupon-tile-price-content"><span class="a-price"><span id="coupon-price" class="a-price-whole">12</span></span></span></span></span></label></div></div></span></div></div></div>
<div id="outside" class="row">${img('outside-image','nice-cat-card_image')}<div id="outside-coupon" class="apex-coupon-tile">Outside</div></div>`;
const ids = ['heading','card','image-floor','info-floor','title','price','neutral','success','sale','custom','nested-color','prime','stars','prime-svg','featured-image','alexa','nice-1','nice-2','nice-3','nice-4','nice-5','old-heart','placeholder','parent-heart','standalone','menu-mlt','select','share','chevron','coupon','coupon-copy','coupon-price','coupon-check','outside-image','outside-coupon'];
const read = ids => Object.fromEntries(ids.map(id => {
    const e=document.getElementById(id),c=getComputedStyle(e),r=e.getBoundingClientRect();
    return [id,{bg:c.backgroundColor,color:c.color,text:c.webkitTextFillColor,filter:c.filter,fill:c.fill,border:c.borderTopColor,borderWidth:c.borderTopWidth,image:c.backgroundImage,mask:c.webkitMaskImage,width:r.width,height:r.height,radius:c.borderRadius}];
}));
async function pageFor(browser, js, route='/s') {
    const page=await browser.newPage({viewport:{width:430,height:932},deviceScaleFactor:1});
    const html=fixture.replace('INJECT',js ? `<script>${js}</script>` : '')+`<script>window.first=(${read})(${JSON.stringify(ids)})</script>`;
    await page.route('https://www.amazon.com/**', r=>r.fulfill({contentType:'text/html',body:html}));
    await page.goto('https://www.amazon.com'+route);return page;
}
async function pixelStats(page,id){
    const png=await page.locator('#'+id).screenshot();
    return page.evaluate(async b64=>{
        const image=new Image();image.src='data:image/png;base64,'+b64;await image.decode();
        const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
        const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);const p=ctx.getImageData(0,0,image.width,image.height).data;
        let gray=0,white=0;for(let i=0;i<p.length;i+=4){if(Math.abs(p[i]-48)<3&&Math.abs(p[i+1]-51)<3&&Math.abs(p[i+2]-53)<3)gray++;if(p[i]>210&&p[i+1]>210&&p[i+2]>210)white++;}return{gray,white};
    },png.toString('base64'));
}
async function run(){
    const browser=await pw[process.env.AD_PROBE_BROWSER||'webkit'].launch({headless:true,...(process.env.AD_PROBE_BROWSER_PATH?{executablePath:process.env.AD_PROBE_BROWSER_PATH}:{}),...(process.env.AD_PROBE_BROWSER==='chromium'?{args:['--no-sandbox','--disable-gpu','--disable-dev-shm-usage']}:{}),});
    try{
        const previous=cp.execFileSync('git',['show','aab59b0370eeec3ea4e4cff7741e200950f85db1:src/Tweak.xm'],{cwd:root,encoding:'utf8',maxBuffer:2e6});
        const old=await pageFor(browser,payloads(previous));const before=await old.evaluate(read,ids);
        assert.equal(before.card.bg,'rgb(255, 255, 255)');assert.equal(before.standalone.bg,'rgb(255, 255, 255)');assert.equal(before.select.bg,'rgba(0, 0, 0, 0)');
        assert.equal(before['nice-1'].filter,'none');assert.equal((await pixelStats(old,'parent-heart')).white,0,'Negative control reproduces blank hydrated heart');
        const current=await pageFor(browser,payloads(source));const first=await current.evaluate(()=>window.first);
        if(process.env.AD_RENDER_DEBUG)console.log(await current.evaluate(()=>Array.from(document.styleSheets).flatMap(s=>Array.from(s.cssRules).filter(r=>r.selectorText&&document.getElementById('heading').matches(r.selectorText)).map(r=>r.cssText))));
        for(const id of ['card','image-floor','info-floor'])assert.equal(first[id].bg,'rgb(0, 0, 0)',id);
        for(const id of ['heading','title','price','neutral'])assert.equal(first[id].color,'rgb(255, 255, 255)',id);
        for(const id of ['success','sale','custom','nested-color','prime','stars','prime-svg','alexa','outside-image','outside-coupon'])
            for(const field of ['color','bg','filter','fill'])assert.equal(first[id][field],before[id][field],id+' '+field);
        for(const id of ['featured-image','nice-1','nice-2','nice-3','nice-4','nice-5'])assert.equal(first[id].filter,'brightness(0.42)',id);
        assert.equal((await current.evaluate(read,['brand-image']))['brand-image'].filter,'brightness(0.42)');
        assert.equal(first.standalone.bg,'rgb(48, 51, 53)');assert.equal(first.select.bg,'rgb(232, 230, 227)');assert.notEqual(first.select.mask,'none');
        assert.equal(first['menu-mlt'].bg,'rgba(0, 0, 0, 0)');assert.equal(first.chevron.border,'rgb(28, 137, 227)');
        for(const id of ['old-heart','placeholder','parent-heart','standalone']){
            const p=await pixelStats(current,id);assert(p.gray>400,id+' must paint the intended gray shell');assert(p.white>12,id+' must have a visible white glyph');
            for(const key of ['width','height','radius','borderWidth'])assert.equal(first[id][key],before[id][key],id+' '+key);
        }
        assert((await pixelStats(current,'select')).white>20,'Select mask must paint visible pixels');
        await current.evaluate(markup=>{document.getElementById('new-controls').innerHTML=markup;},heartButton('late-heart','placeholder')+mlt('late-mlt'));
        assert((await pixelStats(current,'late-heart')).white>12);assert((await pixelStats(current,'late-mlt')).gray>400);
        await current.evaluate(markup=>{document.getElementById('new-controls').innerHTML=markup;},heartButton('late-heart','parent'));
        assert((await pixelStats(current,'late-heart')).white>12,'Hydration must not erase heart');
        await current.evaluate(()=>{const p=document.getElementById('parent-heart');p.parentElement.classList.add('saved');p.querySelector('[role=button]').setAttribute('aria-pressed','true');});
        assert((await pixelStats(current,'parent-heart')).white>30,'Saved silhouette must retain state artwork');
        const cart=await pageFor(browser,payloads(source),'/gp/cart/view.html');const c=await cart.evaluate(()=>window.first);
        assert.equal(c.coupon.bg,'rgb(0, 128, 0)');assert.equal(c['coupon-copy'].color,'rgb(255, 255, 255)');assert.equal(c['coupon-price'].text,'rgb(255, 255, 255)');
        const oldCart=await pageFor(browser,payloads(previous),'/gp/cart/view.html');const oc=await oldCart.evaluate(read,ids);
        for(const id of ['coupon','coupon-check'])for(const f of ['width','height','radius','borderWidth','filter'])assert.equal(c[id][f],oc[id][f],id+' '+f);
        await cart.locator('#coupon-check').check();assert(await cart.locator('#coupon-check').isChecked());
        await cart.addStyleTag({content:'.apex-coupon-tile.red{background:#ffe3e3}.apex-coupon-tile-text-content span{color:#555}'});
        assert.equal((await cart.evaluate(read,['coupon'])).coupon.bg,'rgb(0, 128, 0)');
        await current.addStyleTag({content:'.mlt-icon-container,.puis-heart-placeholder-container{background-color:white}.lists-framework-heart-background{background-color:white}[class*=_AsinContainer_container__]{background-color:white}'});
        assert((await pixelStats(current,'old-heart')).gray>400);assert((await pixelStats(current,'placeholder')).gray>400);
        const strength=await pageFor(browser,payloads(source,.65));assert.equal((await strength.evaluate(read,['nice-1']))['nice-1'].filter,'brightness(0.65)');
        if(process.env.AD_RENDER_OUTPUT)await current.screenshot({path:process.env.AD_RENDER_OUTPUT,fullPage:true});
        console.log('PASS: baseline negative controls reproduce missed floors, media, white MLT, transparent Select and blank parent-art heart');
        console.log('PASS: first-paint floors/copy/media, three heart paths, late hydration and late CSS; visible gray-shell/white-glyph pixels');
        console.log('PASS: Prime/stars/dynamic colors, outside owners, open ring, media strength, stock geometry, saved art and coupon checkbox behavior');
    }finally{await browser.close();}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
