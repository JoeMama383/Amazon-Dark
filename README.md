## v7.522 — Returns label centering

Centers the existing Returns text wrapper from rendered glyph bounds within its authored card. Reapplies after React layout and text commits. Keeps card geometry, complete corners and existing probes. See COMMANDS.md. Device confirmation pending.

## v7.521 — Returns corners and probe scheduling

The v7.520 r5 Person capture completed seven scroll checkpoints, reached the bottom, and restored offset zero. This patch clears only the square inset content plane occluding `yr_item_0`'s authored rounded border. Direct Returns identities participate in the existing mount/layout/background hydration path. Original container geometry and React border geometry are preserved. Native capture idle yield is 4 ms instead of 10 ms, with the same 32-node/3.5-ms work bound and unchanged hydration waits/data limits. Per-snapshot timings are included. Device confirmation of this patch is pending. See COMMANDS.md.

# AmazonDark v7.521 — FULL route-contract repair + Hamburger deep scan

See REVIEW-v7.521.md for the current delta. COMMANDS.md contains the push workflow and separate FULL, VIEWPORT, and TRANSITION probe commands.
