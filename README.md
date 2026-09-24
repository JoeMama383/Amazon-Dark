# AmazonDark v7.475 — offsite standalone repair + PDP nav/bottom-bar polish

Direct parent: **v7.474~pdp-visible-copy-swatch**.

This pass addresses the remaining UI issues shown in the supplied screenshots and the latest `AmazonDark-v7.473-ui-viewport-probe-20260924-002420-079-r1.tar` VIEWPORT capture.

## Scope

1. **Medium / standalone sponsored card family**
   - Harden the offsite/standalone wrapper family so the medium sponsored card uses the same AmazonDark coloring algorithm as the working Celsius card:
     - OLED floors
     - one gray border
     - black neutral text promoted to white
     - dynamic semantic colors preserved
     - Sponsored/info gray + OLED inner “i” preserved
     - image treatment left to the existing tame/TWB pipeline
   - The survivor sheet now also owns the `absoluteComponents` wrapper structure used by the offsite child-frame creative so white wrapper surfaces and multiply blending cannot leave the card as an empty black box with two vertical side lines.

2. **PDP subnav “Top” row geometry**
   - Normalize the PDP subnav link row so `Top` uses the same vertical centering/min-height behavior as its neighboring tabs.
   - This is done in the exact `#nav-subnav` family already owned by v7.474; no new scanning or recurring machinery is introduced.

3. **Bottom nav hairlines**
   - Hide the thin white/partial separator layers being left behind on the bottom bar.
   - Ownership remains background-only plus exact thin-layer suppression on the bar host; icons, selection state, labels, and Amazon geometry are otherwise preserved.

## Probe coverage note

The supplied VIEWPORT tar *does* capture the working top sponsored/offsite child-frame family and is enough to verify the offsite renderer structure that needed hardening.

However, the later blank medium standalone creative shown in the screenshot was **not** the exact visible creative inside that tar. That lower creative was addressed by extending the same probe-proven offsite family rather than inventing a new delivery path.

Likewise, the `Top` alignment issue is visible in the screenshot but is not emitted as a dedicated probe assertion. The fix therefore stays tightly scoped to the existing PDP subnav DOM family.

## Architecture / policy

- No MutationObserver, interval, requestAnimationFrame loop, scroll listener, polling loop, or recurring DOM scan added.
- No new child-frame bridge or new delivery mechanism added.
- Existing standalone delivery remains intact.
- `src/Tweak.xm` remains below the 856 KB ceiling.

FULL, VIEWPORT, and TRANSITION probe instructions are regenerated as **v7.475**.
