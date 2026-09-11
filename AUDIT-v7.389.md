# AmazonDark v7.389 targeted UI audit

Direct parent: `7.388~native-work-optimization`.
Release: `7.389~checkout-sheet-switcher-fix`.

## Issue 1 — checkout Subscribe & Save bottom sheet

The v7.388 universal FULL probe shows the visible Subscribe & Save chooser is not a
descendant of `#checkoutDisplayPage`. It is a portal-mounted sibling
`.a-sheet-web` containing exact root `#sns-item-t1-bottomsheet-0`. The sheet itself
and `.a-sheet-content-container` compute white, all neutral copy computes
`rgb(15,17,17)`, the recurrence dropdown computes white with Amazon's standard gray
border, the secondary action computes white, and the primary action computes Amazon
yellow. Existing checkout selectors could not reach this sibling tree.

v7.389 adds synchronous CSS to the existing checkout document-start program, scoped
by `body:has(#checkoutDisplayPage) .a-sheet-web:has(#sns-item-t1-bottomsheet-0)`.
It gives the sheet/heading/content OLED floors, neutral copy light ink, the recurrence
selector and both actions the existing AmazonDark `#303335` control fill + `#747a7c`
border + light text contract, and a light dropdown glyph. Link colors remain authored.
No MutationObserver, timer, re-scan, or new user script is added.

## Issue 2 — teal app-switcher card while checkout is open

The paired v7.388 transition capture contains a clean control and repeated failing
checkout backgrounds. In the failing case, after `UIApplicationDidEnterBackground`,
`AMSModalLayoutFullScreenViewController` mounts a 430x932 `UIVisualEffectView`. Its
`_UIVisualEffectContentView` receives one plain `UIView` at exact
`rgba(0,.510,.588,.600)`. SpringBoard then snapshots ordinary `SceneContent`. The
shield is absent when backgrounding outside checkout.

v7.389 recognizes only that exact inactive/background checkout hierarchy: live AMS
checkout + AppCXWindow + full-screen visual-effect host + exact teal plain child. It
marks and hides the effect synchronously, clears the teal assignment when observed,
and reasserts ownership through the already-existing UIVisualEffectView lifecycle.
There is no generic app-switcher cover, snapshot replacement, timer, poll, or
SpringBoard scene painter. Normal non-checkout switcher behavior is unchanged.
