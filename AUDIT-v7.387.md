# AmazonDark v7.387 optimization audit

## Baseline and scope

The input is the uploaded `AmazonDark-v7.386-sponsored-shell-ownership-source(1).zip`.
No GitHub API was used and nothing was pushed. `SOURCE-BASELINE.json` records the
actual input hashes. This release is `7.387~runtime-css-optimization`.

The audit covered document-start payloads, CSS ownership/cascade, script installation,
settings refresh, privacy transport hooks, native setters/layout/text/image paths,
SpringBoard artwork, and retained probes. A lexical cross-reference pass covered
394 native static functions before edits. It found no obvious unreferenced static
function definitions; arbitrary deletion of theme owners would remove behavior.

## Implemented changes

1. **Compact existing CSS without changing its selectors.** Remove 11,811 bytes of
   immediately redundant `background-color`/`background-image:none` declarations
   after an identical, color-only `background:…!important` shorthand in the main
   and isolated checkout programs. The shorthand already sets those longhands.
   Rule order, specificity, priorities, colors, geometry and image filters remain
   unchanged. No runtime CSS minifier or DOM classifier is introduced.
2. **Combine adjacent simple sponsored rules.** Their identical collapse declarations
   are emitted once per comma list. All 86 original selectors remain, in the same
   order and with their original individual specificity. Every relational `:has()`
   rule remains separate, preserving rejection isolation and the two v7.386 shell
   owners. CSS shrinks from 26,675 to 13,053 bytes; 86 rules become 33 rules.
3. **Remove the obsolete Home-only diagnostic bridge.** Its 6,053-byte program and
   message listener were still installed in every frame, but the current source had
   no caller of its request/snapshot API. The universal full/viewport probes and
   transition recorder have their own capture paths. Their JavaScript payloads are
   byte-identical to v7.386.
4. **Share immutable WKUserScript objects.** A bounded eight-slot cache retains one
   current program per script family. Only strength-dependent programs are rebuilt
   when TWB strength changes. The cache retains no controllers or webviews. Existing
   document-start order, main/all-frame flags and checkout isolation are preserved.
5. **Reuse WebKit's persisted privacy rule list.** Look up the existing versioned
   `AmazonDarkPrivacy7118` list and compile only on a cache miss. The nine blocking
   rules are unchanged. Disabled fetch/beacon wrappers now pass through before
   allocating URL metadata.
6. **Reduce native work.** Search attributed text reuses the existing idempotent
   painter, avoiding copies when it is already correct. Overlay layout writes occur
   only when bounds/corner radius changed. SpringBoard diagnostic formatting and
   diagnostic metadata getters run only while the launch probe is armed.

## Confirmed bugs corrected

- **Unbounded BYG recovery if sessionStorage fails:** the old code called
  `location.reload()` even when it could not persist the one-shot receipt. It now
  requires a successful, verified write before reloading. The existing narrow
  one-sparse-card signature is unchanged. If storage is unavailable, it safely
  leaves that recovery inactive; it does not fabricate an Add to Cart control.
- **Checkout TWB left behind by settings changes:** the main-document refresh now
  updates the isolated checkout TWB program too, and disabling TWB removes its
  stylesheet along with the other TWB styles. Existing all-frame document-start
  coverage still applies after relaunch; this is not a claim of live updates to
  already-loaded cross-origin child frames.
- **Stale installation receipts after clearing scripts while disabled:** every
  AmazonDark user-script receipt is now invalidated after `removeAllUserScripts`,
  regardless of the enabled flag. Reattachment is still enabled-only.
- **Settings callback thread affinity:** the complete callback, including WebKit
  operations and cache updates, now hands off to main when invoked off-main.
- **Handoff metadata:** current package/probe identities, receipt acceptance,
  source provenance and push commit/temp-directory names now agree on v7.387.

## Measured reductions

| Measure | v7.386 | v7.387 | Reduction |
| --- | ---: | ---: | ---: |
| Main document-start core, UTF-8 bytes | 153,027 | 136,472 | 10.8% |
| Default installed programs, UTF-8 bytes | 169,397 | 151,581 | 10.5% |
| All features enabled, UTF-8 bytes | 215,176 | 183,817 | 14.6% |
| Sponsored CSS bytes | 26,675 | 13,053 | 51.1% |
| Main tweak fat dylib bytes | 1,579,056 | 1,513,280 | 4.2% |
| SpringBoard fat dylib bytes | 169,232 | 169,232 | 0.0% |
| Four production source files, bytes | 648,375 | 617,584 | 4.7% |

Program sizes use TWB strength 45 and exclude explicitly armed diagnostic programs;
all-features totals include the optional main-frame-only price-history program.
The existing standalone program remains installed as in the baseline. Binary
measurements use the same local Clang 11.1, iOS 16.5 SDK, architectures and release
flags. They do not measure WebContent RSS, selector-matching time or frame rate.
Removing duplicate declarations reduces parsing/storage work; no claim is made
that it speeds up matching of unchanged selectors by the same percentage.

## Verification and limits

- **41 Python regression scripts pass** under `AD_STRICT_VALIDATE=1`, including
  Logos lint, cold-launch policy execution, source embedding/linkage tests,
  handoff/probe tests and executable Node regressions.
- Extracted stylesheets from four route fixtures parse without CSS syntax or
  declaration errors in both versions. This is a parser check, not a browser render.
- Golden contracts derived from the uploaded baseline prove exact main/checkout
  program equivalence after only the documented shorthand substitutions; unchanged
  TWB, standalone, raster bridge and ad-loading programs retain their hashes.
- Expanded sponsored selector/declaration pairs exactly match all 86 baseline
  pairs. This covers scope, order and individual specificity; relational selectors
  remain independent rules.
- Executed BYG fixtures cover healthy/one-sparse/multiple-sparse grids, repeated
  visits, failed reads/writes and silently discarded storage writes. Checkout TWB
  cleanup retains unrelated theme styles. Disabled privacy transport wrappers pass
  through without reading the request URL.
- Clean local compilation and linking succeeded for arm64 and arm64e. The available
  Linux compiler reports an **arm64e ABI compatibility warning**. GitHub Actions'
  current macOS toolchain remains the required device-package build. The local
  `package` stage also lacks a compatible libplist; no installable local .deb is
  being supplied or claimed.
- Existing full-probe self-referential block warnings remain. Their finite finish
  paths clear both block variables; those probe-only routines were preserved.
- Browser policy blocked local rendering tests. No on-device rendering, stock-app
  timing comparison, FPS, battery, cache hit-rate or memory improvement is claimed.
  Existing WebKit data stores, process pools, Amazon HTTP cache policies and cache
  contents are untouched. Visual behavior is protected by source/semantic contracts
  but still needs verification against Amazon's live renderers on the phone.

The theme's image brightness filters and narrow relational selectors remain because
removing them would change current behavior. WebKit already optimizes `:has()`;
replacing those selectors with recurring JavaScript scans would add a new runtime
cost. [WebKit's selector design](https://webkit.org/blog/13096/css-has-pseudo-class/).
The compiled-rule cache uses Apple's existing
[rule-list lookup API](https://developer.apple.com/documentation/webkit/wkcontentruleliststore/lookupcontentrulelist(foridentifier:completionhandler:)).

## Device verification

After the Actions package is installed, compare normal cold/warm launch, Search,
Cart refresh, Person, Alexa and checkout with v7.386 using the same settings.
Check the checkout header/Done control, existing sponsored shell collapse, and
TWB toggles. Keep transition capture disarmed when judging performance. If a visual
regression appears, use the unchanged viewport command and export in `COMMANDS.md`.
