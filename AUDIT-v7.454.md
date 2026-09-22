# AmazonDark v7.454 audit

Parent: v7.453-isolated-probe.

## Probe finding

The supplied v7.453 r2 FULL archive proves transport/inventory was alive but the automatic walk did not run. The PDP stream began and emitted DOM evidence, then terminated as `document-backgrounded`; the later root initialization failed and the sweep ended at `totalSteps=0`. This is not evidence of a manual-only FULL mode.

## UI correction

The same capture identifies the failing PDP child ad as the grid-carousel renderer rooted at `#ad` with `data-testid=gridContainer`, `gridRegion`, `.grid-inset-carousel`, `.swiper-slide.bg-white`, and `data-testid^=gridRegionCarousel`. v7.454 targets only those neutral shells plus `price-text`/`currency` leaves. Arrow buttons, CTA/link colors, and image/video media are intentionally not selected.

## Probe correction

FULL initializes its guarded document/visible-panel scroll state before detailed DOM serialization. If the document root has no useful vertical range, a bounded viewport hit-test samples visible elements and ancestors to select the largest connected vertical owner; horizontal-only carousels cannot qualify. Detailed mounted-DOM inventory follows the root pass, then nested owners are walked, then an incremental catch-up serializes unseen nodes and verifies coverage. Scroll offsets are restored once at the end.

The detailed stream persists a WeakSet for the run and uses larger finite slices, reducing duplicate work while retaining background/deadline termination.

## Validation boundary

Static/regression validation in this source tree can verify selector scope, execution order, JS syntax fixtures, packaging identity, and inherited invariants. Device verification is still required for Amazon's live renderer and scroll lifecycle.
