# AmazonDark v7.420 audit

Version: `7.420~cart-topnav-payment-divider-fix`  
Direct parent: `7.419~payment-giftcard-art-input-fill`

## Probe-backed corrections

### Cart top navigation tan plane

`AmazonDark-v7.419-ui-full-probe-20260913-215734-511-r1` captures a direct child of the full-screen `ANXTabRootViewController`:

- class: exact plain `UIView`
- frame/model geometry: `430x0`, full-width
- background and layer background: `rgba(0.929,0.733,0.506,1)`
- nearby visible `ANXSubNavContainer`: `430x44`, transparent
- the same tan node remains in the final snapshot after the sub-nav collapses to zero height

AmazonDark already recognized that precise tan for checkout transitions, but the owner required `gADCheckoutPresentationActive7375`. Cart therefore escaped it. v7.420 creates a separate exact tab-root owner with no checkout-state dependency and handles both attachment and future background assignments.

### Payment sticky-footer divider

`AmazonDark-v7.419-ui-full-probe-20260913-220009-210-r2` captures:

- `[data-testid=sticky-footer]`: `380x33`, OLED black
- first direct child: `380x1`, `rgb(213,217,217)`
- that child begins exactly at the claim-code card's lower edge

The 1px child is collapsed. The claim-code card's authored AmazonDark gray border remains untouched.

## Preserved

- v7.419 `#181a1b` claim-code interior continuity.
- v7.419 selected/unselected gift-card `art` brightness-only TWB.
- v7.418 role=switch outline cleanup.
- v7.417 Search carousel repair.
- v7.416 canonical location implementation.

## Architecture/performance

No new hook class, WKUserScript family, MutationObserver, timer, RAF, polling loop, Web scroll listener, or recurring hierarchy scan. The new native owner is evaluated only by existing UIView lifecycle/background events; payment is static document-start CSS.
