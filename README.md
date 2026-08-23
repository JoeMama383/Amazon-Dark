# AmazonDark v6.0.214

Back on the 6.x line. The v7 inversion experiment is abandoned.

## State of the performance work

The cause is confirmed on device: **Dark Reader's own MutationObserver**. It re-themes
every node as it arrives, and Search and PDP hydrate continuously, so it ran on the web
process main thread through exactly the window where taps queued. v6.0.211 neutralised
it and the app became fast everywhere — instant product taps, seamless scrolling.

Everything else inside Dark Reader was eliminated first: the stylesheet proxy (v6.0.210,
no speed change), image analysis (already `ignoreImageAnalysis:['*']`), and the theme
object (identical to the fast v5.43.0 build). The native side was never the problem —
instrumented counters measured 285ms across 29,541 calls for a whole session.

Carried forward from v6.0.213:

- observer inert during `enable()`, restored in a `finally`
- stylesheet proxy on — it covers late-arriving sheets and costs nothing
- generated CSS published as a plain stylesheet on settle, so late-arriving nodes are
  themed by the style engine rather than by an observer

## Simplification in this build

The v6.0.208/209 bisect switches are removed entirely — helpers, gates, prefs fields,
prefs reads, the injected page flag and its format argument. They never worked:
v6.0.208 read them from `/var/mobile/.ad_off_*`, which a sandboxed Amazon cannot stat,
and v6.0.209's prefs version still produced no visible change on device. Two mechanisms,
neither demonstrated, both dead weight.

    src/Tweak.xm    466,986 -> 465,674 bytes
    residual references to the switches: 0

## Verification

- Format specifiers re-checked **in position** after removing an argument: 8 and 8, each
  landing on the literal it belongs to. Removing a middle argument without re-verifying
  order is precisely how the Dark Reader payload would end up in the wrong slot.
- Declared-before-use audit clean; balance 0/0/0; all payloads parse; lint-logos.
