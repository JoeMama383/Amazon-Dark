# AmazonDark v6.0.206

Base: **v6.0.185~probe** (`2d9a9c4`), on report that v6.0.205 is slower than 185.
No 186–205 work is carried forward.

## What the 196–205 experiments established

- **v6.0.201 / 202** replaced Dark Reader with direct OLED floors. Fast, but theming
  parity was lost. Direction abandoned.
- **v6.0.203** kept Dark Reader owning detailed theming and had AmazonDark own only the
  page/root canvas and WebKit backing floor, through one tiny document-start sheet plus
  constant-time backing hooks. That is the right principle: own a small, constant-time
  surface; leave detail to Dark Reader.
- **v6.0.195** showed the pattern that works on hot paths: narrow observers to the
  mutations that actually matter, cache resolved pairs, defer reconciliation to idle.

This build applies that principle to the one layer none of them touched — the selector
layer — and changes nothing else.

## The change

Eight stylesheet rules had the form:

    :where(div,span,section):has(> [class*=s-color-swatch-container-list-view])

They are duplicated across the document-start sheet and the Dark Reader fixes sheet, so
16 in total. `:where(div,span,section)` places no constraint WebKit can filter on, so
every one is evaluated against **every div, span and section in the document**, and
`:has()` invalidation re-runs them on DOM mutation.

Every component they target — `s-variation-options-link`,
`s-color-swatch-container-list-view`, `s-status-badge-component`,
`puis-csi-with-label-container` — is a search-result component. On Home they can never
match, yet they were still evaluated on every scroll mutation.

All 16 are now scoped to `[data-component-type=s-search-result]`. Zero unconstrained
`:has()` rules remain in either sheet.

Why this maps to the three reported symptoms, all one mechanism — style recalc blocking
the main thread:

- **Home scroll** — cards mutate in continuously; those rules can never match on Home
  and are now skipped on the left-hand selector instead of searching the tree.
- **Search → 3s tap delay** — results hydrate in bulk; evaluation is now confined to
  result cards rather than the whole document.
- **PDP carousels** — same mechanism on the heaviest DOM in the app.

## Theming

Unchanged inside search results, which is the only place these rules could ever match.
Verified rather than asserted: the old rule matched a Home node (the waste being
removed) and the new rule matches the search-result hosts and not the Home node.

## Verification

- Selector behaviour tested in jsdom: search-result swatch host still themed,
  search-result badge host still themed, old rule matched a Home node, new rule does
  not. 4/4.
- 0 unconstrained `:where(div,span,section):has(` in either sheet; all 16 constrained.
- All payloads parse; balance 0/0/0; `scripts/lint-logos.sh`.
