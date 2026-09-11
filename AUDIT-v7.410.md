# AmazonDark v7.410 audit

## Release

- Version: `7.410~permission-text-location-firstpaint`
- Runtime: `v7.410-permission-text-location-firstpaint`
- Direct parent: `v7.409-permission-controls-location-rails-fix`

## Probe evidence reconciled

### Camera permission timing
The supplied v7.406 transition session `AmazonDark-v7.406-skeleton-1789164833529-15879-transition.jsonl` proves the camera prompt hydrates in stages:

- tick 193: `sheet-view` exists.
- tick 195: `inflight-prompt-title` is visible.
- tick 196: `inflight-prompt-description` is visible.
- tick 206: `inflight-prompt-dismiss-button` and `inflight-prompt-allow-button` finally appear.

The title therefore reaches a visible frame about 134 ms before the buttons. Waiting for the final controls before classifying the sheet is a real first-paint race. v7.410 treats the title/description identifiers themselves as sufficient camera identity.

### Microphone permission timing
The v7.409 transition bundle proves `allowTitle` mounts before `actionButton`. v7.410 classifies the microphone family from `allowTitle` immediately instead of waiting for the button.

### Permission text final-paint ownership
Neutral permission text is normalized to the AmazonDark light color while saturated semantic links remain authored. Assignment-time handling is retained, and final-paint/layout handling now covers both observed React text renderer families:

- `RCTTextView`: text storage plus final `drawRect:` correction.
- `RCTParagraphComponentView`: attributed-string assignment plus final `layoutSubviews` correction using the current attributed string.

This closes the load-dependent late-hydration case without a timer, observer, polling loop, or hierarchy scan.

### Choose-your-location transition
The v7.409 transition probe records the bright presentation shell expanding from ~10.7 pt toward its settled height while the inset dark `RCTScrollView` is already present at x≈18, width≈394 and eventually ~375.7 pt high. A separate 430x18 bright rail sits directly above it.

v7.410 now lets that exact local scroller geometry identify the shell before any location root marker is required. The adjacent 18 pt rail uses the same sibling witness. The historical root-marker path remains only as a settled-state compatibility fallback.

## Preserved behavior

- Camera checkbox square remains authored/stock.
- Camera and microphone controls keep one React-owned rounded 1 pt gray border; no competing CALayer ring.
- Authored blue permission/location links remain blue.
- Selected address orange edge remains authored.
- v7.408 inactive AppCXWindow switcher-shield invariant is unchanged.
- v7.407 PDP image-backed skeleton correction is unchanged.
- Existing immutable Web theming architecture is unchanged.

## Performance contract

No new production:

- `MutationObserver`
- interval/polling loop
- `requestAnimationFrame` loop
- Web scroll listener
- recurring hierarchy scan
- delayed retry loop
- WKUserScript family

All new correction remains event-driven through existing React setters/lifecycle/final-paint hooks.
