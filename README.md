# AmazonDark v6.0.106

## v6.0.106 — Heart first-paint lifecycle probe (diagnostic only)

Production paint is byte-for-byte v6.0.105. This build only expands the already-shipping bounded probe to capture Search-result Heart insertion/class/src hydration, reusing existing observers and the existing background dump path.

- Production base is v6.0.104; the working v6.0.104 two-cards first-frame/persistence fix is retained unchanged.
- Applies the same ownership model to the Search-result Heart: `[class*=lists-framework-action-button]` paints the finished dark circular chrome plus a canonical white outline Heart directly from CSS.
- The identical Heart rule is present in both the earliest documentStart sheet and `ADFixesLiteral`, so the settled icon exists before Amazon/Dark Reader can expose a placeholder frame.
- Amazon's transient Heart IMG/I/SVG/fill/unfill children stay `opacity:0`; their placeholder -> final artwork swaps therefore cannot create a visible second render cycle.
- The existing symbol runtime now short-circuits the exact `lists-framework-action-button` Heart host after one legacy cleanup (`data-ad-heart6105`), just as v6.0.104 does for `.mlt-icon-container`.
- The generic `gfix1` lane already excludes the `heart` / `lists-framework` families, so unlike the v6.0.103 cards regression the canonical Heart host is not eligible for whole-control inversion.
- No new observer, scroll listener, interval, RAF, timeout, dispatch queue, or selector traversal is added.
