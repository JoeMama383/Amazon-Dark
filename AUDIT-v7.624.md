# Post-v7.605 UI text audit: focus v7.620–v7.624

| Area and implementation | Scope / owner | Black/neutral text path | Audit finding |
| --- | --- | --- | --- |
| Alexa plus-menu (v7.622 -> v7.624) | Native `plus-menu-modal-container` and two mode-button IDs (r4) | Native `RCTTextView` storage; v7.624 now repaints at mount and `drawRect:` | **Concrete regression identified and repaired in source.** Saturated blue New badge preserved; on-device output unverified. |
| Microphone permission (v7.622) | Native `sheet-view` only when both `allowTitle` and `actionButton` exist (r3) | `ADAlexaText7622` neutral text conversion plus v7.624 post-mount text owner | Text lifecycle now covered by same scoped owner, no global UI overrides. |
| Your Orders details (v7.620) | WebKit `.od-modernized .od-container` from FULL r1 | Neutral text white CSS; authored status/link colors excluded | Source path retained; no new dark text regression seen in source; runtime not re-probed. |
| Advertising Preferences (v7.620) | WebKit `#mobileDataDeleteButton` + `#mobileAdPreferenceButton`, r2/r5/r6 | Neutral copy white, legal links currentColor | Owner mismatch fixed earlier; source retained; runtime unverified. |
| Orders recommendations and shipping sheet (v7.621) | Exact recommendations widget and `#changeShippingAddressPreloadContent`, r1/r2 | Price/delivery and address copy white, selected blue border excluded | Source retained; on-device not re-probed. |
| Alexa editorial page / Feedback (v7.622) | Octopus content-grid / feedback form semantic markers (r5/r1) | Neutral editorial and feedback copy white; blue links preserved | Scoped CSS present, but feedback cross-origin modal DOM not fully captured; not visually verified. |
| Your Saves legacy filters (v7.611) | `#ys-filters-scroller` | White foreground exists; **legacy gray `#303335` button floor remains** | Separate pre-v7.620 contract conflicting with current strict no-gray-floors preference. Not changed in this final-paint fix to avoid unprobed broad redesign. |

**Probe capture limitation:** v7.623 screenshot-triggered `FULL` r1 supplied alongside this report recorded a Search results page (`#s-all-filters`, `scrollY=1250`, one WKWebView), **not** the open native Alexa plus-menu. Therefore it is not proof of this modal's FULL coverage. Exact native r4 owner is from `Archive(20261010-172201).zip`, October 10 13:16:37.

**Hard requirement** now recorded in `THEMING-CONTRACT.md`: neutral black/dark text must render white on OLED; gray may remain only legibly secondary and as original borders/dividers; preserve semantic colors and authored geometry. Source assertions do not prove the installed app paints correctly.
