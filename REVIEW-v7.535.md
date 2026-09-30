# v7.535 — Interests modal OLED paint

Base: remote commit 597e6efb, v7.534. Evidence: supplied v7.534 FULL capture from September 30 and IMG_7387.png.

The FULL probe did capture the modal, including its pseudo-element paint. The top fade belongs to `_bW9ia_content-wrapper_3UjcO::after` (computed gradient). The lower colored glows are the purple/blue `_bW9ia_shape_1xQCn` children of `_bW9ia_shapes-wrapper_9y3QA`. The focused prompt wrapper has both a 1px blue border and a separate 2px solid blue outline. The Update owner `#intp-submit-btn` has an existing 1px border and 100px authored radius, with fill and border both rgb(48,51,51).

The successor rules remove the pseudo-element background image and hide the decorative glow wrapper without removing its layout box. Update receives black fill and gray border color; its inner button planes are transparent. The prompt retains its authored blue border and loses only its extra outline. No dimensions, padding, margins, positions, border widths, or radii are changed. Clear-X artwork and orange sparkle remain untouched.

For the keyboard, the modal and both its textarea and hidden focus input now explicitly request `color-scheme:dark`. This supplies the DOM-side dark appearance alongside the inherited native WKContentView input-trait hooks and OLED keyboard floor. The native hooks are unchanged. The probe does not establish the remote keyboard keycap rendering cause conclusively; first-focus keycap appearance needs device verification. This is a targeted correction, not a claim of confirmed on-device success.

No probe traversal changes, new observers, timers, polling, or recurring scans. All probe exports retain plain TAR and current-session separation.

Validation: see VALIDATION-v7.535.md. After installation, open Interests > Update your Interest with the keyboard on first focus, verify flat background, gray Update contour and one blue input border. Close/reopen and repeat to check focus transitions. A VIEWPORT capture is sufficient for this paint check; FULL and TRANSITION commands are also provided in COMMANDS.md.
