# v7.644 validation

Validated 2026-10-19 against the v7.643 source base. This is a source release for the existing GitHub Actions/Theos build workflow; no linked, signed, or installed device package was produced here.

## Results

| Check | Result |
|---|---|
| Strict source validation | PASS — all 308 regression programs, Logos lint, version synchronization, generated-source parity and package-script permissions |
| Native syntax | PASS — Logos preprocessing and Objective-C++/Objective-C syntax for AmazonDark, AmazonDarkSB, ADPrefs and ADSponsored; arm64, iOS 16.5 SDK, iOS 17 target, gnu++98 |
| Existing theme contracts | PASS — frozen prior payloads and CSS remain identical after only the specifically enumerated runtime-guard, wrapper, version and JSON-encoding changes |
| WebKit paint/geometry comparison | PASS — 60 fixture controls, normal and focused, on 10 routes; 1,200 control/state comparisons |
| Other-route stylesheet preservation | PASS — complete stylesheet text matches the previous implementation on Home, Interests, Live, Cart, Thank-you, Orders, Addresses and Returns, with release comments normalized |
| Search/product theme startup | PASS — the 50 tested theme programs made zero selector scans, broad tag walks, computed-style reads, geometry reads, innerText reads, MutationObserver registrations or owned STYLE-node insertions through document-ready/load |
| Constructed delivery | PASS — stable sheet identity, unchanged-content deduplication, original owned sheet order, app-sheet exclusion, and unsupported-API fallback |
| Isolation restoration | PASS — Search and product routes, normal/full/core/follow-up modes; every restored CSS rule and computed paint matches the corresponding normal run |
| Diagnostic handoff | PASS — FULL, VIEWPORT, TRANSITION and PERFORMANCE helper/version/export contracts; constructed sheet inventory included in performance records |

The full-isolation fixtures withheld 37 Search sheets and 41 product sheets, with zero residual rules or adopted sheets in those synthetic documents before restoration. All restored without failures. Unit checks also cover `textContent +=` during isolation and restoration of earlier sheets after later sheets are already active.

Native compilation still reports five inherited ARC retain-cycle warnings in the optional universal UI probe. There were no syntax errors. This was not a native link, signing, install, or launch test.

## Scope and limits

- The WebKit fixtures execute the actual generated theme programs with the production source wrappers. They do not reproduce every Amazon network response, private native implementation, optional privacy module, or complete user session. They establish fixture equivalence, not complete device screenshot equivalence.
- Source census counts describe occurrences, not runtime cost. The ordinary production MutationObserver count is zero. Non-Search/product legacy one-shot classifiers and component shadow hooks remain and are listed explicitly in the source audit.
- No before/after device latency result exists for v7.644. The v7.643 normal and CSS-isolation captures were separate runs, both containing substantial stalls; neither identifies the root cause conclusively. Browser fixture timing is not presented as a phone benchmark.
- Install the package from a passing CI run, then use the normal PERFORMANCE arm/export commands in `COMMANDS.md` to measure fresh Search entry and immediate product-gallery swipes. Explicit `arm styles` intentionally forces expensive style work and is unsuitable for that normal latency comparison.

The source tree includes the strict regression programs and the generated-source consistency check. The `validation/v7.644/` files record the synthetic browser results and the static source census; no private capture or screenshot is included there.
