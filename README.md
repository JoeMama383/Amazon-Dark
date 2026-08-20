# AmazonDark v6.0.163 — hook instrumentation

Built on **v6.0.159** (`a8957c0`), not on HEAD. 6.0.160 and 6.0.161 are excluded
deliberately: 161 re-touches the Dark Reader ownership boundary that 159 restored, and
159 is the stable rendering baseline.

This build changes no rendering behaviour. Its only purpose is to find out where the
native time actually goes.

## Why this and not another optimization pass

The web side is already near the floor: 3 MutationObservers, 0 intervals, 0 RAF loops,
0 scroll listeners, 17 one-shot timeouts. Source-tree size costs nothing at runtime.
Meanwhile this tree hooks **94 methods across 46 classes, 57 of them on UIKit and Core
Animation hot paths** — including `-[CALayer setContents:]` and
`-[CALayer setBackgroundColor:]`, which run on every commit, every scroll frame and
every image decode completion, and `layoutSubviews` on 19 classes. The file also
contains 71 `objc_getAssociatedObject` and 76 `objc_setAssociatedObject` calls;
association lookups take a global lock.

The stock app does none of this, which is the most plausible remaining explanation for
the gap. But "plausible" is exactly what Dark Reader throttling and the iframe payload
split were, and both were wrong. So this measures instead of assuming.

## What was added

All 57 hot-path hooks accumulate a call count and inclusive wall time. Instrumentation
uses a cleanup-attribute scope guard, so every early return is covered without editing
any return path. Per call: two relaxed atomic adds and two `mach_absolute_time` reads —
far below the association lookups and class-name walks these hooks already do.

The table is written on every `UIApplicationWillResignActive` and truncated at launch,
so one session stands alone and backgrounding twice appends two tables. The destination
is resolved by really writing a test file to each candidate, so a sandbox denial cannot
fail silently, and the chosen path is printed in the header.

## Reading the dump

`AmazonDark-hook-perf-163.txt`, sorted by call count, plus a list of hooks that never
fired at all.

**Time is inclusive of `%orig`**, so it contains the real UIKit work as well as ours.
Rank primarily by count. Compare inclusive time only between hooks wrapping the same
underlying method. The `never fired` list is immediately actionable: those hooks can be
deleted outright.

## Verification

- All six injected JS payloads are **byte-identical to v6.0.159** — the web path is
  untouched.
- Counter core compiles clean under clang.
- String/comment-aware whole-file brace, paren and bracket balance: 0/0/0.
- `scripts/lint-logos.sh`.
