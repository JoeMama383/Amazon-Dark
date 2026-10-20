# v7.644 — stylesheet separation and production cleanup

Base: the complete v7.643 source. This is a production architecture change with a probe restoration repair.

## Runtime changes

- Remove the v7.642 review MutationObserver and body-marker writes. Keep the original static review selectors, including late review insertion and removal.
- On main Search/product documents, install owned constructed stylesheets, retaining stable sheet identity and order. Do not add STYLE nodes to the app's DOM or reparse an unchanged owned sheet. Head replacement does not detach these sheets. Capability failures fall back to the existing style path.
- Keep the existing static theme rules while bypassing unrelated medical, business, checkout continuation, advertising-preference and account classifiers on Search/product. Do not install the account shadow prototype hook there.
- Preserve the existing native hooks, preferences, independent menu themes, semantic colors, geometry, and media-taming declarations. No claim of complete global JavaScript removal: non-Search/product legacy classifiers and component shadow hooks still exist.

## Source separation

Extract 193 CSS source blocks into `styles/` and separate runtime templates under `runtime/`. The build-only expander reproduces committed compiler inputs. Strict validation rejects stale generated files. This reorganization itself is not a device speed measurement. Python continues to run only in development/build/test tooling, never in Amazon.

## Diagnostics

Constructed theme sheets now contribute to the native performance inventory, report, and explicitly armed stylesheet trials. Fix the isolation getter so `+=` preserves earlier withheld CSS. Restore sheets in original order, including partial isolation modes. The previous restoration could omit earlier declarations and reorder precedence.

The source census now includes `.m`/`.mm` and reports broad tag searches, single selectors, computed style, geometry reads, innerText and shadow hooks, alongside existing timers/observers. The production observer budget is zero again.

## Evidence and limitations

The v7.643 normal capture recorded a PDP input-to-next-frame maximum of 9,333 ms. CSS isolation still recorded 5,059 ms. These are different runs, not a controlled speedup. The isolation removed intercepted rules but retained JavaScript, native hooks, and live DOM style nodes. It did not establish a root cause.

This build removes known runtime work and separates styles from live DOM mutation. Browser/source tests cannot prove that Amazon's on-phone gallery stall is cured. A normal performance capture after installing the compiled package is still required to measure that result.
