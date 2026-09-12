# AmazonDark v7.412 — address + location auxiliary UI theme

## Release
- Version: `7.412~address-location-aux-theme`
- Runtime: `v7.412-address-location-aux-theme`
- Direct parent: `7.411~permission-firstpaint-owner-fix`

## Evidence reviewed
- `AmazonDark-v7.411-ui-full-probe-20260911-202634-022-r1.zip` — **Your Addresses** Web/AUI page.
- `AmazonDark-v7.411-ui-full-probe-20260911-203522-224-r1.zip` — **Enter a US zip code** native React page.
- User screenshot of **Ship outside the US** — structurally assigned to the same lower native location-navigation family as the ZIP screen. A distinct country-screen FULL probe was not supplied, so this portion is deliberately structure/geometry-gated rather than text-route-gated.

## 1. Your Addresses — Web/AUI
The FULL probe identifies a standalone account/address manager, not the checkout shipping-address deck. v7.412 scopes the new static rule to the exact `ya-myab` family:
- top Add address / Add pickup rows -> dark gray fill, standard gray edge, light text;
- address cards -> OLED black with gray card edge;
- neutral black text and section/header text -> light;
- readable secondary/default copy -> contrast-safe gray;
- Edit / Remove / Set as Default -> dark-gray controls, gray borders, light text;
- card dividers -> gray;
- neutral pressed/focus states -> dark;
- authored blue links remain currentColor;
- raster/SVG/sprite/icon families are explicitly left unfiltered so semantic/dynamic artwork is preserved.

## 2. Ship outside the US — native React location-navigation family
This page is handled by the native auxiliary-location owner rather than by broad Web CSS. The owner requires the exact lower-half inset React scroll geometry and a matching header/list shape. It themes only neutral surfaces:
- country/list plates and neutral rows -> OLED black;
- header and ordinary neutral text -> light;
- acceptable secondary text -> gray;
- existing thin dividers/separators -> standard gray;
- authored chevron/image/vector artwork is not tinted or filtered.

## 3. Enter a US zip code — native React
The new FULL probe proves the visible white/yellow controls are native React owners:
- exact `RCTSinglelineTextInputView` at ~394x44 -> `#303335` fill with one existing React gray border; input/placeholder text becomes light;
- exact nested ~394x45 yellow Apply `RCTView` -> OLED black with one existing React gray border and white text;
- header row -> OLED with its existing 1px React bottom border recolored gray;
- neutral header text -> light;
- back chevron/image remains authored.

The implementation rewrites the existing React border channels and clears only duplicate CALayer border ownership where necessary; it does not stack a second border.

## Preservation / architecture
- v7.411 camera/microphone button-text first-paint ownership retained.
- v7.411 Choose-your-location first-paint rail/shell fix retained.
- v7.408 inactive app-switcher hardening retained.
- v7.407 PDP transition skeleton handling retained.
- existing semantic blue/green/red/orange states preserved.
- no production `MutationObserver`, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, fake snapshot, generic image inversion, or new WKUserScript family was introduced.
- Your Addresses adds one small static CSS program to the existing immutable document-start program; native country/ZIP work is event-driven from existing React/UIKit lifecycle/setter hooks.

## Validation
- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- targeted v7.412 UI regression: PASS.
- exact v7.411 -> v7.412 probe receipt handoff: PASS.
- bounded non-exhaustive Python regressions: **82/82 PASS**.
- exhaustive `tests/test_probe_handoff.py`: **PASS** separately.
- strict serial `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: reached inherited passing tests with no assertion failure before the 120-second execution ceiling; the bounded suite and exhaustive handoff suite were therefore run independently as above.

## Build status
Theos is not installed/configured in this environment (`/makefiles/common.mk` absent), so a local rootless `.deb` compile is not claimed. Device/GitHub Actions packaging remains authoritative. Device verification is still required for Amazon's live React renderers.
