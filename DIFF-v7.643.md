# v7.643 — startup isolation and missing callback attribution

Base: v7.642-review-owner-cache. This is a diagnostic build, not a verified production latency fix.

## What the v7.642 phone capture proves

The 72.4-second normal capture contains seven web-document instances, no injection errors, no dropped records and no overlapping UI/transition probe.

| Main document | Mean input event to next animation callback | Maximum | Maximum event-loop lag | DOM interactive |
| --- | ---: | ---: | ---: | ---: |
| Search | 970 ms | 3,251 ms | 3,488 ms | 18,089 ms |
| Product | 2,521 ms | 11,435 ms | 11,567 ms | 43,394 ms |

Native event dispatch peaked at 37.5 ms. A native runloop gap reached 614.2 ms, so native work is not claimed to be entirely stall-free. The substantially larger web delays remain unexplained by the measured theme installs (27 ms Search, 25 ms product). Install timing does not include later browser style/layout/paint work. Only resource PerformanceObserver entries were supported on this capture; no browser long-task or event-timing attribution was available.

The earlier synthetic CSS improvements were insufficient evidence of an on-phone fix. This capture also exposed a measurement gap: the v7.642 review ownership MutationObserver callback was outside the timed listener wrapper. Cheap recorded callbacks could therefore not rule out that callback's work.

## Changes

- Adds timing around the existing review ownership callback while a performance recorder is armed. It retains the same observer and lookup logic; there is no second observer.
- Adds `arm isolate-css`, `arm isolate-core`, and `arm isolate-followups`. On new main Search/product documents only, selected AmazonDark stylesheet assignments are withheld before the styles enter the document. Normal mode keeps all production styles.
- The control keeps one simple black root-floor rule. It deliberately does not reproduce the full theme, so stock panels or images may appear during an isolation session. This is not a proposed replacement UI.
- Each intercepted STYLE object keeps its latest exact assignment, with a cap of 128 objects. Session stop, pagehide, or the existing 90-second deadline restores these assignments. No new timer, polling loop, DOM walk or browser-prototype hook is added by the isolation helper.
- Reports requested mode, eligibility, late documents, intercepted styles, residual theme rules/adopted sheets, failures and restoration. Missing final inventory is reported as unconfirmed, never zero. All-CSS isolation with residual rules is explicitly incomplete.
- Includes the authored `style.textContent` assignment used by the Orders/ad-preferences module in the existing source wrapper. Without this, its 40 rules survived an apparent all-CSS isolation run. Normal declaration values are unchanged.
- Updates all three probe helpers' shared export destination to the user's new phone Documents folder.
- Adds a short `push-source.sh` helper for the existing phone clone. It verifies the source version, removes only the two known obsolete scanner files, validates, commits changed source and pushes `origin main`.

## What this can and cannot establish

A fresh Search/product capture with substantially lower delay while all intercepted theme CSS is absent would implicate CSS or its interaction with page loading. It would not yet identify an individual selector or justify discarding the theme. Base/follow-up partitions can narrow that result.

If the same delay remains with verified CSS isolation, native hooks, theme JavaScript and their interactions remain candidates. The recorder does not remove those components and cannot independently measure internal WebKit style/layout/paint stacks.

Already-loaded pages cannot measure the counterfactual startup, and are intentionally left alone. A one-second native finalization grace may miss the last web response when WebContent is blocked; the report marks a missing final inventory as unconfirmed. Restoration itself executes when WebContent can run the queued stop or deadline; it cannot preempt a blocked thread.

No physical-device result for v7.643 is available yet. See COMMANDS.md for separate normal and isolation sessions, and VALIDATION-v7.643.md for the local checks.
