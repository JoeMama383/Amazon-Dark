# AmazonDark v7.433 validation

## Static/regression validation

- `scripts/lint-logos.sh`: PASS.
- `scripts/ui-probe.sh`: `sh -n` PASS.
- `scripts/skeleton-probe.sh`: `sh -n` PASS.
- `scripts/validate.sh`: the repository's full validator is long-running in this container, so its Python regression set was executed in sequential chunks instead of one uninterrupted invocation.
- Python regression scripts: **116 / 116 PASS**, including new `test_v7433_universal_crossframe_probe.py`.
- Main universal Web probe C-string include: compiles under `gnu++98`, emitted bytes equal the decoded include, Node syntax check PASS.
- Child/SafeFrame bridge C-string include: compiles under `gnu++98`, emitted bytes equal the decoded include, Node syntax check PASS.
- `layout/DEBIAN/postinst`: mode 755.

## v7.433-specific contracts checked

- Probe user script is document-start and `forMainFrameOnly:NO`.
- The main universal probe no longer attempts cross-origin `contentDocument` traversal.
- Main-frame probe dispatches nonce-scoped commands using `iframe.contentWindow.postMessage`.
- Child frame bridge self-inspects DOM/computed styles and recursively forwards to nested iframe windows.
- Native `WKScriptMessageHandler` validates nonce/chunk bounds and writes `CROSS_FRAME_DOM` records into the active FULL/VIEWPORT output.
- Child-frame payload records hash-only origin/path/referrer metadata.
- Text remains length/hash only.
- Foreground/effective-background luminance and dark-on-dark/light-on-light diagnostics are present.
- No MutationObserver, interval, RAF, Web scroll listener, or programmatic JS scroll operation exists in either universal probe payload.
- FULL/VIEWPORT/TRANSITION operational identities are v7.433.

## Compile/link status

A full Theos iOS compile/link is not available in this container. GitHub Actions remains the authoritative compile/link proof after push.

## Device validation required

Force-close and reopen Amazon after installing v7.433 so existing APE/SafeFrame documents are recreated with the document-start bridge. Then capture the broken standalone sponsored ad with FULL or VIEWPORT and verify that the exported probe contains one or more `CROSS_FRAME_DOM` sections with the internal ad renderer nodes and computed paint state.
