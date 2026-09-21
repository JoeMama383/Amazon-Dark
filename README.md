# AmazonDark v7.443 — user-style ownership validation fix

v7.443 is cut from the exact v7.442 user-style-ad-ownership source. It does **not** add another PDP selector family or replace the v7.442 user-level all-frame stylesheet. The purpose of this release is to repair the release/validation inconsistency exposed by strict CI while preserving the smoother v7.440-derived runtime architecture.

The v7.442 core program retired `ADFrameOwnerTriggerJS7440()` but accidentally left `ADCoreWebJS7271()` with sixteen `%@` format conversions for only fifteen active program arguments. v7.443 corrects that concatenation to fifteen conversions and updates the frozen v7.369/v7.370 normalization tests to remove the current fifteen-program delta before comparing their historical hashes.

The retired v7.440 child-frame traversal/message-bridge implementation is also removed from the production translation unit instead of being retained as dead static code. The exact v7.440 main-document residual remains, and embedded APE/SafeFrame ad delivery remains owned by the v7.442 `_WKUserStyleSheet` path with `forMainFrameOnly:NO`. No frame walking, frame-targeted reinjection, MutationObserver, polling interval, RAF loop, or web scroll listener is active.

FULL, VIEWPORT, and TRANSITION probe identities are bumped to v7.443. Device visual verification of the standalone ads remains pending; this build should be judged from the same top standalone-ad screenshot/probes used for v7.441/v7.442.
