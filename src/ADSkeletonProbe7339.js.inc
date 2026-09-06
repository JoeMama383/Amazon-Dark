R"AD7339JS(
(function () {
    'use strict';
    const cfg = __AD_CONFIG__;
    if (Date.now() >= cfg.until || globalThis.__adSkeleton7339) return;
    globalThis.__adSkeleton7339 = true;
    const bridge = window.webkit.messageHandlers.adSkeleton7339;
    const doc = cfg.session + '-' + Math.random().toString(36).slice(2);
    const ids = new WeakMap(), last = new WeakMap(), motion = new WeakMap(), tracked = new Set(), roots = new Set();
    const ruleQueue = [], ruled = new WeakSet();
    let serial = 0, seq = 0, raf = 0, timer = 0, ended = false, paused = false, bytes = 0;
    let frames = 0, clipped = 0, maxMS = 0, heartbeat = 0, inventoryKey = '', pending = [];
    const known = '#sc-saved-cart,#p13n-uf-anchor,li.a-carousel-card,.a-loading-static';
    const semantic = /skeleton|shimmer|placeholder|loading|carousel|hero|sc-saved-cart/i;
    const paintNames = ['background-color','background-image','background-position','background-size',
        'border-top-color','border-top-width','border-right-color','border-right-width',
        'border-bottom-color','border-bottom-width','border-left-color','border-left-width',
        'border-radius','box-shadow','outline','color','fill','stroke','opacity','filter',
        '-webkit-mask-image','display','visibility','position','z-index','overflow','transform',
        'animation-name','animation-duration','animation-delay','animation-play-state','transition-property'];
    function clean(x, n = 280) {
        return String(x == null ? '' : x).replace(/url\([^)]*\)/gi, 'url([redacted])')
            .replace(/(?:https?:|data:|file:|blob:)[^\s"'<>]+/gi, '[resource]')
            .replace(/[\r\n\t]+/g, ' ').slice(0, n);
    }
    function ident(e) {
        if (!ids.has(e)) ids.set(e, ++serial);
        return {n:ids.get(e), tag:clean(e.tagName, 24), id:clean(e.id, 120),
            cls:clean(e.getAttribute && e.getAttribute('class'), 260)};
    }
    function resourceKey(url) {
        try {
            const u = new URL(url, document.baseURI), s = u.origin + u.pathname;
            let h = 2166136261;
            for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
            return (h >>> 0).toString(16);
        } catch (_) { return ''; }
    }
    function rect(e) {
        const r = e.getBoundingClientRect();
        return [r.x,r.y,r.width,r.height].map(x => Math.round(x * 10) / 10);
    }
    function bright(c) {
        const a = String(c).match(/[\d.]+/g);
        return !!(a && a.length >= 3 && (a.length < 4 || +a[3] > 0.15) &&
            (+a[0] * .2126 + +a[1] * .7152 + +a[2] * .0722) > 150);
    }
    function paint(e, pseudo) {
        const c = getComputedStyle(e, pseudo || null), out = {};
        for (const k of paintNames) out[k] = clean(c.getPropertyValue(k), k === 'background-image' ? 700 : 280);
        if (pseudo) out.contentLength = String(c.content || '').length;
        return out;
    }
    function send(event, data) {
        if (ended) return;
        const item = {event, doc, seq:++seq, epoch:Date.now(), ms:+performance.now().toFixed(2),
            ready:document.readyState, hidden:document.hidden, ...data};
        pending.push(item);
        if (pending.length >= 10) flush();
    }
    function flush() {
        if (!pending.length) return;
        const body = JSON.stringify({session:cfg.session, events:pending});
        pending = []; bytes += body.length;
        if (bytes > 6 * 1024 * 1024) {
            bridge.postMessage(JSON.stringify({session:cfg.session, events:[{event:'FRAME_LIMIT',doc,epoch:Date.now()}]}));
            stop('byte-limit'); return;
        }
        bridge.postMessage(body);
    }
    function ancestor(e) {
        const out = [];
        for (let p = e.parentElement || e.getRootNode().host; p && out.length < 6;
            p = p.parentElement || p.getRootNode().host) {
            const c = getComputedStyle(p);
            out.push({...ident(p), rect:rect(p), bg:clean(c.backgroundColor),
                image:clean(c.backgroundImage), opacity:c.opacity, display:c.display,
                overflow:c.overflow, filter:clean(c.filter)});
        }
        return out;
    }
    function media(e) {
        const o = {};
        if (e.tagName === 'IMG') {
            o.kind = 'IMG'; o.natural = [e.naturalWidth, e.naturalHeight]; o.complete = !!e.complete;
            const s = e.currentSrc || e.getAttribute('src') || '';
            o.sourceKind = /^data:image\/svg/i.test(s) ? 'svg-data' : /^data:/i.test(s) ? 'data' : s ? 'resource' : 'none';
        } else if (e.tagName === 'IFRAME') {
            o.kind = 'IFRAME'; o.sourceKey = resourceKey(e.src);
        } else if (/^(SVG|svg|CANVAS|VIDEO)$/.test(e.tagName)) {
            o.kind = e.tagName; o.viewBox = clean(e.getAttribute('viewBox'), 80);
            o.size = [e.width && e.width.baseVal ? e.width.baseVal.value : Number(e.width) || 0,
                e.height && e.height.baseVal ? e.height.baseVal.value : Number(e.height) || 0];
        }
        return o;
    }
    function capture(e, reason, force) {
        if (ended || !e || e.nodeType !== 1) return;
        try {
            const r = rect(e), c = getComputedStyle(e), old = last.get(e);
            const visible = e.isConnected && r[2] > 0 && r[3] > 0 && r[0]+r[2] >= 0 &&
                r[1]+r[3] >= 0 && r[0] <= innerWidth && r[1] <= innerHeight &&
                c.display !== 'none' && c.visibility !== 'hidden' && +c.opacity > .001;
            if (!visible) {
                if (old && old !== 'gone') { last.set(e, 'gone'); send('NODE_GONE', {node:ident(e), reason}); }
                tracked.delete(e); return;
            }
            const name = ident(e), hint = semantic.test(name.id + ' ' + name.cls);
            const large = r[2] >= 40 && r[3] >= 8;
            const before = paint(e, '::before'), after = paint(e, '::after');
            const light = bright(c.backgroundColor) || bright(c.borderTopColor) && parseFloat(c.borderTopWidth) >= 2 ||
                bright(c.borderBottomColor) && parseFloat(c.borderBottomWidth) >= 2 ||
                bright(before['background-color']) || bright(after['background-color']);
            const picture = /^(IMG|SVG|svg|CANVAS|VIDEO|IFRAME)$/.test(e.tagName) || c.backgroundImage !== 'none';
            if (!(force || old || hint || large && (light || picture))) return;
            const state = {...name, rect:r, paint:paint(e), before, after, media:media(e),
                children:e.childElementCount, directTextLength:Array.from(e.childNodes).slice(0,100)
                    .reduce((n,x) => n + (x.nodeType === 3 ? x.length : 0),0),
                ariaBusy:e.getAttribute('aria-busy'), hydrated:!!e.querySelector('.p13n-uf'),
                parent:e.parentElement ? ident(e.parentElement).n : 0, hint, light};
            const stablePaint = p => ({...p,'background-position':'','transform':''});
            const key = JSON.stringify({...state,rect:null,paint:stablePaint(state.paint),
                before:stablePaint(before),after:stablePaint(after)});
            const moving = JSON.stringify([r,c.transform]), priorMotion = motion.get(e);
            if (key === old && priorMotion && (priorMotion.key === moving || Date.now()-priorMotion.at < 300)) return;
            motion.set(e,{key:moving,at:Date.now()});
            last.set(e, key);
            if (tracked.size < 100) tracked.add(e); else clipped++;
            send('NODE', {reason, ...state, ancestors:ancestor(e)});
            if ((hint || light) && !ruled.has(e) && ruleQueue.length < 30) {
                ruled.add(e); ruleQueue.push(e);
            }
        } catch (_) { clipped++; }
    }
    function observeRoot(root) {
        if (roots.has(root) || roots.size >= 24) return;
        roots.add(root);
        observer.observe(root, {subtree:true, childList:true, attributes:true,
            attributeFilter:['style','class','id','hidden','aria-busy','src','fill','stroke']});
    }
    function walk(root, reason, cap) {
        if (!root || cap <= 0) { clipped++; return 0; }
        const q = [root]; let i = 0;
        while (i < q.length && i < cap) {
            const e = q[i++];
            if (e.nodeType !== 1) continue;
            if (/^(SCRIPT|STYLE|LINK|META|NOSCRIPT)$/.test(e.tagName)) continue;
            capture(e, reason, false);
            if (e.shadowRoot) { observeRoot(e.shadowRoot); for (const c of e.shadowRoot.children) q.push(c); }
            for (const c of e.children) { if (q.length < cap + 1) q.push(c); else clipped++; }
        }
        if (i < q.length) clipped++;
        return i;
    }
    function inventory() {
        const sheets = Array.from(document.styleSheets).slice(0,80).map((s,i) => {
            let rules = -1; try { rules = s.cssRules.length; } catch (_) {}
            return {i, owner:s.ownerNode ? ident(s.ownerNode) : null, disabled:s.disabled,
                media:clean(s.media.mediaText), rules};
        });
        const k = JSON.stringify(sheets);
        if (k !== inventoryKey) { inventoryKey = k; send('STYLES', {sheets}); }
    }
    function rulesFor(e) {
        const matches = []; let examined = 0, blocked = 0;
        function scan(list, sheet, conditions) {
            for (let i = 0; i < list.length && examined < 1200 && matches.length < 12; i++) {
                const rule = list[i]; examined++;
                if (rule.selectorText) {
                    let matched = false;
                    // Keep selector lists intact: commas inside :is()/:has() and
                    // attribute values are not separators between whole selectors.
                    try { matched = e.matches(rule.selectorText.replace(/::?(before|after)\b/g, '')); } catch (_) {}
                    if (!matched) continue;
                    const props = {};
                    for (const p of Array.from(rule.style)) if (paintNames.includes(p) || /^(background|border|animation|--)/.test(p))
                        props[p] = [clean(rule.style.getPropertyValue(p),700), rule.style.getPropertyPriority(p)];
                    if (Object.keys(props).length) matches.push({sheet, selector:clean(rule.selectorText,800), conditions, props});
                } else if (rule.cssRules) scan(rule.cssRules, sheet,
                    conditions.concat(clean(rule.conditionText || rule.media && rule.media.mediaText || '',180)));
            }
        }
        const sheets = Array.from(document.styleSheets);
        const root = e.getRootNode();
        if (root !== document) {
            for (const s of root.querySelectorAll('style,link[rel=stylesheet]')) if (s.sheet) sheets.push(s.sheet);
            for (const s of root.adoptedStyleSheets || []) sheets.push(s);
        }
        // Examine our own sheets first, then Amazon's. These are matched declarations,
        // not a claim of cascade winners; inaccessible cross-origin sheets are counted.
        sheets.sort((a,b) => Number(/^ad/.test(b.ownerNode && b.ownerNode.id || '')) - Number(/^ad/.test(a.ownerNode && a.ownerNode.id || '')));
        for (let i = 0; i < sheets.length && examined < 1200 && matches.length < 12; i++) {
            try { scan(sheets[i].cssRules, sheets[i].ownerNode ? ident(sheets[i].ownerNode) : {index:i}, []); }
            catch (_) { blocked++; }
        }
        const inline = {};
        for (const p of paintNames) if (e.style && e.style.getPropertyValue(p))
            inline[p] = [clean(e.style.getPropertyValue(p),700), e.style.getPropertyPriority(p)];
        send('RULES', {node:ident(e), matchedDeclarations:matches, inline, examined, blocked,
            truncated:examined >= 1200 || matches.length >= 12});
    }
    const observer = new MutationObserver(records => {
        if (Date.now() >= cfg.until) { stop('expiry'); return; }
        const start = performance.now(); let count = 0, walked = 0;
        // Capture at the mutation microtask, before waiting for another frame. This
        // includes a short-lived white state even when the later RAF sees hydration.
        for (const m of records) {
            if (++count > 80) { clipped++; break; }
            capture(m.target, 'mutation-' + m.type, false);
            for (const n of m.addedNodes || []) {
                walked += walk(n, 'added', Math.min(160, 400 - walked));
                if (walked >= 400) { clipped++; break; }
            }
            for (const n of m.removedNodes || []) if (n.nodeType === 1) capture(n, 'removed', true);
        }
        maxMS = Math.max(maxMS, performance.now() - start); flush();
    });
    function tick() {
        if (ended) return;
        if (Date.now() >= cfg.until) { stop('expiry'); return; }
        const start = performance.now(); frames++;
        if (!document.hidden) {
            for (const e of Array.from(tracked)) capture(e, 'frame', true);
            for (const root of roots) for (const e of Array.from(root.querySelectorAll(known)).slice(0,40)) capture(e, 'known-owner', true);
            // Viewport hit testing finds anonymous light paint and visible hero cards;
            // candidate selection is diagnostic only and is never used to recolor UI.
            const seen = new Set();
            for (const fx of [.06,.28,.5,.72,.94]) for (const fy of [.08,.22,.38,.54,.7,.86]) {
                const hit = document.elementsFromPoint(innerWidth * fx, innerHeight * fy).slice(0,4);
                for (const e of hit) {
                    if (!seen.has(e)) { seen.add(e); capture(e, 'hit-grid', false); }
                    if (e.shadowRoot) { observeRoot(e.shadowRoot); walk(e.shadowRoot.firstElementChild, 'shadow-grid', 100); }
                }
            }
            if (frames % 6 === 0 && ruleQueue.length) rulesFor(ruleQueue.shift());
            if (Date.now() - heartbeat >= 1000) {
                inventory(); heartbeat = Date.now();
                send('HEARTBEAT', {frames, clipped, maxMS:+maxMS.toFixed(2), tracked:tracked.size,
                    viewport:[innerWidth,innerHeight], scroll:[scrollX,scrollY], shadows:roots.size-1});
            }
        }
        maxMS = Math.max(maxMS, performance.now() - start); flush();
        raf = requestAnimationFrame(tick);
    }
    function stop(reason) {
        if (ended) return;
        observer.disconnect(); cancelAnimationFrame(raf); clearTimeout(timer);
        window.removeEventListener('pagehide', onPageHide);
        window.removeEventListener('pageshow', onPageShow);
        document.removeEventListener('DOMContentLoaded', onDOMReady);
        document.removeEventListener('load', onLoad, true);
        // Leave enough room for a final limit/end marker without recursive flush.
        pending.push({event:'FRAME_END',doc,epoch:Date.now(),reason,frames,clipped,maxMS:+maxMS.toFixed(2)});
        try { bridge.postMessage(JSON.stringify({session:cfg.session,events:pending.slice(-10)})); } catch (_) {}
        pending = []; tracked.clear(); roots.clear(); ruleQueue.length = 0; ended = true;
    }
    function onPageHide(e) {
        if (!e.persisted) { stop('pagehide'); return; }
        paused = true; observer.disconnect(); cancelAnimationFrame(raf);
        send('FRAME_PAUSE',{reason:'bfcache'}); flush();
    }
    function onPageShow() {
        if (!paused || ended) return;
        if (Date.now() >= cfg.until) { stop('expiry'); return; }
        paused = false;
        const oldRoots = Array.from(roots); roots.clear(); for (const root of oldRoots) observeRoot(root);
        send('FRAME_RESUME',{reason:'bfcache'}); flush(); raf=requestAnimationFrame(tick);
    }
    function onDOMReady() { inventory(); walk(document.documentElement,'dom-ready',400); flush(); }
    function onLoad(e) { capture(e.target,'load',false); inventory(); flush(); }
    send('FRAME_START', {main:window === top, documentKey:resourceKey(location.href), viewport:[innerWidth,innerHeight], until:cfg.until,
        route:/\/cart|\/gp\/aw\/c/.test(location.pathname) ? 'cart' : location.pathname === '/' ? 'home-root' : 'other'});
    observeRoot(document);
    window.addEventListener('pagehide', onPageHide);
    window.addEventListener('pageshow', onPageShow);
    document.addEventListener('DOMContentLoaded', onDOMReady);
    document.addEventListener('load', onLoad, true);
    walk(document.documentElement,'document-start',400); inventory(); flush();
    timer = setTimeout(() => stop('expiry'), Math.max(0, cfg.until - Date.now()));
    raf = requestAnimationFrame(tick);
})();
)AD7339JS"
