## v7.546 — FULL menu route arbitration repair

Direct parent: v7.545.

The keyboard transition diagnostics from v7.545 are retained unchanged. v7.546 repairs a separate FULL-probe routing defect: the dedicated Hamburger scanner existed, but the capture dispatcher checked the retained Person `RCTScrollView#me` surface first. `ADUIViewActuallyVisible7362` only proves screen intersection; it does not prove that a React surface is frontmost. Amazon can retain the previous Person screen under the open Hamburger overlay, causing FULL to choose PERSON and return before the menu scanner ever runs.

The probe now identifies the foreground menu using hit-test ownership, recognizes both probe/theming-proven menu identities (`scrolled-hamburger` and `scrolled-hamburger-view`), resolves the actual `RCTCustomScrollView`, and arbitrates Menu vs Person using frontmost ownership before PDP detection. The dedicated scan remains finite, screenshot-triggered, non-animated, preserves `scrollEnabled`, and restores the authored offset. No production theming or keyboard behavior changes.
