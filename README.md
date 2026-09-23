# AmazonDark v7.457 — temporary Share recovery and handler diagnostics

This is NOT screenshot Share prevention. It carries the v7.456 close-before-walk workaround and adds bounded native screenshot-registration evidence so the actual opener can be identified. The temporary preference is labeled honestly: `Close Screenshot Share for FULL (Temporary)`, default ON. Turning it OFF stops PDP FULL rather than manipulating a possibly locked page. The old hide-only `disableShareSheetForProbes` setting is not used.

Fully close and relaunch Amazon after installation so early observer registrations are recorded. Take one screenshot on a product page, leave Amazon visible for the walk, then export FULL from the terminal. Send that TAR. `SCREENSHOT_OBSERVER_REGISTRATIONS` records up to 64 registration sites, each with at most 12 native stack entries. Selector registrations include class/selector; block registrations include their registration stack. This is registration evidence, not proof of which callback fired. No notification is suppressed, no observer is retained, and manual Share is untouched outside FULL.

Direct parent: v7.455, commit `615ba69c820e7625cb4e869d604da595ee2f478c`.
Source handoff only: iOS compilation and installed-device verification are still required.

## Evidence and correction

Five v7.440 product captures show the same sequence: the root scroll height drops from 12,737–14,405 pixels to 779, while the product container remains full height. A screenshot-triggered SSF Product Share sheet appears and `#a-page` becomes fixed with `a-scroll-disabled`. The v7.403 probe stylesheet hid that sheet without invoking its close handler, leaving the modal scroll lock active.

Earlier attempts interpreted this as a collapsed renderer. v7.455 then disabled automatic PDP walking in favor of manual checkpoints. That interpretation missed the retained product height and new Share sheet.

This version removes the hiding stylesheet and obsolete Hide Share preference. During an explicitly requested PDP FULL capture, it invokes only the SSF sheet's stock close button and waits for the page lock to release before using the existing automatic walker. A late-arriving lock pauses the walker for the same check. Unknown modals, missing close buttons, and timeouts stop with partial/error evidence; the probe does not forcibly clear Amazon's styles or lock classes.

Cart/Search retain their automatic walker. The manual-only PDP tracker is retired. Duplicate native PDP scrolling remains disabled. Existing UI treatment is retained; this release does not claim to fix outstanding ad styling. FULL, VIEWPORT, and TRANSITION exports remain separate plain TAR archives.

## Use and verification

Take one screenshot in Amazon and leave the app visible while FULL walks automatically. After completion, switch to the terminal and export. No manual product-page scrolling is required. VIEWPORT and TRANSITION workflows are in `COMMANDS.md`.

The new regression fixture models the captured Share lock, verifies stock-close recovery and automatic bottom traversal, and tests late locks, unknown modals, timeout, restore, backgrounding, and nonce changes. These tests are not a substitute for an installed-device run. Inspect `PDP_SHARE_GATE`, `WEB_SWEEP_END`, and `WEB_WALK_COVERAGE` in that run before calling the repair device-verified.
