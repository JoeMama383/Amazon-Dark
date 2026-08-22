# AmazonDark v6.0.194~probe — carousel hot-path + Share focus correction

Base: v6.0.193~probe.

## v6.0.194 corrections

- Removes the old screenshot-Share phrase/subtree discovery from ordinary native UIImageView layout. Probe 6192 proved the current Share preview is WebKit/CSS, so native fallback ownership is now entered only from the exact Share text event.
- Adds a mounted-image positive fast path: an already-owned RCT UIImage on the same image/superview/window/bounds only resizes the existing TWB overlay during layout. It does not rerun semantic discovery, image classification, or peer consensus on scroll frames.
- Primary web product/photo/video carousel leaves already owned by declarative TWB CSS now settle on the first media event without ancestor-chain/local-text classification. Generic media still uses the full classifier.
- Fixes the PDP Share button's stuck post-click white focus ring. The normal :active press state remains untouched; only the lingering focused state has its background/border/shadow/outline cleared.
- v6.0.193 screenshot Share preview background ownership and v6.0.191 Product images gallery ownership are retained.

## Probe

The existing 6192/6180 diagnostics remain available; no new recurring probe mechanism is added.
