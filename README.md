# AmazonDark v7.364 — robust universal FULL-sweep UI probes

Direct source base: **v7.363~search-pane-related-cart-claimed**.

This build keeps the v7.363 Search/Related Searches/Cart visual fixes intact and repairs the v7.362 universal-probe convergence. The v7.362 FULL probe captured the entire *currently mounted* Web/native tree, but it removed the finite renderer scroll walks that made the older menu-specific probes useful on lazy/virtualized interfaces. v7.364 restores that behavior without bringing back per-menu probe categories.

## Two universal probe categories only

### FULL universal sweep — screenshot trigger

Leave the target menu/screen visible and take **one screenshot**.

The probe dynamically discovers the current renderer ownership instead of dispatching by Home/Cart/Menu/Person/Alexa route:

- initial full native hierarchy for every visible `UIWindow`;
- every current on-screen `WKWebView`;
- initial full mounted DOM for each WebView;
- finite top-to-bottom `WKScrollView` sweep with per-step current-viewport DOM/paint snapshots so lazy and virtualized content can hydrate;
- final full DOM inventory after the sweep;
- dynamically discovered non-WebKit `UIScrollView` renderers (React scrolls, collection/table views, and generic scroll surfaces), swept over each genuinely scrollable axis with per-step native subtree/layer snapshots;
- final full native hierarchy;
- every Web/native `contentOffset` and `scrollEnabled` value restored before completion.

The scan is finite and explicit-trigger only. It adds no steady-state MutationObserver, timer, RAF loop, web scroll listener, polling loop, or recurring native hierarchy scan.

### VIEWPORT universal probe — command-armed SIGUSR2

Leave the target visible and run:

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

This remains a fast one-shot current-screen capture. It does **not** mutate scroll offsets.

## Export behavior

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
```

Because FULL sweeps can take longer than the old mounted-tree capture, export now refuses to hand off a partial file. Keep Amazon foregrounded until the scan finishes, then rerun export if it reports that the probe is still sweeping.

## Preserved v7.363 visual fixes

- autocomplete product thumbnails remain visible/tamed rather than being blacked out;
- authored Rufus/Alexa autocomplete artwork is preserved;
- Related Searches cards remain OLED black with `#494d4d` borders, white copy, and white search glyphs;
- claimed Cart Apex coupon remains green with white copy, OLED-black circle, and white check;
- Cart unified-promotion badge remains the calmer `#5a9e43` with OLED-black copy.

See `COMMANDS.md` and `AUDIT-v7.364.md`.
