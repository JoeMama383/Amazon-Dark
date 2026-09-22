# AmazonDark v7.450 — PDP read-only FULL

Direct parent: **v7.449~full-probe-nonblocking**. This release corrects only the Product Detail FULL diagnostic path. Production theming, the v7.448 performance consolidation, non-PDP FULL behavior, VIEWPORT, TRANSITION, and plain-TAR exports are preserved.

## Probe-backed diagnosis

The generic FULL architecture was not the primary problem. FULL works on the other Amazon menus. Three known-good v7.435 Product Detail captures show that the full mounted `#dp` document was already available **before** the probe tried to drive it:

- 7,530 nodes over 11,341 px;
- 7,546 nodes over 11,341 px;
- 9,074 nodes over 13,076 px.

After the old FULL probe changed the Product Detail scroll owner, all three captures collapsed to a WebKit content height of about **779 px**. The active sweep added little diagnostic coverage while destabilizing the product renderer. Later attempts to make that sweep more bounded or cooperative did not remove the fundamental PDP-specific side effect.

## v7.450 correction

An exact Product Detail WebView is identified first from the native WebView URL (`/dp/`, `/gp/product/`, `/gp/aw/d/`) and then, only as a fallback, from the exact DOM root `#dp`. Once any current WebView is classified as Product Detail, the **entire FULL Web session** is read-only so an auxiliary/ad WebView cannot be driven first:

- no `scrollEnabled` changes;
- no `setContentOffset:`;
- no JavaScript `scrollTo` / scroll command;
- no nested overflow-owner sweep;
- no native scroll-candidate discovery or sweep for a FULL session containing the PDP.

Every WebView in that PDP FULL session receives one cooperative complete mounted-DOM inventory, followed by a passive 750 ms unseen-node catch-up. These passes inspect DOM state without changing scroll state. Native initial/final hierarchy snapshots remain read-only, and the native scroll-candidate phase is skipped entirely for the PDP session.

All non-PDP menus retain the v7.449 generic FULL implementation unchanged.

## Coverage boundary

This captures the entire **currently mounted** PDP DOM. Historical PDP evidence shows that was already the full 11–13k px document on the affected renderer. If Amazon introduces content that literally does not exist until a human scrolls to it, v7.450 will report the mounted document rather than forcing the renderer to scroll and risking the collapse again.

No production `MutationObserver`, Web scroll listener, interval, RAF loop, polling loop, or recurring hierarchy scan is introduced.

See `AUDIT-v7.450.md`, `VALIDATION-v7.450.md`, and `COMMANDS.md`.
