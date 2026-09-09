# AmazonDark v7.377 — probe-diff / source-ownership audit

## Direct base

- Parent: `7.376~warm-switcher-noninterference`.
- Parent Tweak SHA-256: `2f585184c34a47517820231a9d060fa8cf93d8a98f73a016714c1f86b90d2ebc`.
- Parent SpringBoard SHA-256: `1453e4efc45cfe95af044668234c0b6c25ea8e50ca51e3e66033f0d5161e111e`.

## 1. BYG expanded quantity control

The v7.376 FULL captures identify the live expanded control as:

`div.a-stepper-inner-container <- fieldset.a-stepper-expanding-fieldset <- ... <- div.byg-dense-grid-atc-container`

Its computed inner floor is `rgb(255,255,255)` with a `3px rgb(255,216,20)` edge. The trash/remove/add sprite leaves inside the expanded stepper have `filter:none`. This is a different selector path from the already-themed Cart stepper and from `fieldset[name='checkout-quantity-stepper']`.

v7.377 scopes the accepted Cart palette to that exact BYG lane: `#303335` inner fill, 1px `#747a7c` edge, transparent outer/plumbing nodes, and white add/remove/subtract/trash sprite leaves.

## 2. Checkout decrement

Historical Cart evidence identifies `span.a-icon.a-icon-small-remove` as the decrement sprite. Cart already inverts it white. Checkout's existing quantity rule only included `.a-icon-small-trash,.a-icon-small-add`; therefore quantity > 1 exposed the untouched black decrement. v7.377 adds `.a-icon-small-remove` and `.a-icon-small-subtract` to the same exact checkout selector. No generic icon rule is added.

## 3. Crayon / sparse BYG hydration

The same `anonCarousel3` geometry can be compared directly:

- v7.374 good capture: row 2 / column 2 (`x=162.9`, `y=410.5`) contains the full dense-grid faceout, `byg-dense-grid-atc-container asin-id-B0096XWNNY`, the authored ATC subtree, price row, basis-price row, and delivery tail.
- v7.376 r1 and r2: the same row 2 / column 2 faceout exists at the same geometry, but ends after image + product title. It has **no ATC subtree and no price/details tail**. The omission survives the probe's finite vertical full sweep.

This pinpoints a bug in v7.375's recovery logic. It classified an incomplete card only when `img + title + .a-price` were already present. The observed Crayon failure has no `.a-price`, so it could never satisfy the recovery predicate and no nudge was attempted.

v7.377 changes only that classifier: one card with image+title but no price and no ATC, while every sibling has ATC, is the sparse renderer failure. The document is marked and Amazon's existing horizontal carousel is moved/restored by one pixel once, with the existing scroll/resize activation. No fake `+`, DOM cloning, reload, MutationObserver, interval, timeout, RAF loop, or recurring scanner is introduced.

## 4. Teal app-switcher / warm transition

v7.376 removed the erroneous v7.375 black snapshot cover and the inherited v7.307 warm-splash hidden/alpha state machine. The user's new device report shows the teal card still occurs, so those app-side mutations were not the root source.

The remaining architectural delta from the known-good v7.335/v7.336 warm/switcher contract is upstream in SpringBoard. The v7.337/338 artwork-only rebase introduced a hook on `SBDeviceApplicationSceneViewPlaceholderContentViewProvider -_loadLiveXIBViewForApplication:`. Unlike `XBApplicationSnapshot`, that method provides no `GeneratedDefault`/`Default`/`SceneContent` kind and no launch-request provenance to the tweak. The production code nevertheless replaced **every** return for `com.amazon.Amazon` with custom artwork.

That violates the project's stated resource policy and the non-interference contract: a generic scene-placeholder provider must not be treated as a proven cold-launch resource. v7.377 removes that hook entirely. `XBApplicationSnapshot` remains the only SpringBoard image owner; its policy still vetoes `SceneContent` and protected snapshots. The app-side v7.350 AXU/Tez seal remains, so the later probe-proven opaque cold-splash child still has its exact owner.

This is a source correction, not a new cover: no view is inserted into the app switcher, no lifecycle observer is added, and no warm view is hidden/revealed.

## 5. Probe identity

v7.376 generated files with v7.376 filenames while the universal header said v7.375 and the JSON payload said v7.374. v7.377 aligns the filename, native header, JSON `version`, arm marker, helper, and receipt identity.

## Validation contract

- Logos lint for app and SpringBoard source.
- Node parse for all embedded JS payloads.
- Full Python regression suite, including new v7.377 assertions.
- `git diff --check` equivalent whitespace validation.
- Phone push remains dependency-free; strict Python validation remains in GitHub CI.
