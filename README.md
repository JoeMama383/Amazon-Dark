# AmazonDark v7.487 — Book transition + v6.0.185 Sign Out visual port

Direct parent: **v7.486~book-overlay-fade-removal**.

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
