# AmazonDark v7.378 audit — BYG focus outline + one-shot renderer recovery

## Direct parent
`7.377~byg-stepper-hydration-switcher-source-fix`

## New FULL evidence

### Collapsed Add-to-Cart circle
After expanding a BYG quantity control and collapsing it back, the real `button[name=submit.addToCart]` is already correctly themed as a 32×32, `border-radius:100px` circle with `rgb(48,51,53)` fill and a 1px `rgb(116,122,124)` border. The residual artifact is a separate `2px rgb(136,140,140) solid` focus outline on the button. That outline is the four gray corner artifact visible outside the circle.

v7.378 suppresses `outline` only on the exact checkout-BYG dense-grid ATC button, including focus/focus-visible/active states. It does not remove the circular border.

### Crayola / row-2-col-2 sparse faceout
The v7.377 FULL capture begins with 24 dense-grid faceouts and 23 ATC subtrees and ends after the probe's finite sweep with the same 24/23 state. The sparse faceout contains image + product title but still has no price/details tail and no real ATC subtree.

Therefore the v7.377 synchronous 1px carousel scroll/restore + resize nudge is disproven on-device for this renderer family.

The known successful recovery is a document refresh. v7.378 performs exactly one `location.reload()` only when:

1. checkout BYG exists;
2. at least six dense-grid faceouts exist;
3. exactly one faceout has image+title, no price, and no ATC;
4. every other faceout has its real ATC subtree; and
5. this exact failure has not already triggered a reload in `sessionStorage`.

If the reload remains sparse, the guard prevents another reload. If the page comes back complete, the guard is cleared so a genuinely later navigation can recover independently.

## Performance / scope
No fake control, MutationObserver, `setInterval`, `setTimeout`, `requestAnimationFrame`, polling loop, or recurring scanner. No Cart/Search/Person/Alexa/shared-theme change. No warm/app-switcher or cold-launch production-policy change.
