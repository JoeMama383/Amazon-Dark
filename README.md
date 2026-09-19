# AmazonDark v7.424 — Native header OLED fix

Based on the exact v7.423 source handoff; all previous Cart, BYG, Returns and Medical Care fixes are retained.

The FULL r1 probe shows ANXTopNavBackgroundView has a black backing, but still draws an image layer and two gradient layers above it. The transparent subnavigation area exposes that decoration as a tan strip.

The existing exact background-view hook now suppresses its decorative sublayers on mount and after layout, with implicit animations disabled. Search and navigation content are sibling views and are untouched. No timers, observers, global layer hooks or hierarchy scans were added.

FULL, VIEWPORT and TRANSITION probe identities are updated to v7.424. Device confirmation is pending. See COMMANDS.md.
