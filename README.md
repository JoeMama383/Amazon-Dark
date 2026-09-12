# AmazonDark v7.413 — address/location compile fix

Direct parent: **v7.412~address-location-aux-theme**.

This release is a compile-only correction to the v7.412 address/location build. The v7.412 native `RCTScrollContentView` hook correctly casts `self` to `UIView *v`, but one line still accessed `self.layer`. Because `RCTScrollContentView` is intentionally only forward-declared in the tweak, Clang cannot resolve the `layer` property on that static type. v7.413 changes that single access to `v.layer`, which is type-safe because `v` is the existing `UIView *` cast.

The unused `micButton` classifier variable is also removed, eliminating the warning introduced by the same code path. No theming selector, ownership gate, color policy, image treatment, transition logic, or runtime architecture changes. All v7.412 UI behavior is preserved. FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.413.
