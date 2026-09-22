# AmazonDark v7.452 audit — PDP streaming FULL

## Direct parent

`v7.450~pdp-readonly-full` (`AmazonDark-v7.450-pdp-readonly-full-source.zip`, SHA-256 `5e27eeacc4e2ee562e25f211395fcf6ad8fea8540b0f67badff4c25a2068235b`).

## Probe-proven root cause

The supplied v7.450 archive disproves another scroll-architecture rewrite. PDP classification succeeded and both Web/native scroll-driving paths were bypassed. The main document also passively expanded to 14,175 px.

The failure occurs inside `PDP_READONLY_FULL_DOM`: by the 199th continuation, only 927 elements had been serialized. The serializer performs rich per-node computed-style, pseudo-style, geometry, media and effective-background work, but v7.450 asked WebKit to return after each tiny batch and then used a new `evaluateJavaScript` call for the next batch. One continuation eventually exceeded the 4-second native callback timeout.

That continuation churn is PDP-specific in practice because this renderer is much larger and heavier than the menus where FULL succeeds.

## Correction

- PDP remains classified from the exact native product route with exact `#dp` fallback.
- PDP session preflight still happens before any Web scan.
- PDP scroll mutation remains prohibited across WebKit and native scroll owners.
- One short native `evaluateJavaScript` starts the scanner and immediately returns an acknowledgement.
- All subsequent DOM work runs in the page in finite time slices and yields between slices.
- Results stream through the already-installed `adUniversalUI7433` script-message handler.
- Main PDP stream payloads are accounted separately from child-frame payloads so cross-frame coverage receipts remain truthful.
- A WeakSet-backed second tree pass cheaply skips already captured elements while finding nodes mounted during the first pass.
- Rich technical metadata remains: computed paint, bounds, borders, typography, media dimensions/state, pseudo-element paint hashes, scroll geometry, inline-style hashes, contrast metadata and structural ancestry.
- No text strings, URLs, src/href values, network payloads or clipboard data are added.

## Performance boundary

The new timer exists only inside the explicitly started diagnostic scanner and terminates when the finite walk completes. Production remains free of MutationObservers, Web scroll listeners, intervals, RAF loops, polling and recurring hierarchy scans.

## Device boundary

Source validation proves the old recursive WebKit-continuation path is absent from PDP FULL. Device installation is still required to prove responsiveness and complete traversal on the live Amazon renderer.
