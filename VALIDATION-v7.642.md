# v7.642 validation

## Performance evidence

The final local WebKit test progressively inserts 220 synthetic product tiles in batches of ten and forces layout after each batch. The new observer is enabled and mutation microtasks are delivered before timing ends. Four alternating runs per variant and route compare the same v7.641 stylesheet set with the production review ownership transformation. Sampled tile paint and geometry are equal.

| Route | v7.641 median total | Candidate median total | Reduction |
| --- | ---: | ---: | ---: |
| Search | 629 ms | 486.5 ms | 22.7% |
| Product | 1032.5 ms | 918 ms | 11.1% |

These are synthetic construction/rendering totals, not on-device input latency. Individual runs vary. No claim is made that the remaining phone delay is cured.

## Compatibility

- Ten-route production-program comparison: 60 representative shared-control nodes per route, normal and focused states. Paint and geometry match v7.641. All eight non-hot routes retain their full CSS source, apart from version strings.
- Review-specific WebKit comparison: 22 nodes, ten paint/geometry properties, eight states including no review owner, late owner assignment, product-root presence/removal, alternate review owner, owner removal, late subtree insertion, and body replacement. The candidate's live updates match the freshly evaluated authored CSS in all states.
- The local WebKit engine retained stale native `:has()` styling after pure ID renames in the original stylesheet. The compatibility oracle therefore reinstalls the original stylesheet for each state; the candidate must update dynamically without reinstalling it. This tests selector semantics rather than reproducing stale paint.
- Node regression verifies unchanged-state write suppression over 1000 deliveries, only one observer after repeated sheet installation, ID changes, body replacement, route/child-frame isolation, and native-CSS fallback.

## Build checks

- Strict `scripts/validate.sh`: PASS, all 306 Python regressions and Logos lint.
- ARM64/iOS 17 syntax checks with the iPhoneOS 16.5 SDK: PASS for Tweak, SpringBoard companion, preferences and sponsored module. Five inherited UI-probe retain-cycle warnings remain; no new compile errors.
- Production source audit now explicitly counts one review ownership observer, with no timers, layout reads or DOM traversal in that observer. The regression budget permits exactly one, rather than concealing it as a diagnostic.

A linked DEB and physical-device latency validation require the user's GitHub Actions build and phone.
