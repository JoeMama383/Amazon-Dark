# AmazonDark v6.0.110

## v6.0.110 — restore Heart selected state + align symbol row

- Production base: v6.0.109.
- Fixes the Heart regression introduced by stable-shell first-frame ownership: Amazon's native filled/unfilled state still changed on tap, but v6.0.109 hid every native Heart descendant and always painted the same static outline SVG, so the selected white fill could never become visible.
- Keeps the one-owner first-frame Heart shell, but uses Amazon's existing `lists-framework-filled-heart` / `aok-hidden` state as a pure-CSS state bit. When Amazon reveals the filled-heart branch, the stable shell switches immediately to a white-filled Heart SVG. No click handler, observer, timer, or polling was added.
- Keeps both controls at 35x35. The screenshot shows the two-cards control centered about 5 px below the Heart, so `mlt-icon-container` is shifted upward 5 px while preserving its 35x35 hit box/visual control and first-frame ownership.
- The selected-state and alignment rules are duplicated in the earliest documentStart sheet and `ADFixesLiteral` so first-paint and settled paint agree.
- No new observer, selector traversal, scroll listener, recurring timer, RAF, `dispatch_after`, timeout, or image sampler.
