# AmazonDark v7.447 validation

Direct parent: `v7.446~probe-responsiveness` (`AmazonDark-v7.446-probe-responsiveness-source.zip`, SHA-256 `637763e24cf093b208b61ff406bebe7889c5653923b8e0d9cd437a1c8588cbce`).

## Scope

- Preserve v7.446 production theming, bounded FULL traversal, and scale-normalized Search → Product skeleton handling.
- Make VIEWPORT one-shot and background-safe: arm is passive; the arm is consumed at `UIApplicationWillResignActiveNotification`; the initial native hierarchy is frozen at that foreground→inactive boundary; a finite iOS background task lets asynchronous WebKit/frame collection finish; export happens afterward from NewTerm.
- Retain SIGUSR2 only as an optional foreground-only compatibility path. It cannot consume a VIEWPORT arm while Amazon is inactive.
- Restore the established plain-TAR export policy for FULL, VIEWPORT, and TRANSITION. No gzip, ZIP, or bsdtar fallback remains in the active probe helpers.
- Keep exports isolated: FULL/VIEWPORT use their exact state-selected current file; TRANSITION uses only the current-version capture from the current arm and never bundles historical recordings.
- Integrate the deterministic transition handoff mtime regression fix from the v7.446 CI hotfix.

## Validation

- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- Universal main-frame and cross-frame generated JS includes compile under gnu++98 and parse under Node: PASS.
- Real helper fixture verifies passive VIEWPORT arm with no PID lookup / `kill -USR2`: PASS.
- Real FULL and VIEWPORT exports create readable plain TAR archives and never cross-export each other: PASS.
- Real TRANSITION export creates readable plain TAR archives, exports only the current armed session, and excludes historical captures: PASS.
- ZIP poison fixtures return failure if invoked; all three current export paths still pass, proving ZIP is not used: PASS.
- Bounded FULL responsiveness regression: PASS.
- All 125 Python regression files under `tests/test_*.py`: PASS (strict suite completed in bounded chunks after the single all-in-one run exceeded the execution cap).

## Runtime architecture

No MutationObserver, requestAnimationFrame loop, web scroll listener, polling loop, or recurring hierarchy scan was added. The new steady-state addition is one notification observer for the foreground→inactive boundary; actual traversal remains opt-in and finite.
