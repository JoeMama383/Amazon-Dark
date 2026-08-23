# AmazonDark v7.0.36~probe

Direct continuation of v7.0.35's diagnostic coverage, with the probe trigger
restored to the exact older known-good workflow.

## Probe trigger
The probe listens for SIGUSR1.

Known-good NewTerm sequence:
1. Leave the target Home frame visible in Amazon.
2. Background Amazon.
3. Run `kill -USR1 "$(pgrep -x Amazon -n)"`.
4. Wait one second.
5. Find the generated probe file in Amazon's sandbox and copy it to the shared
   Documents folder.

No notifyutil.
No Darwin-notification relay.
No SpringBoard relay.
No auto-trigger-on-background.

## Probe targets
The current visible Home frame is sampled for:
- missing category-card visuals that may be IMG/SVG/background/mask/glyph;
- large Home photo ads that are not currently receiving TWB;
- large seasonal/category glyph/media leaves that are not receiving TWB;
- visible standalone iframe elements and child-frame contents when responsive.

The actual capture logic is unchanged from v7.0.35.

## Performance
Diagnostic only, bounded current-frame snapshot:
- no querySelectorAll;
- no MutationObserver;
- no TreeWalker;
- no scroll listener;
- no setInterval;
- no requestAnimationFrame;
- no recurring scanner/timer.
