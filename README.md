# AmazonDark v7.488 — Returns geometry/header/CTA correction

Direct parent: **v7.487~book-transition-signout-v6185**.

## Probe-backed Returns correction

The v7.486 FULL captures supplied for the two Returns surfaces show two separate issues in the prior rule set:

- the ORC warning owner `.a-box.a-alert.a-alert-warning` already carries Amazon-authored warning geometry (2 px top/right/bottom, 12 px left, 8 px radius). v7.483 had additionally painted an inset orange strip on its inner `.a-alert-container`. v7.488 removes all AmazonDark border-color/box-shadow ownership from this warning family and changes only its floor to OLED, so Amazon keeps both the original orange and the original geometry;
- the Your Returns history termination/header copy lives outside the item-card-only text scope, so its inherited `rgb(15,17,17)` survived on OLED. v7.488 extends white neutral-copy ownership across the exact `.returns-history-section` family while excluding authored links/prices/status colors;
- recommendation CTA buttons are now recolored in place to OLED with gray authored-width borders and white text. No width, height, radius, padding, or other geometry is changed.

The existing return-history/recommendation image taming, blue link/review colors, orange rating stars, prices, and other semantic colors remain preserved.

## Inherited v7.487 work

## Book `See more` transition

The v7.486 TRANSITION capture records both reported stages. The same full-content `UIView` owned directly by `AMIWebViewController` is opaque white at 430×829 first while nested below `_UIParallaxDimmingView`, then remains opaque white after it is reparented under `UIViewControllerWrapperView`. About 16 ms later the existing generic darkening finally turns that exact view black. v7.487 claims that exact bright, near-full-content AMI root from its normal UIView lifecycle/background setter so it is OLED from first paint. The authored parallax motion/opacity animation is not replaced.

## Sign Out confirmation

The donor is the exact `AmazonDark-v6.0.185-probe-source.zip` source (`src/Tweak.xm` SHA-256 `836b250b7965ab429b5f38a6f88199ec81e242683a1bb9d9e51ce4343551c0af`). v7.487 ports only its bounded Sign Out confirmation visual owner, not the old v6 runtime architecture:

- exact runtime class `AWButton`;
- exact sibling titles `Sign Out` and `Cancel`;
- same compact parent must contain a UILabel beginning `You are signed in as `;
- Sign Out keeps Amazon's stock image geometry/cap insets and is recolored to donor dark yellow `#D4A017`;
- Cancel keeps stock image geometry/cap insets, recolored to `#666666`, with white title ink.

No MutationObserver, timer, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan is added.
