# v7.564 validation repair

Baseline: origin/main e9ca91db, v7.563.

Reproduced the original Returns/PDP standalone compile failure: ADPharmacyMediaJS7563 and ADSellerMessagingThemeJS7562 were undeclared in the extracted test fixture. Both definitions exist earlier in production. The fixture now extracts complete helper definitions in production order; original syntax assertions remain and failed compiler diagnostics are surfaced.

The full run then exposed a stale version-comment anchor in the Refunds help-note test. It now locates the same block using its stable descriptive marker. All geometry/color assertions remain.

Validation: AD_STRICT_VALIDATE=1 sh scripts/validate.sh completed successfully: python-regressions OK (217), Logos lint OK. Local Clang 21.1.0 frontend distributed with Zig was used for the C/Objective-C++ checks; the link test used its GNU/Linux driver. tinycss2/cssselect2/lxml were installed, so CSS cascade checks ran. git diff --check passed.

Runtime changes are version identities only. All v7.563 Pharmacy styles, large-image taming, and prior UI/probe behavior remain intact.

This verifies regression and isolated compiler checks, not a full iOS/Theos package build or physical-device rendering. GitHub Actions native build and on-device verification remain pending.
