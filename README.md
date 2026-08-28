# AmazonDark v7.146 — performance compaction

Production compaction built directly from v7.145. Visual and functional fixes are retained, including the Search video/More-like-this repair. Probe-only runtime, dead SpringBoard launch-window code, and Privacy diagnostic bookkeeping were removed. Hot-path constant colors/TWB paint are cached and duplicate UIImageView classification passes are eliminated.

No Dark Reader, MutationObserver, interval, RAF loop, scroll listener, or recurring DOM scanner is added. This production build intentionally ships no manual probe.
