# AmazonDark v7.487 validation

## Scope

Direct parent: `7.486~book-overlay-fade-removal`.

v7.487 changes two production owners only:

1. the probe-proven white `AMIWebViewController` root exposed during the immersive Book-details `See more` transition; and
2. the bounded native Sign Out confirmation visual treatment ported from the exact v6.0.185 donor source.

## Transition evidence

The supplied v7.486 TRANSITION capture contains both reported bright stages, so the probe did not need to be expanded.

The exact same `UIView` owned by `AMIWebViewController`, rect `430x829` below the top chrome, is recorded:

- at uptime `100021.060194`: opaque white while its parent is `_UIParallaxDimmingView`;
- at uptime `100021.56846141667`: still opaque white after reparenting to `UIViewControllerWrapperView`;
- at uptime `100021.58435041667`: the same owner becomes black under the existing later theme path.

That proves the visible semi-transparent/light transition and blank white canvas share an early white backing owner. v7.487 claims only a bright-neutral, near-full-content `UIView` whose direct responder is `AMIWebViewController`; the existing parallax motion/opacity animation is left authored.

## v6.0.185 Sign Out donor

Exact donor archive materialized from the project history: `AmazonDark-v6.0.185-probe-source.zip`.

Exact donor `src/Tweak.xm` SHA-256:

`836b250b7965ab429b5f38a6f88199ec81e242683a1bb9d9e51ce4343551c0af`

The port keeps the donor's bounded recognition contract:

- exact runtime class `AWButton`;
- exact `Sign Out` / `Cancel` sibling titles;
- same compact parent must contain a UILabel beginning `You are signed in as `;
- Sign Out stock background-image geometry is recolored to `#D4A017`;
- Cancel stock background-image geometry is recolored to `#666666`, with white title ink;
- source image alpha, cap insets and resizing mode are retained.

No v6 Dark Reader/runtime architecture was restored.

## Regression / syntax validation

- `scripts/lint-logos.sh`: PASS.
- `bash -n scripts/ui-probe.sh`: PASS.
- `bash -n scripts/skeleton-probe.sh`: PASS.
- `bash -n scripts/validate.sh`: PASS.
- package/probe identity synchronization checks: PASS.
- `tests/test_v7487_book_transition_signout.py`: PASS.
- normalized `tests/test_v7480_build_syntax_guard.py`: PASS; retains the exact Objective-C++ preflight that catches the historical v7.479 malformed message-send failure.
- complete version-normalized Python regression corpus: **164/164 PASS** in bounded runs. The long source-audit tests were split only to fit the execution window; every test in the normalized corpus was executed successfully.
- `src/Tweak.xm`: **854,555 bytes**, below the frozen 856,000-byte source gate.

## Runtime policy

`ADBookTransitionSignOut7487.inc` adds no `MutationObserver`, interval, RAF loop, web scroll listener, `dispatch_after`, polling loop, or recurring hierarchy scan. The transition owner rides the existing `UIView` lifecycle/background setter. The Sign Out owner rides the existing `UIButton` mount/layout lifecycle and performs only a bounded local sibling check after an exact `AWButton` title match.

## CI limitation

The repository's workflow still performs the authoritative Theos/iOS SDK compile/package on macOS. This environment does not contain Theos or the iOS 16.5 SDK. The full source-regression stage and the known Objective-C++ failure guard were run locally before packaging.

## Packaged-release replay

After creating the flat-root source ZIP, it was extracted into a clean round-trip directory. A SHA-256 manifest comparison of all 353 packaged regular files against the validated source tree was byte-identical. The extracted package then passed `zip -T`, logo lint, all three shell syntax checks, the v7.487 focused regression, package/runtime identity checks, and the 854,555-byte source gate again. Because the archive contents are byte-identical to the tree that completed the 164/164 normalized regression corpus, the regression result applies to the shipped archive bytes rather than only to an earlier working directory.
