# AmazonDark v7.494 — exact Your Orders owner correction

- Direct parent: **v7.493~orders-endtext-ci-repair**.
- The v7.493 FULL r2 probe proves the remaining thick white strip is the 5 px bottom border of `.yo-mobile-atf`; v7.494 paints that exact border OLED black without changing its geometry.
- The same probe proves `form.search-bar.js-search-bar` itself still owns a 5 px gray bottom border; v7.494 collapses that exact border to 1 px while retaining the existing input/filter split treatment.
- The quantity bubble is exactly `span.product-image__qty`; v7.494 directly applies dark-gray fill, gray border, and white count text to that owner.
- Retains the verified end-of-orders white text, Prime/information tile work, and Book transition canvas correction.

# AmazonDark v7.489 — Active Returns header + expanded Book transition probe

Direct parent: **v7.488~returns-geometry-header-cta**.

## Active Returns header

The v7.486 FULL Returns capture shows the exact section owner is `.active-returns-section.instrumentation`. Its carousel/card copy is already themed, but the section itself still inherits Amazon's neutral `rgb(15,17,17)`. The visible `Active Returns` label is therefore black on the OLED floor even though the neighboring Returns headings are white.

v7.489 adds white neutral-copy ownership across that exact Active Returns section while continuing to exclude anchors, links, prices, success/error/state colors and other authored semantic colors. No geometry, spacing, card border, image, carousel, or link-color rule changes.

## Expanded Book `See more` transition probe

The prior transition capture proved the same 430×829 AMI root is the white painter in both the dimmed presentation stage and the full-white dismissal stage, but it did **not** prove when the responder/controller relationship becomes available. The v7.487 production predicate depended on that relationship, which is why identifying the painter did not guarantee first-frame interception.

v7.489 expands TRANSITION diagnostics without changing the Book transition's production paint. While transition mode is explicitly armed, it now records:

- `UIViewController setView:` before/after for exact `AMIWebViewController`, marking the candidate root before attachment;
- `viewDidLoad`, `viewWillAppear`, `viewDidAppear`, `viewWillDisappear`, `viewDidDisappear`, and `viewDidLayoutSubviews` phases for that exact controller;
- the marked root's incoming `setBackgroundColor:` writes, including the requested color and its current `nextResponder`, superview, window, model/presentation background and animation state;
- the marked root's `didMoveToWindow` before/after state;
- transition-coordinator duration/progress plus presenting/parent/presented controller classes.

These records are probe-only. They do not recolor, resize, hide, reparent, retime, or otherwise mutate the transition. The goal is to identify the earliest deterministic hook that exists **before** the first white frame, then replace the failed v7.487 timing assumption with evidence.

## Inherited v7.487 work

## Book `See more` transition

The v7.486 TRANSITION capture records both reported stages. The same full-content `UIView` owned directly by `AMIWebViewController` is opaque white at 430×829 first while nested below `_UIParallaxDimmingView`, then remains opaque white after it is reparented under `UIViewControllerWrapperView`. About 16 ms later the existing generic darkening finally turns that exact view black. v7.487 attempted to claim that root from normal UIView lifecycle/background setters, but the device result proved that the responder-based predicate becomes usable too late. v7.489 therefore leaves that production attempt unchanged while collecting the missing attachment-order evidence needed for the next correction.

## Sign Out confirmation

The donor is the exact `AmazonDark-v6.0.185-probe-source.zip` source (`src/Tweak.xm` SHA-256 `836b250b7965ab429b5f38a6f88199ec81e242683a1bb9d9e51ce4343551c0af`). v7.487 ports only its bounded Sign Out confirmation visual owner, not the old v6 runtime architecture:

- exact runtime class `AWButton`;
- exact sibling titles `Sign Out` and `Cancel`;
- same compact parent must contain a UILabel beginning `You are signed in as `;
- Sign Out keeps Amazon's stock image geometry/cap insets and is recolored to donor dark yellow `#D4A017`;
- Cancel keeps stock image geometry/cap insets, recolored to `#666666`, with white title ink.

No MutationObserver, timer, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan is added.
