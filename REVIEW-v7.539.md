# v7.539 — keyboard handoff evidence

Baseline: pushed v7.538, commit 288f436c. Diagnostic update, not a confirmed keyboard repair.

The supplied v7.538 transition recorded background at 8.80s, foreground at 9.78s, input focus at 13.77s, Amazon's invisible-focus-input at 15.26s, then textarea focus at 15.54s. All sampled inputs reported a dark color scheme. WKExtendedTextInputTraits was absent; UITextInputTraits was present. The previous 512-record native budget was exhausted at 13.88s, before the critical handoff. Thus the final native appearance change was not captured.

Changes:
- Deduplicate identical per-object/per-phase native trait states before consuming budget. Counts of suppressed duplicates accompany the next changed record.
- Replace lifetime native cap with 512 records per five-second window, still bounded by the existing capture duration and 20MiB writer limit. A burst no longer disables later foreground evidence. Dropped counts and budget-boundary flags are explicit.
- Observe the existing legacy keyboardAppearance getter as well as setter, preserving original return values and arguments. Getter evidence can expose direct field/copy changes that bypass a setter. Thread-local reentrancy guard always clears in @finally.
- Map WebKit trait objects to their WKContentView owner pointer at existing trait getters. This is probe-only and permits correlation with native hierarchy evidence.
- Include additional numeric keyboard configuration and safe focused-element state: input type, readonly/disabled, autocorrect, appearance and related focus target. No typed value, entered text or keycap pixels.
- Keep the existing OLED policy, geometry, FULL/VIEWPORT behavior and plain TAR exports. No new timers, observers or production hierarchy traversal.

Reproduce after installing the CI-built package: arm transition, open Amazon, background and reopen as before, open the Interests editor and allow the keyboard to change. Keep the bad keyboard visible for two seconds, then export from NewTerm. A matching short video remains useful because remote keycap pixels are not visible to this app-local probe.

Validation includes executing the actual portable rolling-budget implementation under C++98 after 10,000 rejected burst events, then at the recorded foreground and focus-handoff times. Existing runtime DOM tests retain deduplication, focus replacement, deadline and cap checks. The transition-payload hashes were deliberately regenerated; production CSS hashes remain unchanged.
