# v7.518 — Person probes and Returns contours

Base: GitHub 8352243594ad22499be22a7f638ceed4558e79fe (v7.517).

## Findings and changes

The last rollback restored an entire probe engine by hash, including its routing defects. FULL's initial hierarchy collector accepted a WKWebView based on its own visible rectangle without checking hidden ancestors. Tracked webview discovery checked ancestors but not coverage by a retained native screen. Every accepted webview ran before native discovery; any accepted PDP also suppressed native scanning. This is a source-confirmed way for Person scanning to stall or be skipped. It is not a device-confirmed diagnosis of the latest failure: no v7.517 Person capture was available.

v7.518 uses ancestor visibility, clipping and a bounded nine-point hit test at capture time to select exposed renderers. Non-PDP native scans run before WebKit scans. RCTCustomScrollView receives the intended React priority. Native steps now log requested and actual offsets and mark rejected scrolling partial. Foreground loss ends a native walk and restores its original offset. The protected PDP DOM-owned path remains.

An armed VIEWPORT previously returned immediately while FULL was busy, missing the last-foreground boundary. It now writes a separate native-only partial VIEWPORT in that collision case without changing FULL's bridge or state. Web evidence is explicitly marked omitted. Normal VIEWPORT retains its existing native plus WebKit path. All three exports remain one current capture as plain TAR.

v7.517 put a React-raster border on the outer card but painted nested card wrappers opaque black. Those children can cover the parent's border, consistent with the corners-only and pressed-state screenshots. v7.518 keeps the outermost-card selection, suppresses nested React borders, and draws one inset gray contour above the contents. Existing mount/layout/section rehydration maintains it; no recurring production scanner is added. Button colors and geometry stay inherited.

## Evidence boundaries

Reviewed v7.509 FULL and v7.512 FULL archives. These are WebKit screens, not the failing Person menu. The v7.512 capture completes one webview, aborts the second and never reaches useful native discovery; its old cancellation label does not distinguish timeout from app-state loss. New captures log those conditions separately. Screenshots IMG_7241–7244 show the Returns contours obscured in the unpressed state.

## Validation

171 of 173 normalized Python host regressions passed. Two require Clang/Clang++, which are absent here. Strict validation correctly stops at the first missing compiler; it is not reported as passed. Logos lint, shell syntax and git diff checks passed. No Theos package build or on-device run was possible here. Device verification is required for the selected renderer and final border appearance.

The full probe should visibly walk the native Person page, restore the original position, and contain NATIVE_MOVE records with matching target/actual offsets. If it does not, export its partial TAR: do not keep regenerating captures. The log distinguishes zero eligible renderers, rejected offsets and lost foreground.
