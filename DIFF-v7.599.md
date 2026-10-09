# AmazonDark v7.599 — Alexa owner recovery / Person hydration / FULL capture

## Root cause
The Oct 9 full native snapshot shows Alexa `navigation-root` under `AppCXBottomSheetContentView` inside the application's main `UIWindow`. Historical Alexa/Rufus coloring roles required an `AppCXWindow` and thus stopped applying after Amazon's host-window migration. The actual controls still expose the historical accessibility IDs and geometry. The old FULL probe exported in `state=partial` with `source_state=started`, `terminal_marker=0`; its only completed pass is the initial native hierarchy, followed by an unfinished menu arbitration log.

## Changes
- Reconnect historical AppCX Alexa themed text/controls/SVG/rounded pill ownership to the new exact native overlay ancestry. No global main-window recoloring.
- Restore black Alexa main top chrome/header and input backing. Old chevron/history/overflow and plus/mic icon ownership is reused, with legacy gray circular hosts and one ring each.
- Restore the three 390×58 Alexa suggested-card floors to OLED with one gray React border; normalize neutral card copy via the existing color-sensitive storage routine. Preserve `header_text_alexa_for_shopping` logo art, and semantic blue profile call-to-action.
- Restore the native three suggestion pills to their inherited medium-gray fill / gray ring / white text rather than the stock light-blue fill.
- Repair the Person Your Orders anonymous 186×180 Forgot-something carousel owner: recolor only its native title/subtitle text on both React text-commit paths, preserving the green time span and geometry.
- Give screenshot FULL an exact Alexa-first native route, distinct from the retained Menu/Person routes. Preserve the full mounted native scene, walk Alexa's own overflow scroller only when one exists, restore offset, and finalize the archive so `state=completed` is distinguishable from interrupted captures.
- No DOM mutation observer, runtime polling, global image filtering, added borders/overlays on non-Alexa surfaces, or changes to other families.

## Verification
- `scripts/lint-logos.sh`: PASS.
- `tests/test_v7599_alexa_owner_full_recovery.py`: PASS.
- `tests/test_v7598_pdp_reviews_ad_followup.py`: PASS (current handoff identifiers).
- `tests/test_v7533_web_theme_payload_parse.py`: PASS.
- Attempted `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`; **did not finish before the local timeout**. This is NOT claimed as a full-suite pass. Objective-C++ iOS build and device rendering remain to be verified in GitHub Actions and on-device.
