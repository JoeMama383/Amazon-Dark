# AmazonDark v7.546 — WebKit editing trait repair

Baseline: successful v7.545 (63a8dff1).

The v7.543 and v7.544 device captures show a Light WKContentView responder alongside Dark keyboard windows and effective text-input traits. This release aligns that responder's native appearance before it becomes first responder. It preserves subsequent app style requests for restoration after editing, releases the override after successful resignation or failed focus acquisition, and does not change geometry or introduce scanning/timers.

This is a targeted repair candidate, not a device-confirmed resolution. The retained transition probe now distinguishes an exact stored keyboardAppearance scalar (when available) from values returned through our existing getter override. See REVIEW-v7.546.md, VALIDATION-v7.546.md and COMMANDS.md.
