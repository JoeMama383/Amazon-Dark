# v7.522 review

Base: 19f38b70 (v7.521).

The supplied Person r1 capture shows yr_item_0 at 292x69.3 with 12-point radius and 1-point authored border. Its transparent inner plane is now correct. That plane still reserves a 60-point thumbnail column before the 230-point text column. The text wrapper starts at local x=66 and is 225 points wide. Thus the label is offset by the reserved column; the corner repair did not change the frame.

The patch measures the existing text renderer using its NSLayoutManager used rect and centers that glyph rect in the card by moving only the text wrapper horizontally. It preserves text size/attributes, vertical position, card dimensions, border radius/width, and carousel spacing. Exact component IDs and yr_item ancestry constrain the change. Existing mount/layout and both React text-storage commit hooks reapply it after hydration. Each correction recomputes from current coordinates, preventing accumulated drift.

The probe completes seven steps through offset 2321, restores zero and reports completed. Snapshot durations are 375–526 ms; no new probe scheduling changes are included here.

Validation: Logos lint and diff checks pass. The new compiled geometry regression verifies centering and repeated-call idempotence. Full normalized results: see VALIDATION-v7.522.md. iOS compilation and visual verification still require CI/device.
