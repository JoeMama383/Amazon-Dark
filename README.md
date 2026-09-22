# AmazonDark v7.451 — PDP streaming FULL

Direct parent: **v7.450~pdp-readonly-full** (`AmazonDark-v7.450-pdp-readonly-full-source.zip`, SHA-256 `5e27eeacc4e2ee562e25f211395fcf6ad8fea8540b0f67badff4c25a2068235b`). Production theming, v7.448 performance consolidation, non-PDP FULL behavior, VIEWPORT, TRANSITION, and plain-TAR exports are preserved.

## Exact v7.450 device failure

The supplied failed v7.450 PDP FULL archive proves the no-scroll routing worked, but the serializer did not:

- PDP was correctly classified before the Web pass.
- WebKit content started at one viewport and passively grew to **14,175 px** without any probe scroll mutation.
- `PDP_READONLY_FULL_DOM` reached **chunk 199** but only **927 elements**.
- The native wrapper then emitted `WEB_TIMEOUT ... after=4.0s`.
- The delayed catch-up was skipped after the interface became inactive/detached.
- Native scroll discovery was correctly skipped.

The freeze therefore comes from the v7.450 rich serializer/transport itself. Each tiny batch returned through a new `evaluateJavaScript` continuation. On the PDP, expensive computed-style, pseudo-style, geometry and contrast work meant only a few elements advanced per continuation, causing hundreds of WebKit round-trips and eventually a callback timeout.

## v7.451 correction

PDP FULL remains completely read-only, but the serialization transport is replaced:

- native starts the PDP scan **once**;
- the page performs finite 4 ms time-sliced batches;
- batches yield with probe-only `setTimeout`;
- payloads are streamed through the existing `WKScriptMessageHandler`;
- there is **no per-chunk `evaluateJavaScript` continuation**;
- the scan walks the complete mounted main-document tree, including shadow roots;
- a second cheap WeakSet-backed tree pass captures nodes mounted while the first pass was running;
- technical paint, geometry, style, media, pseudo-element and contrast metadata remain available;
- child/SafeFrame capture remains best-effort through the existing bridge;
- PDP Web/native scroll mutation remains prohibited.

The streaming scanner is created only after an explicit FULL screenshot. It is not installed as production polling/observation machinery.

## Other menus

Non-PDP FULL remains the inherited v7.449 cooperative root/overflow sweep. VIEWPORT and TRANSITION are unchanged.

See `AUDIT-v7.451.md`, `VALIDATION-v7.451.md`, and `COMMANDS.md`.
