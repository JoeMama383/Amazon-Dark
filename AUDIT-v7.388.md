# AmazonDark v7.388 optimization audit

## Baseline and release

Direct parent: `AmazonDark-v7.387-runtime-css-optimization-source.zip`, SHA-256
`4852812538c39cd8284e5ee2e056d02118c9b57bb9cdf5a91b3755173f4b43e5`.
Release: `7.388~native-work-optimization`. No GitHub API or push was performed.
The shipped source archive contains the complete project and existing build workflow.

## Implemented optimizations

- **Selective preference refreshes.** A small C planner compares the previous and
  current effective settings. Duplicate notifications, relaunch-only sponsored/
  price-history options, inactive TWB strength changes, and equivalent clamped
  strengths cause no runtime refresh. Enabling refreshes web floors; effective
  120 Hz changes refresh promotion state; effective TWB changes refresh loaded
  main documents; effective privacy changes refresh its content rules and wrappers.
  Disabling and re-enabling active options still trigger their required cleanup/
  setup. The complete callback retains its main-thread handoff.
- **Privacy protocol setup.** Both configuration installation and the hooked
  protocolClasses setter check the original array before copying. Existing
  installation is reused; insertion still prepends the same protocol class at
  index zero. The disabled path and nine filtering rules are preserved.
- **Search native ownership.** The GlowIngress subview hook ignores only our own
  tagged backing insertion after calling Amazon's original method. That insertion
  no longer starts a nested ownership pass. Geometry, hidden/alpha, ownership,
  glyph tint and plain-label color writes skip already-correct values. Labels with
  attributed text still receive the original color write. The sole floor-tree
  caller reuses its successful exact-root classification instead of checking the
  same root/window geometry twice. Both 96-view traversal budgets and all real
  mount/layout/subview events remain.
- **Checkout appearances.** Read current appearance properties before copying or
  rebuilding. The guard checks opaque black background, absent effects/images,
  clear shadow, title/large-title ink, and normal/highlighted/disabled/focused text
  dictionaries for plain, back and Done buttons. A later app-authored property
  change invalidates the guard automatically; there is no permanent themed flag
  or retained appearance cache. All four appearance slots and existing prepaint/
  setter hooks remain. No navigation-bar layout hook is added.
- **Small ancestry simplification.** The identical Home visual-category ancestor
  walks now share one implementation. React classification reuses the identifier
  already read for that ancestor. Existing miss behavior and cache invalidation
  remain, preserving delayed identification and hierarchy changes.

## Bugs corrected

1. **Search self-triggering:** inserting the tweak's own backing into GlowIngress
   synchronously invokes didAddSubview and previously started another bounded
   theme pass. The sentinel guard removes that recursive work.
2. **Checkout transaction cleanup:** an exception after CATransaction begin could
   leave the transaction open. Commit now runs in finally, and the prior internal
   write flag is restored instead of unconditionally clearing nested state.
3. **Viewport package gate:** v7.387's UI helper still required installed package
   `7.386~*`. It now derives names, acceptance and messages from its single version
   variable. It accepts v7.388 and rejects older packages before signalling.
4. **Unarmed status:** the UI helper could return failure when no viewport arm was
   present. Status now succeeds for a normal unarmed app. Current and immediately
   previous v7.387/v7.386 receipts are usable for upgrade discovery.
5. **Probe metadata:** UI JavaScript capture-version fields now report v7.388;
   package, native receipt paths and helper versions agree. Capture behavior is
   unchanged.

## Measurements and verification

| Measure | v7.387 | v7.388 |
| --- | ---: | ---: |
| Main tweak fat dylib, bytes | 1,513,280 | 1,513,280 |
| SpringBoard fat dylib, bytes | 169,232 | 169,232 |
| Four production source files, bytes | 617,584 | 620,993 |
| Default installed programs at TWB 45, UTF-8 bytes | 151,581 | 151,581 |
| All features at TWB 45, UTF-8 bytes | 183,817 | 183,817 |
| Regression scripts | 41 | 43 |

The additional guards add 3,409 source bytes (0.55%); the linked fat binary size
is unchanged. This release targets avoidable execution and allocation work.
It does not claim an additional code-size reduction, a measured percentage speedup,
or parity with stock Amazon performance. Binary comparison uses the previous
recorded build and this build with the same local Clang 11.1, SDK, architectures
and release flags; Mach-O layout/alignment is included in file size.

Validation completed:

- All **43 Python regression scripts** pass under strict validation, including
  Logos lint, native/source contracts, compiled helpers and Node execution.
- The actual production C preference planner is compiled and executed against
  duplicate notifications, independent toggles, effective disable/re-enable,
  relaunch-only settings and clamped strengths.
- The actual UI helper arms a disposable SIGUSR2 receiver, writes the right
  permission/path, rejects mismatched packages, discovers upgrade receipts,
  handles unarmed status, and exports only completed full/viewport files.
  This does not simulate Amazon or assert a successful UIKit capture.
- Eleven native function contracts are recorded from the unchanged v7.387 ZIP.
  The original checkout transformation, Search geometry/color predicates,
  controller prepaint and privacy filter definitions remain, with only the
  documented fast-path/identifier changes normalized in their comparisons.
- Every production JavaScript program is byte-identical to v7.387 at TWB strengths
  0, 45 and 100; ADSponsored.m is byte-identical. All 86 sponsored selector pairs
  retain their previous order/specificity/declarations. Existing v7.386 semantic
  goldens remain enforced.
- Universal probe JavaScript differs only in its two capture-version fields;
  skeleton JavaScript is byte-identical. Native probe code differs only in release
  identifiers. Cold-launch/switcher policy regression checks pass.
- After restoring missing tracked links in the local Theos/SDK dependencies,
  a clean-source local build compiled and linked arm64 and arm64e, including the
  preference bundle. The compiler emits the existing arm64e ABI warning and the
  existing finite full-probe block-retention warnings. GitHub Actions' macOS build
  is required for the installable device package; no local .deb is shipped.

## Preserved behavior and remaining limits

Amazon HTTP caches, request cache policies, WebKit data stores and process pools
are untouched. Existing optional privacy filtering stays scoped to its prior rules.
No new timers, observers, scroll scanners or recurring JavaScript are introduced.
No on-device FPS, launch time, memory, battery or cache hit-rate measurement was
available. Source/semantic checks do not replace testing Amazon's live renderers.

The previously discussed consolidation of Search's two traversal phases is not
included: insertion order and bounded coverage can affect delayed content. Nor is
persistent caching of React classification misses added, because the source alone
cannot prove complete invalidation when ancestor identity changes. Both remain
candidates for a device-profiled follow-up, rather than claimed completed changes.

## Phone checks

Install the v7.388 Actions package and open Amazon once. Check Search immediately
and after delayed content appears, including glyph tint and its delivery bar. Open
checkout from a fresh presentation and verify the black header and Done control
through the transition. Exercise TWB and privacy off/on plus TWB strength, with
other settings held constant. Verify ordinary cold/warm launch, Cart, Person and
Alexa. A screenshot still triggers the universal full sweep; ui-probe.sh arm
captures the visible viewport. See COMMANDS.md for both export and transition
commands. Keep capture unarmed when comparing normal runtime performance.
