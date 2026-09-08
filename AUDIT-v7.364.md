# AmazonDark v7.364 audit — universal FULL-sweep probe repair

## Baseline

Parent: `v7.363~search-pane-related-cart-claimed`.

All v7.363 visual fixes are retained. This release changes probe architecture/identity only; it does not intentionally alter theming, launch/splash behavior, TWB policy, or production visual ownership.

## Regression diagnosis

The v7.362 universal convergence correctly reduced the UI probes to two categories, but its screenshot FULL path meant “entire currently mounted DOM/native hierarchy.” That is not equivalent to the older comprehensive menu probes on Amazon interfaces that lazy-load or virtualize content.

Historically, the useful Cart/Alexa/Person-style probes performed finite renderer walks: move the relevant `UIScrollView`/`WKScrollView` through the document, capture each viewport, then restore the original offset. Removing that traversal meant a screenshot could miss owners that were not mounted/hydrated at the trigger position.

## v7.364 architecture

There remain exactly **two** UI probe categories and no route-specific dispatcher:

1. Screenshot => `ui-full-probe`: robust universal FULL sweep.
2. `scripts/ui-probe.sh arm` => one-shot SIGUSR2 `ui-viewport-probe`: current viewport only.

### FULL Web capture

- Dynamically inventories every current on-screen `WKWebView` from the visible UIKit hierarchy plus tracked WebViews.
- Records an initial full mounted DOM.
- Performs a finite vertical `WKScrollView` walk with non-animated offsets, ~62% viewport stride, bounded at 72 steps.
- Captures a viewport DOM/paint snapshot at every sweep position.
- Recomputes the bottom after each step so newly hydrated document height is followed.
- Records a final full DOM after the sweep.
- Restores original `contentOffset` and `scrollEnabled` before moving to the next WebView.

### FULL native capture

- Initial and final full mounted hierarchy for every visible `UIWindow`.
- Dynamically discovers current visible non-WebKit scroll renderers without Home/Cart/Menu/Person/Alexa identifiers.
- Candidate families include React scroll views, collection/table views, and generic `UIScrollView` surfaces.
- Excludes WebKit and obvious keyboard/tab-bar chrome.
- De-duplicates strongly overlapping ancestor/descendant candidates on the same scroll axis.
- Finite vertical and/or horizontal sweep of selected candidates with per-step subtree + direct layer snapshots.
- Restores original native offsets and `scrollEnabled` values.

### VIEWPORT capture

- Same universal WebView/native discovery scope as v7.362 current-frame mode.
- No Web/native offset mutation.
- No full sweep.

## Runtime/performance contract

Normal runtime still contains only the single screenshot notification and single SIGUSR2 dispatch source for this UI-probe system. The heavy traversal exists only after an explicit trigger.

The universal probe JavaScript contains no `MutationObserver`, `setInterval`, `requestAnimationFrame`, web scroll listener, `scrollTo`, or `scrollBy`. Renderer movement is finite native `UIScrollView setContentOffset:animated:NO` work inside the explicit FULL capture.

FULL output cap is raised to 192 MiB to accommodate multi-renderer finite sweeps. VIEWPORT remains 48 MiB. The writer reserves the final 8 KiB so the terminal END RUN marker can still be written if the body reaches its data cap; export therefore cannot deadlock forever on a cap-truncated body.

## Handoff robustness

`scripts/ui-probe.sh export` now exports only files containing the terminal `================ END RUN ================` marker. If the newest capture is still sweeping and no completed current capture is available, the helper tells the user to keep Amazon foregrounded and rerun export rather than copying a partial probe.

## Validation

See `AmazonDark-v7.364-VALIDATION.txt` in the handoff for executed checks. No local Theos/iOS SDK build is claimed; GitHub Actions/on-device Theos remains the authoritative compile/link/package proof after push.
