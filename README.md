# AmazonDark v6.0.216 — retry trains and the contrast engine removed

## Scope note

The analysis this build acts on describes a 7.x branch with Dark Reader deleted. This
tree is 6.x: Dark Reader is still present, with its observer inert since v6.0.211. So
the "current" column in that analysis did not describe what was running. The named
bottlenecks were measured against this tree directly before cutting.

## Measured, then cut

**Startup retry trains — present and removed.** Whole-document repairs were armed at:

    sym413            30, 160, 560, 1560, 2600 ms
    stockCheckbox434  40, 180, 700, 1800 ms

Nine document-wide passes spread across the first 2.6 seconds — exactly the window in
which Search results become tappable. All nine dropped; the immediate pass remains.
`setTimeout` sites in the symbols payload: 11 -> 2.

**The fallback contrast/background engine — present and retired.** Computed-style
inspection plus bounded whole-root walks. Profiling put pathological runs near 806ms and
1.59s, against Dark Reader itself enabling in about 1ms. With no observer left to feed
it incrementally it was a large synchronous pass with no owner.
`__AMZDARK_FIXCONTRAST__` now returns immediately.

**Already gone before this build:** every MutationObserver, ours (v6.0.215) and Dark
Reader's (v6.0.211). Zero live observers, zero scroll listeners, zero intervals, zero
rAF loops in all three payloads.

## Left in place, deliberately

Video control discovery still binds `loadeddata`, `canplay`, `playing`, `play` and
`pause` as individual listeners rather than an array I could retarget in one edit. They
are bounded per video element, not per mutation, so they are orders of magnitude smaller
than what was cut. Doing a delicate multi-site edit as the last change in a build is how
regressions ship; this is worth its own pass.

## Expect gaps

The retry trains existed to catch elements that hydrate late. Without them, and without
observers, anything appearing after the initial pass is themed only if a static selector
matches it. Coverage now comes from the document-start sheet, the Dark Reader fixes
sheet, and Dark Reader's generated CSS published on settle.

Report what renders wrong and each becomes a selector, which costs nothing per mutation.

## Verification

- Retry trains: 0 remaining, confirmed in the emitted payload.
- Live observers 0, scroll 0, interval 0, rAF 0 across all payloads.
- Format specifiers 8 and 2; declared-before-use audit clean; balance 0/0/0; payloads
  parse; lint-logos.
