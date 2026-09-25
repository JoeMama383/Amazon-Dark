# AmazonDark v7.489 validation

## Scope

Direct parent: `v7.488~returns-geometry-header-cta`.

This build makes one production UI correction and one probe-only diagnostic expansion:

1. The exact `.active-returns-section.instrumentation` family now owns white neutral text so the still-dark **Active Returns** heading is visible on OLED. Links, prices, success/error/state colors and other semantic colors remain excluded.
2. TRANSITION mode now records the AMI Book Details root/controller attachment order needed to explain why the v7.487 responder-based first-paint owner missed both the dimmed presentation frame and the white dismissal canvas. The expansion is read-only apart from an associated-object identity marker while the probe is explicitly armed.

## Probe evidence used

`AmazonDark-v7.486-ui-full-probe-20260925-062611-138-r1.tar` records:

- `.active-returns-section.instrumentation` at 430×227 beginning at y=66;
- the section and its wrapper still inherit neutral `rgb(15,17,17)`;
- `.active-returns-section-content` begins at y=109;
- existing card descendants are already white.

This supports owning neutral text across the exact Active Returns section rather than adding another guessed heading selector.

## Transition probe expansion

When `transition` is explicitly armed, v7.489 adds records for exact `AMIWebViewController` only:

- `UIViewController setView:` pre/post, marking the candidate root before attachment;
- `viewDidLoad`, `viewWillAppear`, `viewDidAppear`, `viewWillDisappear`, `viewDidDisappear`, `viewDidLayoutSubviews` phases;
- marked root incoming `setBackgroundColor:` writes;
- marked root `didMoveToWindow` pre/post;
- root background/layer/presentation background, alpha/opacity, frame/bounds, window, superview, `nextResponder`, incoming color and animations;
- parent/presenting/presented controller classes and transition-coordinator duration/progress.

No probe path writes color, alpha, hidden state, geometry, hierarchy or transition timing.

## Validation completed

- `scripts/lint-logos.sh`: **PASS**.
- `bash -n scripts/ui-probe.sh`: **PASS**.
- `bash -n scripts/skeleton-probe.sh`: **PASS**.
- `bash -n scripts/validate.sh`: **PASS**.
- Package/runtime/FULL/VIEWPORT/TRANSITION identity synchronization for **7.489**: **PASS**.
- `src/Tweak.xm`: **855,991 bytes**, below the repository `< 856000` gate.
- Decoded `ADReturnsTheme7480.js.inc`: `node --check` **PASS**.
- Normalized `test_v7480_build_syntax_guard.py`: **PASS** (retains the exact Objective-C++ regression that caught the v7.479 compiler failure).
- Normalized `test_v7486_putb_overlay_fade.py`: **PASS**.
- Normalized `test_v7487_book_transition_signout.py`: **PASS**.
- Normalized `test_v7488_returns_geometry_headers_cta.py`: **PASS**.
- Normalized `test_v7489_active_returns_ami_probe.py`: **PASS**.
- Normalized `test_probe_embedding.py`: **PASS** for C99/GNU++98 emitted probe payload checks and negative control.
- Normalized `test_probe_handoff.py`: **PASS** for one-current-session TAR transition export.

`AD_STRICT_VALIDATE=1 sh scripts/validate.sh` was also started against the complete normalized regression corpus. It progressed through the v7.379 transition-forensics regression with no failure before this environment's execution window terminated it. Because that monolithic run did not finish, this report does **not** claim a complete uninterrupted strict-suite pass.

## Runtime/performance scope

No MutationObserver, polling loop, interval, RAF loop, web scroll listener or recurring hierarchy scan was added. The new controller/view event logging immediately returns unless an explicit current-version TRANSITION probe is active.
