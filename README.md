# AmazonDark v6.0.93 probe

## v6.0.93 — automatic search-pane lifecycle snapshot

Diagnostic-only build based directly on v6.0.92/v6.0.90 production behavior. It replaces the unavailable notifyutil and unreliable SIGUSR2 trigger with bounded automatic snapshots on real WK navigation and app foreground lifecycle events. No visual fix or performance rewrite is included.

Probe output inside Amazon's container: `AmazonDark-search-lifecycle-probe-6093.txt`.
