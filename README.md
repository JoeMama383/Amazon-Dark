## v7.553 — exact Filters owners + obsolete Tweak size-gate removal

Direct source baseline: reconstructed v7.550 tree.

v7.553 replaces the non-matching generic Filters selectors with the exact owners captured by the v7.548 FULL probe: `#dropdown-content-s-all-filters`, `.sf-filters-vtabs-tabs-container`, `.s-vtabs-contents-container`, `.sf-bottom-nav.sf-bottom-nav-current`, and `.sf-show-results`. Right-side option controls are medium gray with gray borders; the left rail keeps its subtle tint and one right divider; the footer top/bottom dividers are removed; and Show results is OLED black with white text and a gray border.

The arbitrary monolithic `Tweak.xm` source-size assertions inherited by v7.550 are retired rather than forcing another runtime refactor. Independent probe/SpringBoard helper guardrails are left alone. The v7.550 App Settings and About You behavior remains in-tree; the malformed C-string encoding in the v7.550 filter/About You CSS tail is repaired so the payload can compile and parse.
