# v7.337 launch correction and regression audit

Date: 2026-09-05. Audience: AmazonDark source handoff and device verification.

## Outcome and identity

The supplied NewTerm screenshot `IMG_6369.png` identifies the installed package as `7.332~process-scoped-ready-continuity`. The previously checked archive identifies itself as `7.332~v7307-launch-image-correction`. Equal numeric versions did not identify equal source. The new handoff uses the distinct full version `7.337~v7307-stock-timing-cold-artwork` in package metadata and the SpringBoard constructor probe.

The direct baseline is [v7.307, commit 4bbbbd9](https://github.com/JoeMama383/Amazon-Dark/commit/4bbbbd9ae7c5dc0a9d4dc1455235da3feeb706f7). No newer GitHub/other-chat UI branch or process-scoped cover implementation is used as its base. Existing 7.330/7.334/7.336 artifacts were inspected only to reconcile the supplied event signatures; their code is not imported.

## What the probes establish

| Same-thread evidence | Finding | Limit |
|---|---|---|
| PID 8202 posts ready at `810297574.499669`; later `810297651.124934` says `pid=8202 running=1 liveScenes=0 ... cover=1` | Temporary absence of a SpringBoard presentation view is being treated as a cold process launch. | A view's lifetime is not the process's lifetime. |
| `ready.listener.tentative` binds again to PID 8202; `overlay.hardcap` follows with `elapsed=20.248` | The cover waits for an already-consumed one-shot ready event, then removes itself without animation. The source's `ADPostReadyOnce` confirms the once-per-process contract. | This explains the displayed delay, not an actual 20-second Amazon load. |
| A subsequent tap says `cover=0`, but a replacement scene immediately receives generation 3's overlay | A warm decision does not cancel an already-active cover generation. | Explains persistence across view replacement. |
| Earlier PID 11997 sequences have the same false-cold arm and 20-second cap | The latest failure is a repeated state-machine regression. | No new timer value resolves incorrect ownership. |
| v7.326 expired arm; v7.327 process callback about 648 ms after scene creation; v7.328 old PID ready dismisses a new launch before its constructor | Cold/warm inference, callback timing and cross-process readiness each failed independently. | `overlay.attach`, especially with `win=0`, never proves displayed pixels. |
| v7.331 eight `provider=nil launch=0` observations | Requiring provider metadata rejects the actual observed snapshot calls. | These old probes lack content kind/image availability. |

The warm failure slice keeps the same Amazon PID. It does not prove a crash, jetsam or watchdog termination. The user's reports of actual restarts remain a separate, unverified symptom; a matching crash/termination record is required to determine their cause.

## Implemented correction

1. Remove SpringBoard presentation ownership entirely: no `SBSceneView`, icon-tap, process-launch, scene-registry, overlay, ready-listener, minimum-duration, settle-delay, hard-cap or custom-dismissal hook.
2. Reuse the bounded launch-artwork source correction: the snapshot's own symbolic `GeneratedDefault`/`Default` kind, launch-request factory/context, or known launch provider identifies the resource. A nil provider is not a veto. Saved `SceneContent` and protected content are always preserved.
3. Return OLED-black/custom-logo imagery through the ordinary, generation-options and cached-image accessors. Confirmed launch resources can use reference geometry when the original image is missing. Unknown resources remain untouched. The original `XBApplicationSnapshotImage` wrapper is retained; its initializer hook is diagnostic-only.
4. Replace only the detached launch-XIB provider return for exact bundle `com.amazon.Amazon`. Do not insert a view into any scene or saved card. iOS retains the returned resource's presentation lifetime.
5. Remove the now-unused app-side Home-readiness polling and call sites. Remove the inherited launch-time deletion of files under `SplashBoard/Snapshots`, so the tweak no longer deletes last-view snapshots or races iOS cache reads. No cache-clearing installation step is introduced.

The source includes no replacement launch state machine. There is no recurring screenshot recognition, broad image inversion, global UIKit replacement, delayed cover, process control or added warm/switcher handler.

## Precisely what is preserved

All app-side changes are an explicit allowlisted transformation of v7.307: version/comments, deletion of the readiness block and its call sites, deletion of the now-empty readiness-only view hook, and deletion of the snapshot-purge function/call. A full-file comparison verifies every other byte, including UI, Cart glyph/image logic, Alexa geometry, WK payloads and native warm behavior. The original preferences, assets, Makefile, Actions workflow, filters and installer are hash-checked.

The approved v7.307 `ADOwnAmazonSplash7307` / lifecycle warm-splash suppression is deliberately retained. This is existing app-native behavior, not a new SpringBoard warm-boot mechanism. Thus “stock timing” here means no independent SpringBoard cover or handoff deadlines; it does not claim every line of the original tweak is identical to an untweaked Amazon binary.

## Research and confidence boundaries

[Apple TN3118](https://developer.apple.com/documentation/technotes/tn3118-debugging-your-apps-launch-screen) documents the distinction between the system launch screen and the first app screen. The full document was reviewed in the preceding same-thread research; this pass reused that evidence after the public HTML/Markdown endpoints did not expose the body. A late app callback cannot retroactively correct an earlier system image.

The exact interface declarations were rechecked in the [iOS 17 runtime headers at d1d960df](https://github.com/MTACS/iOS-17-Runtime-Headers/tree/d1d960dfaa4107765dd7fcf891e4967c0930d5fd): `XBApplicationSnapshot`, `XBApplicationSnapshotManifestImpl`, `XBApplicationSnapshotImage`, and the SpringBoard launch-XIB provider. These prove selectors and types, not their invocation or description format on this phone.

An unrecognized cached launch kind with no provider/request provenance remains unchanged to protect saved UI. A private delivery path outside the hooked accessors or a bright child inside Amazon's native splash is not ruled out by the supplied logs. The dark source correction therefore needs target-device acceptance; no permanent zero-white guarantee is claimed.

## Verification and acceptance

The host test executes 79 cases of the production C resource policy and verifies the exact permitted app-source delta, saved-scene/protected-content vetoes, package identity, hook whitelist and absence of the removed timing/cache machinery. Logos lint and whitespace checks are also required. The source ZIP must be compared byte-for-byte with the checked worktree before delivery.

Local verification completed: all 79 cases, source/baseline checks, Logos lint and `git diff --check` pass. Both arm64 and arm64e compile/link and package creation pass. The existing Linux compiler reports an incompatible arm64e ABI warning; its binary is not the installation deliverable. Use the unchanged macOS Actions build from the supplied source. Existing explicit UI-probe retain-cycle warnings remain outside this change. No device-rendering or crash-cause verification is available here.

After the Actions package is installed and SpringBoard is restarted:

- Confirm installed version `7.337~v7307-stock-timing-cold-artwork` and the matching probe constructor with `mode=artwork-only`.
- Cold-launch repeatedly, including interrupted launches and kill/relaunch. `snapshot.dark` or `xib.dark` identifies a replaced resource; a generation factory event may be absent on cache hits.
- Background and reopen from Home and the switcher. The last app view must remain visible; no independent launch cover or 20-second wait exists in this source.
- If white appears, stop relaunching and export this version's probe immediately. A source event is not frame-level visual proof. If the app actually terminates, keep its CrashReporter/termination record as separate evidence.

Do not erase snapshots or old probes as a troubleshooting prerequisite. The new filename and full version marker distinguish this handoff from the installed process-scoped branch without destroying evidence.
