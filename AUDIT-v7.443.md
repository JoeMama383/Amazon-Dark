# AmazonDark v7.443 audit

## Why this release exists

GitHub strict validation for v7.442 stopped in `test_v7370_checkout_script_reinstall.py` at the frozen `ADCoreWebJS7271` hash. The failure was legitimate: v7.442 retired `ADFrameOwnerTriggerJS7440()` from the active core argument list but left sixteen `%@` conversions in the `stringWithFormat:` call even though only fifteen programs remained. The v7.370 historical normalizer also still expected the retired trigger in the current delta, so it could not reconstruct its frozen baseline before hashing.

## Corrections

- `ADCoreWebJS7271()` now has 15 `%@` conversions for exactly 15 active program arguments.
- The v7.369/v7.370 historical normalization tests remove the current 15-program delta before comparing their frozen hashes.
- The retired v7.440 child-frame traversal/message-bridge implementation is removed from the production translation unit instead of remaining as dead static code.
- `ADPDPMainResidualJS7440()` remains active.
- The v7.442 `_WKUserStyleSheet` all-frame ad-delivery path remains active and unchanged in purpose.
- The v7.443 probe package guard now accepts `7.443~*`; FULL, VIEWPORT, and TRANSITION identities are bumped to 7.443.
- `COMMANDS.md` uses a unique `/var/mobile/t7443` staging directory and the v7.443 archive name.

## Runtime scope

This is a release/validation repair, not another speculative visual selector pass. It removes dead frame-walker code and fixes the core concatenation mismatch while preserving the smoother v7.440-derived runtime and the v7.442 user-style ownership approach. No MutationObserver, interval polling, RAF loop, web scroll listener, or frame-tree traversal is introduced.

## Device status

Standalone-ad visual treatment is still pending device verification. Do not treat v7.443 as visually fixed until the same top standalone ad is confirmed on-device.
