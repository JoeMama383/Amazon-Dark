## v7.555 — Merge exact Filters, App Settings, and Interests fixes

Built from current GitHub commit 9a0a45ce (v7.554), restoring the complete Filters stylesheet block from commit 634ac270 (v7.553). This corrects the omitted merge that caused the v7.553 regression test to fail after the v7.554 overlay.

Filters: medium-gray option containers, white text, gray borders, one continuous vertical rail divider, no footer top/bottom dividers, OLED Show-results button with white text and a gray border. Existing star/Prime artwork and selected blue rail accent are retained.

App Settings and Interests restoration from v7.554 remains present, including document-owned Interests styles during hydration. The source-size ceiling remains removed. All probe identities are regenerated as v7.555.

See COMMANDS.md for existing-clone push and separate FULL, VIEWPORT and TRANSITION commands. Device verification and native build remain pending.
