# AmazonDark v7.347 Cart strip forensics audit

## Why v7.346 can still leak

The strip investigation has crossed three distinct renderers. v7.302/v7.308/v7.311 treated the ~430x26 `#sc-saved-cart` Web hydration band; later temporal captures showed that element already black while the visible thin strip persisted. v7.344 then isolated a separate native `AWLoadingIndicatorBarView` at 430x5 with layer contents present and no background color.

v7.346 correctly avoids globally blacking that class because the same bar exists on Home. It instead attaches an opaque black sublayer only while an internal boolean says `cartTab` is selected. The remaining unproven assumption is that the internal boolean is always synchronized with Amazon's real selected tab and that the exact class hook is installed/runs when the bar mounts.

The source already contains a stronger diagnostic definition of selected tab: `ADProbeTabSelected7254()` checks `selected`, `UIControlStateSelected`, and `UIAccessibilityTraitSelected` on the live `ANXTabBarButton`. Production does not use that live state; it trusts only the value written by `ANXTabBarButton -setSelected:`. Therefore the diagnostic recorder can truthfully report `tab=cartTab` while the production cover remains gated off.

A second plausible failure is class-load timing: the exact `AWLoadingIndicatorBarView` hook is installed through the normal Logos initialization path, while Amazon can load private UI families lazily. v7.347 does not assume this occurred; the already-installed global UIView lifecycle hook records a read-only exact-class witness so a mounted bar with no exact-hook event is directly observable.

## v7.347 scope

No visual correction is added. The v7.346 paint path is preserved while the explicit transition recorder adds enough telemetry to prove:

1. whether the exact bar hook fired;
2. whether the global UIView lifecycle saw the bar;
3. latched vs live Cart selection;
4. whether the black cover exists, is attached, visible, and geometrically correct;
5. whether a named high-z black sublayer is present in the native frame when the white strip is visible.

The next on-device capture therefore decides the production fix instead of generating another selector hypothesis.
