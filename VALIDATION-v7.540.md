# v7.540 validation

Evidence basis: AmazonDark-v7.539-transition-probe-20261001-082200-68385.tar.

The expanded v7.539 capture recorded 96 KEYBOARD_TRAITS events. Every recorded traits object is UITextInputTraits; WKExtendedTextInputTraits is absent at each keyboard lifecycle notification. During the Interests editor handoff, the WKContentView owner repeatedly returns fresh legacy traits with keyboardAppearance=0 before the existing helper writes 1, while additional live legacy traits are still read with appearance=0 around repeated keyboard WillShow/DidShow cycles. This is the path v7.540 clamps.

Validation on final source tree:
- scripts/lint-logos.sh: PASS
- scripts/ui-probe.sh shell syntax: PASS
- scripts/skeleton-probe.sh shell syntax: PASS
- ADNewMenus shipped payload reconstruction/node parse: PASS
- v7.539 handoff evidence regression: PASS after successor-policy update
- v7.540 legacy-traits clamp regression: PASS
- Objective-C++ build syntax guard regression: PASS
- exact scripts/validate.sh normalization reproduced on a temporary tests copy: 196/196 test_*.py PASS in six sequential batches
- Tweak.xm: 855905 bytes (<856000 gate)

The monolithic AD_STRICT_VALIDATE=1 wrapper was also started and passed its lint/version-sync gates plus the early regression sequence, but the execution environment terminated that single process at its 300-second tool limit. The same normalization code from validate.sh was then run explicitly and every normalized regression completed successfully.
