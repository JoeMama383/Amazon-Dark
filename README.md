# AmazonDark v6.0.169

Fixes the v6.0.168 measurement, which produced no output at all.

## Why 168 recorded nothing

It timed one specific `DarkReader.enable(...)` call site. The enable that actually runs
reaches a different path, so `__ADDRT168__.ms` was never set and the capture returned an
empty string — no `DRCOST` line, which read as "the capture is broken" rather than
"the wrong site was instrumented".

Second defect: `exportGeneratedCSS()` returns a **Promise**. 168 read `.length` off the
Promise, so `cssLen` would have been meaningless even if a line had been written.

## What 169 does

Wraps `DarkReader.enable` itself, once, at bootstrap. Every call site is then covered
whichever one fires, and the wrap is idempotent. The Promise form of
`exportGeneratedCSS()` is resolved properly, with the string form still handled.

Silence is now diagnostic rather than ambiguous. If nothing was recorded, the capture
still writes a line saying so, including whether Dark Reader is present, whether the
wrap installed, and whether the page carries `style.darkreader`:

    DRCOST {"noRecord":1,"hasDR":1,"wrapped":0,"themed":1,"url":"..."}

Negative `cssLen` values are states, not sizes: `-1` export not resolved yet, `-2`
export rejected, `-3` export threw, `-9` field never set.

## What the history says

This problem is not a 6.x regression. At v5.463 the reports were 15+ second tap delays
and a frozen PDP carousel — the same failure, two major versions back. Every theory
since has been tested and dropped: Dark Reader throttling, the iframe payload split,
and native hook trimming. v5.43.0 fails the heavy PDP section too, so that section is
not something 6.x broke.

The one constant across every version, and the one thing never addressed, is Dark
Reader's initial theming pass. Deferring it was proposed at v5.463 and never built.
This build measures it.

## Verification

- Wrapper tested behaviourally in node: timing recorded, Promise CSS captured
  (90,000 chars), wrap flag set, second call does not double-wrap. 4/4.
- All payloads parse; both fixes-literal variants parse.
- Balance 0/0/0; declared-before-use audit clean; `scripts/lint-logos.sh`.
