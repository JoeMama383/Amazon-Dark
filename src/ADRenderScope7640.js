// Pure source filtering: no DOM inspection or selector matching at runtime.
function ad7640HotRoute() {
  try { return window.top === window && /^\/(?:s(?:\/|$)|dp(?:\/|$)|gp\/(?:product|aw\/d)\/)/.test(location.pathname); }
  catch (_) { return false; }
}
function ad7640ScopeCSS(css) {
  if (!ad7640HotRoute()) return css;
  var owners = [
    ':is(#gwm-Deck-btf, .gwm-dashboard-container)',
    ':is(#gwm-Deck-btf,.gwm-dashboard-container)',
    '#gwm-Deck-btf', '.gwm-dashboard-container',
    '#a-page:has(#interests-ai-sticky-div):has(#product-grid)',
    'body:has(#interests-ai-sticky-div)',
    // v7.642: full-page owners still present in the v7.640 Search/PDP capture.
    // Do not exclude shared overlays (ax-mbs, reviews, lists, shipping, maps).
    'section.your-orders-mobile-content-container.aok-relative.js-yo-container',
    '#typ-body-container', '#live-page-container-mobile',
    '#sc-page-container', '#sc-active-cart', '#sc-saved-cart', '#sc-buy-box',
    'body:has(#sc-page-container)',
    '#a-page:has(#ya-myab-address-add-link):has([id^=ya-myab-display-address-block-])',
    '[data-csa-c-painter=pharmacy-lego-painter]',
    '#a-page:has([data-csa-c-painter=pharmacy-lego-painter])',
    '#react-app.ryp__mobile',
    'body:has(:is(#ee-aisles-on-ba-widget-container,#ordersSearch))',
    'body:has(#ordersSearch)', '#ordersSearch',
    'body:is(*,#ordersSearch) #ordersSearch',
    '#a-page:has(#hybrid-hub-app .search-bar-with-suggestions-container)',
    'body:has(.discounts-react-app)',
    'body.omg-body:has(#omg-matc-top-section-id)',
    '#ng-app', '#apd-content-wrapper', '.apd-modal-box', '.cs-help-v4',
    '#root:has([class*="NavigationBar-module__navHeader_myx"])',
    '#customer-corner-root'
  ];
  // A full Search document does not contain the PDP root, and vice versa.
  // Mixed selector lists remain intact so shared controls are never excluded.
  if (/^\/s(?:\/|$)/.test(location.pathname)) owners.push('#dp', '#ppd', 'body:has(#dp)', 'body:is(*,#dp) #dp');
  else owners.push('#search', 'body:has(#search)');
  // Preserve mixed rules and all at-rules. A descendant of an off-route owner
  // can be omitted; sharing a substring with that owner is not sufficient.
  function offRoute(selector) {
    selector = selector.replace(/\/\*[\s\S]*?\*\//g, '').trim();
    return owners.some(function(owner) {
      return selector.indexOf(owner) === 0 &&
        (!selector[owner.length] || /[\s>+~.#:\[]/.test(selector[owner.length]));
    });
  }
  var result = '', start = 0, depth = 0, paren = 0, bracket = 0;
  var quote = '', escape = false, comment = false, selectors = [], part = 0;
  for (var i = 0; i < css.length; i++) {
    var c = css[i], n = css[i + 1];
    if (comment) { if (c === '*' && n === '/') { comment = false; i++; } continue; }
    if (escape) { escape = false; continue; }
    if (c === '\\') { escape = true; continue; }
    if (quote) { if (c === quote) quote = ''; continue; }
    if (c === '"' || c === "'") { quote = c; continue; }
    if (c === '/' && n === '*') { comment = true; i++; continue; }
    if (c === '(') paren++;
    else if (c === ')') paren--;
    else if (c === '[') bracket++;
    else if (c === ']') bracket--;
    if (paren || bracket) continue;
    if (c === ',' && depth === 0) { selectors.push(css.slice(part, i)); part = i + 1; }
    if (c === '{') {
      if (depth === 0) selectors.push(css.slice(part, i));
      depth++;
    } else if (c === '}') {
      if (--depth < 0) return css;
      if (depth === 0) {
        if (!selectors.length || !selectors.every(offRoute)) result += css.slice(start, i + 1);
        start = part = i + 1; selectors = [];
      }
    }
  }
  if (depth || paren || bracket || quote || comment) return css;
  return result + css.slice(start);
}

// Review selectors previously repeated a document-wide :has() disjunction.
// Resolve its two ID witnesses once per mutation delivery instead. This does
// not walk nodes, read computed style/layout, or write on unchanged state.
function ad7642ReviewScope(css) {
  var prefix = ':is(body:has(#mobile-product-reviews),body:has(#cruise-customer-reviews))';
  if (css.indexOf(prefix) < 0 || typeof MutationObserver !== 'function') return css;
  if (!window.__ad7642ReviewOwner) {
    function refresh() {
      var body = document.body;
      if (!body) return;
      function owns(id) {
        var node = document.getElementById(id);
        return node && node !== body && body.contains(node);
      }
      var mobile = owns('mobile-product-reviews'), cruise = owns('cruise-customer-reviews');
      var state = mobile || cruise ? 'reviews' + (mobile ? ' mobile' : '') + (owns('dp') ? ' product' : '') : null;
      if (body.getAttribute('data-ad7642-reviews') !== state) {
        if (state !== null) body.setAttribute('data-ad7642-reviews', state);
        else body.removeAttribute('data-ad7642-reviews');
      }
    }
    var observer = new MutationObserver(refresh);
    observer.observe(document, {subtree: true, childList: true, attributes: true, attributeFilter: ['id']});
    window.__ad7642ReviewOwner = observer;
    refresh();
  }
  // :is retains the original ID + body specificity; :where adds none.
  // Keep the authored descendant selectors and every declaration unchanged.
  return css.split(prefix).join('body:is(*,#mobile-product-reviews):where([data-ad7642-reviews])')
    .split('body:has(#mobile-product-reviews):not(:has(#dp))')
    .join('body:is(*,#mobile-product-reviews):is(*,#dp):where([data-ad7642-reviews~=mobile]:not([data-ad7642-reviews~=product]))');
}

function ad7640Style(style) {
  if (!ad7640HotRoute() || !style || style.tagName !== 'STYLE' || !/^ad[0-9]/.test(style.id || '')) return style;
  return {
    get textContent() { return style.textContent; },
    set textContent(css) {
      // These complete sheets have only dedicated full-page owners; leaving
      // them empty avoids their @media rules and repeated parse work too.
      if (/^(ad7480-returns-theme|ad7412-address-management|ad7596-order-confirmation|ad7597-live-and-thankyou)$/.test(style.id)) {
        style.textContent = '';
      } else {
        if (style.id === 'ad7593-review-business') css = ad7642ReviewScope(css);
        style.textContent = ad7640ScopeCSS(css);
      }
    }
  };
}

// Capture only owned style references. Head replacement cannot strand the
// main floor sheet until window.load (which may wait on slow ad resources).
function ad7640RetainStyle(style) {
  if (!style || style.tagName !== 'STYLE' || !/^ad[0-9]/.test(style.id || '')) return style;
  var registry = window.__ad7640Styles;
  if (!registry) {
    registry = window.__ad7640Styles = {nodes: [], index: Object.create(null)};
    function restore() {
      var parent = document.head || document.documentElement;
      if (!parent) return;
      registry.nodes.forEach(function(node, index) {
        if (node.isConnected) return;
        var current = document.getElementById(node.id);
        if (current) {
          if (current.tagName === 'STYLE') registry.nodes[index] = current;
          return;
        }
        parent.appendChild(node);
      });
    }
    document.addEventListener('DOMContentLoaded', restore, {once: true, passive: true});
    window.addEventListener('load', restore, {once: true, passive: true});
    window.addEventListener('pageshow', restore, {passive: true});
  }
  var index = registry.index[style.id];
  if (index === undefined) {
    registry.index[style.id] = registry.nodes.length;
    registry.nodes.push(style);
  } else registry.nodes[index] = style;
  return style;
}
