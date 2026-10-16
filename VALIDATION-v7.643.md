# v7.643 validation

## Completed checks

- Strict `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: PASS, Logos lint and all 307 Python regressions.
- ARM64/iOS 17 syntax checks with the cached iPhoneOS 16.5 SDK: PASS for Tweak, SpringBoard companion, preferences and sponsored module. The same five inherited UI-probe retain-cycle warnings remain. This was not a linked Theos DEB build.
- Local WebKit normal-mode comparison with v7.642: 60 representative shared-control nodes on each of ten routes, normal and focused states. Sampled paint and geometry match. All eight non-Search/product routes also retain their complete CSS source apart from version strings; adopted sheets match.
- Existing review-owner lifecycle test now verifies the callback is timed when armed, still performs its state update, and stops recording after the recorder is removed. It retains one observer and suppresses redundant attribute writes.
- New isolation regression checks normal/child/non-hot/late-page exclusion, three partitions, repeated assignments, exact latest-value restoration, deadline, the 128-style cap, restoration after an individual failure, native field handling and invalid/incomplete report warnings.
- JavaScript source/include parity is checked by the regression suite. The short push helper parses with `sh -n`.

## Real stylesheet isolation in local WebKit

The fixture executes all 50 extracted production programs during document parsing, before stock fixture controls are inserted. This exercises the actual stylesheet assignments and existing route transformations. A normal armed run supplies the restoration comparison. These are functionality checks, not performance benchmarks or physical-phone results.

| Route | Mode | Intercepted STYLE elements | Retained theme rules before restore | Restored |
| --- | --- | ---: | ---: | ---: |
| Search | Normal | 0 | 694 | 0 |
| Search | All CSS | 37 | 0 | 37 |
| Search | Base CSS | 1 | 471 | 1 |
| Search | Follow-up CSS | 36 | 223 | 36 |
| Product | Normal | 0 | 732 | 0 |
| Product | All CSS | 41 | 0 | 41 |
| Product | Base CSS | 1 | 654 | 1 |
| Product | Follow-up CSS | 40 | 78 | 40 |

All isolated assignments restore without errors, and sampled restored paint matches the normal run in every mode. Both all-CSS runs have zero retained theme rules beyond the single diagnostic root-floor rule, and zero adopted sheets. The local rule counts are not presented as exhaustive inventories of every possible Amazon page.

The first isolation test found 40 residual rules from the Orders/ad-preferences module. Its separate `style.textContent` assignment is now covered by the source wrapper; the final results above include this correction.

## Limits and required next evidence

The v7.642 phone capture confirms persistent delays. No v7.643 phone result or successful linked package is available here. The source must pass the GitHub Actions package build and be installed before testing.

Record a normal armed v7.643 Search → product → gallery session, export it, then run the same interactions in a separate `isolate-css` session on fresh documents. An already-loaded page, missing final inventory, or residual styles cannot establish successful isolation. Do not overlap FULL, VIEWPORT or TRANSITION with these performance sessions. Do not use the older forced-recalculation `arm styles` experiment for ordinary latency comparisons.

The control removes intercepted theme CSS only. Native hooks and theme/page JavaScript still run. Restoring styles cannot preempt a blocked WebContent thread. These limits are explicit in the report rather than interpreted as zero cost or a successful fix.
