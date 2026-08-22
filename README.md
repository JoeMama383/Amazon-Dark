# AmazonDark v6.0.208 — web-owner bisect switches

Base: v6.0.185~probe, carrying v6.0.206 and v6.0.207.

## Why switches instead of another fix

Tapping a search result is delayed for seconds while the page is already loaded and
visible. That is the web process main thread being busy, which no native counter can
see — three separate instrumentation attempts produced nothing usable.

Two candidate fixes have since shipped and neither moved it: scoping the unconstrained
`:has()` rules (v6.0.206) and stopping the contrast lane being promoted to a deadline
task (v6.0.207). Both were sound reasoning about real inefficiencies. Neither was the
block.

So this build stops proposing causes and lets the device identify it.

## Using it

Set **one** flag, relaunch Amazon, search, try tapping a result.

    touch /var/mobile/.ad_off_boot      inject nothing at all (no Dark Reader, no CSS)
    touch /var/mobile/.ad_off_symbols   skip the symbols/checkbox script (32KB, 26 qSA, 1 observer)
    touch /var/mobile/.ad_off_twb       skip White Background Taming
    touch /var/mobile/.ad_off_contrast  make __AMZDARK_FIXCONTRAST__ a no-op

Remove with `rm -f` and relaunch. Read once per launch.

Start with `.ad_off_boot` — it halves the search space in one test. If the delay
survives it, nothing injected into the page is responsible and the cause is native or
Amazon's own. If the delay goes, the other three identify which owner.

Each flag costs theming while set. They are diagnostics, not modes.

## Kept from the last two builds

- **v6.0.206** — 16 `:where(div,span,section):has(> …)` instances scoped to
  `[data-component-type=s-search-result]`. Zero unconstrained `:has()` remain.
- **v6.0.207** — PDP and Search schedule the contrast lanes idle-only, so they can no
  longer be promoted to deadline tasks mid-hydration.

Both are real reductions and worth keeping regardless of what the bisect finds.

## Verification

- Bootstrap format specifiers and arguments: 9 and 9, **each verified in position**.
  The first cut placed the new argument at slot 5 when its literal sits at slot 7,
  which would have fed the Dark Reader payload into the wrong slot and corrupted the
  entire bootstrap. Caught and corrected before packaging.
- Declared-before-use audit clean; balance 0/0/0; all payloads parse; lint-logos.
