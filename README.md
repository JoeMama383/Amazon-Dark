# AmazonDark v7.447 — background-safe VIEWPORT + unified TAR probes

Direct parent: **v7.446~probe-responsiveness**. Production theming and the v7.446 bounded FULL / scale-aware Search → Product transition work are otherwise unchanged.

The VIEWPORT phone workflow is corrected. `scripts/ui-probe.sh arm` now writes only a one-shot arm file; it does not look up Amazon's PID and does not signal a backgrounded process. After arming, return to Amazon, leave the exact target scene visible, and background Amazon once. The app consumes the arm at `UIApplicationWillResignActiveNotification`, takes the initial native VIEWPORT snapshot at that foreground→inactive boundary, and uses a finite iOS background task only to finish its asynchronous WebKit/frame capture. The completed capture can then be exported from NewTerm while Amazon remains backgrounded.

A foreground-only SIGUSR2 receiver is retained for remote/SSH compatibility, but it cannot consume the arm while Amazon is inactive. The old wait-for-Amazon-to-return-foreground path is removed, so a background trigger cannot accidentally capture the app-switcher/privacy hierarchy instead of the requested scene.

FULL keeps the v7.446 bounded implementation: cooperative main-document batches, lazy document/overflow-owner traversal, finite native scroll sweeps, offset restoration, no scroll disabling, 4-second WebKit callback timeouts, explicit partial-coverage receipts, and no recurring production scan machinery.

FULL, VIEWPORT, and TRANSITION now use the same export policy: **plain `.tar`, no gzip and no ZIP fallback**. FULL and VIEWPORT export exactly the current state-selected capture; TRANSITION exports only the newest current-version recording from the current arm. Historical transition recordings are never wildcarded into a new archive.

No production UI family is claimed fixed by v7.447. Outstanding visual work remains separate from this probe-workflow correction.

See `COMMANDS.md` for the push and three separate capture workflows.
