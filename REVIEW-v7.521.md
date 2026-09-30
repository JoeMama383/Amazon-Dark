# v7.521 review

Base: fd2be84b, user-confirmed working v7.520.

## Evidence and repair

The supplied r5 FULL capture contains 1,275 initial native nodes and seven Person checkpoints (1,086–1,149 nodes each), with no truncation. Offsets advance through 0, 452, 904, 1355, 1807, 2259 and 2321, end at bottom, and restore zero. The native page has no webviews. `frameCompleteness=unverified` concerns cross-frame web capture, not a failed native walk.

`yr_item_0` and `yr_view_all_returns_card` are authored 292x69.3 controls with 1-point React borders and 12-point React radii. Only the left control contains an opaque, square 290x67.3 RCTView at inset (1,1). It paints above the parent's rounded border raster. Clearing that exact inset plane lets the parent's OLED fill and gray curved border show through. No custom outlines, masks, clipping, frame/size/transform, width or radius writes are introduced.

Returns identities now establish ancestry without waiting for the title's section marker. Existing RCTView mount, reparent, layout and background setter handling reapplies the correction, matching the other Person occluder controls. A rebuilt or reattached left card can be recognized without a stale per-view result. Text uses the existing Returns ancestry/light-text owner and preserves accents. Offline/refresh device confirmation remains required.

## Probe efficiency

Only the asynchronous native snapshot inter-batch wait changes from 10 to 4 milliseconds. The 32-node / 3.5-millisecond work bound, all metadata fields, node limits, step sizes, hydration delays, routes and offset restoration remain unchanged. This removes six milliseconds of intentional idle delay per continued batch. No measured device-speed claim is made. New NATIVE_TIMING records expose each snapshot duration. No production scan machinery is added.

## Validation

The added regression executes the shipped inset geometry predicate with g++ against the captured owner and negative controls, and checks lifecycle/color routing and preservation of scan limits. The complete normalized regression results are recorded in VALIDATION-v7.521.md. Actual iOS/Theos compilation and visual/offline confirmation are not available on this host.
