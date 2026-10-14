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
    'body:has(#interests-ai-sticky-div)'
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

function ad7640Style(style) {
  if (!ad7640HotRoute() || !style || style.tagName !== 'STYLE' || !/^ad[0-9]/.test(style.id || '')) return style;
  return {
    get textContent() { return style.textContent; },
    set textContent(css) { style.textContent = ad7640ScopeCSS(css); }
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
