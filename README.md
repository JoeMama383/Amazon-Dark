# AmazonDark v7.363 — Search pane media, Related Searches, and Cart coupon-state polish

Direct source base: **v7.362~universal-dual-ui-probes**.

This build keeps the v7.362 universal dual-probe architecture unchanged in behavior and adds only the probe-backed UI corrections requested from the latest Search/autocomplete, Search-results, and Cart captures.

## Visual changes

- Search autocomplete product-thumbnail rows: stop the generic suggestion-floor rule from turning image-layer owners opaque black; keep the loaded product thumbnails visible and inside the existing autocomplete TWB strength lane.
- Search autocomplete Rufus/Alexa row: stop the generic autocomplete floor from erasing the authored icon background artwork. No replacement SVG/icon is injected.
- Product Search `Related searches`: exact `textref` cards now use OLED-black floors, `#494d4d` borders, white copy, and white search icons.
- Cart Apex coupon: both unclaimed and claimed states are anchored to the state-stable coupon container. The claimed state stays true green with white copy; its SVG circle is OLED black and its check remains white.
- Cart unified-promotion savings badges: lime green is replaced with `#5a9e43`; badge copy is OLED black.

## Probe architecture retained

**FULL universal probe:** take one screenshot while the issue is visible. It captures all current on-screen WKWebViews, their entire mounted DOM, and the full mounted native hierarchy.

**VIEWPORT universal probe:**

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

It captures only elements intersecting the current screen and does not scroll.

The helper command shapes are unchanged from v7.362; only the versioned output identity advances to v7.363.

See `COMMANDS.md` for push/probe commands and `AUDIT-v7.363.md` for validation details.
