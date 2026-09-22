# v7.452 probe recovery

Parent: exact v7.451-pdp-streaming-full source.

## Supplied evidence
- r4 (search): 13 root positions, y=0 through 8220, final observed max=9111;
  ends scroll-move-failed before FINAL_FULL_DOM. Partial; zero child-frame payloads.
- r5 (product): PDP_STREAM_START_ERROR result=pdp-stream-bridge-unavailable;
  zero streamed DOM batches. Partial; zero child-frame payloads.
- Both contain initial and final native hierarchy snapshots (about 500 views each).
  Similar file size did not imply full document coverage. Neither was a successful FULL.

## Changes
- Re-register the message handler on the actual live controller before capture,
  independently of the installed user-script receipt. A retained script is not proof
  that its message handler still exists.
- Every FULL WebView now receives the same finite streaming full mounted-DOM
  inventory before optional scrolling. Product pages retain their predecessor's
  read-only policy; search pages retain a lazy-load sweep after inventory.
- Remove duplicate native contentOffset restoration for WebKit and forced native
  layoutIfNeeded calls. Normal UIKit layout remains in control.
- Restrict stream timeouts and batches to their capture identity; page-side deadline
  terminates work. Serializer exceptions yield a terminal partial receipt.
- Record concrete scroll failure domain/code or JavaScript error name. Recover a
  replaced document scroll owner within the same live document; do not silently
  claim success after a failed sweep.
- Keep plain TAR exports, separate modes, and next-background viewport capture.

## Remaining limits
This fixes evidenced failure paths, not a verified on-device universal sweep.
A full mounted-DOM inventory includes offscreen elements but cannot capture content
Amazon has not mounted yet. Product pages intentionally do not auto-scroll because
v7.450 documented renderer collapse following scroll mutation. A manual traversal
may still be necessary for unmounted content. No claim that all product lazy content
is covered, or that the observed black flash is conclusively eliminated.
The r4 log omitted the concrete error; its exact failure cause remains unproven.
The new diagnostics preserve DOM evidence even if that optional sweep fails again.

Outstanding theme issues remain open: standalone ads, duplicate borders, compact ad
heading/sponsored glyph, untamed brand media, missing bundle images and transition
skeleton. This release changes diagnostic behavior; it does not claim those fixed.

## Validation
127 runnable Python regression scripts pass, including a new executable Node fixture
for missing transport, 400-node full/offscreen traversal on both routes, asynchronous
yielding, preserved offsets and deadline completion. Three clang-dependent scripts
could not run here. AD_STRICT_VALIDATE=1 sh scripts/validate.sh stops at missing clang.
No iOS SDK/Theos build or device run was available; GitHub CI and device checks remain.
