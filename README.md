# AmazonDark v7.444 — probe-confirmed media fixes

Exact parent: v7.440, not v7.441–v7.443.

- Restore Customers also bought images by removing multiply blending from the exact image-display wrapper. The probe shows completed 210x210 images, normal leaf blending, but multiply on the wrapper against black.
- Apply the existing configurable image-taming strength to those images and From the brand images. Dim the portrait background artwork using background blending, so live text and controls are not dimmed with a whole-container filter.
- Advance FULL, VIEWPORT and TRANSITION identities and export/package guards.

Still unresolved: white medium ad internals; duplicate border within another embedded ad; compact top-ad title and info glyph; light search-to-product transition. All supplied v7.440 UI captures lack CROSS_FRAME_DOM. The transition tar is a historical export, newest actual transition recordings v7.433, despite its v7.443 archive name. No current transition fix is claimed.

Runtime: only additions to two existing stylesheets; no additional scripts, observers, callbacks, frame walks, scans or timers. The inherited v7.440 frame-ownership implementation is unchanged; this release does not claim that the entire parent is walker-free or stock-performance verified.

Build/install through your existing Actions workflow. See COMMANDS.md. On-device visual acceptance is required.
