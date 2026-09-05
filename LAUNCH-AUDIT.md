# v7.331 launch audit and handoff

## Exact baseline

Base commit: `4bbbbd9ae7c5dc0a9d4dc1455235da3feeb706f7`, v7.307.

The user identifies this version as the desired UI/warm-resume/app-switcher baseline. This build starts from that commit in an isolated worktree, not either v7.330 archive. `Tweak.xm` changes only its opening comment and `AD_VERSION` string. Existing UI probes retain v7.307 filenames and include the new version inside the report. The Makefile, workflow, preferences, injection filters and artwork are identical to v7.307.

## Findings and evidence strength

The v7.307 `SBSceneView.didMoveToWindow` hook returns without covering Amazon whenever `processState.isRunning` is true. Running does not mean that a finished warm scene is available. It can be true after a new process starts or describe an outgoing process. This is a concrete false-warm branch in the source, corroborated by later traces. It does not establish that every historical flash had the same cause.

Your v7.327 trace shows the scene registering at `810219729.224977` with no cover active, followed by replacement-process launch at `810219729.872070`. A process callback can arrive too late to protect the start of that transition.

Your v7.328 generation-61 trace shows old PID 10086 posting ready at `810223423.363668`, then new PID 10094 launching at `810223423.460280`. The old ready dismisses generation 61 at `810223424.083886`, before the new constructor at `810223424.152786`. A global notification plus unchanged generation can release the wrong process's cover. This is directly evidenced, not a timing guess.

`overlay.attach win=0x0` proves installation into an unattached view. It does not prove that the compositor displayed it, that no other snapshot was visible, or which pixels were on screen. Earlier explanations overstated what these events proved.

## Post-v7.307 attempts in the available lineage

| Version | Change | Why it did not establish a complete solution |
|---|---|---|
| 7.308–7.310 | Cart, Menu, dog/footer/ad work and probes | Mostly unrelated to the system launch source; also moved the UI away from the user's chosen baseline. |
| 7.311 | PID identity and earlier window callback, described in the 7.312 history | No standalone 7.311 commit exists in this local ancestry. Its stated intent cannot substitute for a separate source/probe comparison. |
| 7.312–7.313 | Earlier scene mutation; replaced Home readiness with native-splash handoff | The history records compile fixes and subsequent watchdog failures. A native view callback also does not prove removal of every system launch surface. |
| 7.314 | Move mutation after the original window callback | The 7.315 audit records continued watchdog self-deadlock inside the enclosing transaction. Raw watchdog files were not independently reverified in this pass. |
| 7.315 | Defer scene work to the next main-queue turn | Avoids synchronous work there, but cannot guarantee covering the first displayed frame; the documented PID-unknown branch deliberately skips coverage. |
| 7.316–7.321 | Independent window, launch-selector discovery, then verified icon tap | Several releases were instrumentation or compile/link fixes. Correcting a hook entry point does not correct stale-PID classification or make a separate window part of the stock scene transition. |
| 7.322 | Manually couple the window to icon transition | Adds separate transition behavior while retaining classification and handoff dependencies. |
| 7.323–7.325 | Scene cover with a short icon-tap arm and later restored Home readiness | Still relies on tap-time process classification and a consumable arm. 7.325 also allows the first scene to consume the arm before confirming its bundle. |
| 7.326 | Native scene-overlay API; remove snapshot purge; Cart/Alexa changes | The user's trace still shows fresh processes arriving after taps classified warm. Attachment logs do not prove first-frame visibility. |
| 7.327 | Authoritative process-launch callback | Fixes a missed replacement process, but the supplied trace proves that callback may arrive after the transition begins. |
| 7.328 | Live-scene prearm | Generation 61 directly proves the outgoing-process ready race described above. |
| 7.329 | Synthetic background/switcher cover | Changes what UIKit snapshots; a foreground overlay and a saved switcher image remain different surfaces. |
| Earlier 7.330 | Process-qualified readiness | Targets the stale-ready race; does not by itself make a stock launch image dark. |
| Later 7.330 | Warm/switcher lifecycle changes on another working baseline | Violated the baseline constraint and changed app-side behavior. |
| Unfinished 7.331 draft | One pending process bit plus delayed-dismiss generation check | Rejected before this handoff: a late callback still misses an already-attached scene, and the global ready channel still lacks sender identity. |

## This implementation

The new addition changes the launch artwork returned by SpringBoard's source path. It does not try to fix those timing races by adding another launch state machine.

- `XBApplicationSnapshot`: exact Amazon bundle identity plus exact `dataProviderClassName == XBLaunchImageDataProvider` selects launch artwork. Three image-returning accessors return black/custom-logo imagery at the original image's size and scale.
- Other snapshot providers, including saved scene content, return the original result. There is no guessed numeric content-type constant or broad brightness test.
- `SBDeviceApplicationSceneViewPlaceholderContentViewProvider._loadLiveXIBViewForApplication:` substitutes equivalent imagery only for an exact Amazon detached UIView return. It does not mutate the live scene hierarchy.
- Generated artwork is cached for up to four sizes with a 32 MB cache cost limit. No user snapshot pixels are stored by this cache.
- v7.307's existing cover, warm suppression, snapshot purge and Home-ready behavior remain as they were. Those inherited features are not new guarantees; the source substitution is intended to make the underlying launch artwork dark even when a cover is skipped or released.

## Validation and practical limits

The private interfaces were checked against the local iOS 17 runtime-header repository at commit `d1d960dfaa4107765dd7fcf891e4967c0930d5fd`. Headers establish selectors and types, not the full runtime call graph or which metadata Amazon's cached snapshots carry.

The build needs an on-device run to confirm `snapshot.dark` or `xib.dark` on failed launch paths. An Amazon launch image with a missing/different provider, an attached/unavailable XIB return, a missing logo, or a different image-delivery path is passed through and logged where observable. This is deliberate narrow scoping to preserve saved app content, and means a universal no-white guarantee is not yet supported.

The code does not claim to intercept arbitrary IOSurface deliveries or rewrite Amazon's packaged launch storyboard. A black splash controller background in an old probe does not rule out a bright child image. Device video and source events are necessary to distinguish those cases if white persists.

Both architectures are compile checked locally. The available Linux toolchain reports an incompatible arm64e ABI linker warning, so the local binary is not the installation deliverable. Use the source ZIP with the unchanged macOS GitHub Actions workflow to build the device package. Compilation is not a device visual test.

## Probe

After installing the package produced by GitHub Actions, respring so SpringBoard loads the new dylib. Existing files are retained by adding a run marker, then reproduce cold launches and ordinary warm opens. Export `/var/mobile/AmazonDark-v7.331-launch-sb-probe.txt` into the usual shared Documents folder.

Expected new-source events: `snapshot.source` identifies the provider; `snapshot.dark` and `xib.dark` show substitution; `snapshot.fallback`, `xib.fallback` and `.error` identify paths left unchanged. These are source events, not pixel capture.

## Sources

- [Apple TN3118: Debugging your app's launch screen](https://developer.apple.com/documentation/technotes/tn3118-debugging-your-apps-launch-screen): system launch screens precede the first app screen.
- [iOS 17 runtime headers](https://github.com/MTACS/iOS-17-Runtime-Headers/tree/d1d960dfaa4107765dd7fcf891e4967c0930d5fd): `XBApplicationSnapshot`, `XBSnapshotContainerIdentity`, `XBLaunchImageDataProvider`, and `SBDeviceApplicationSceneViewPlaceholderContentViewProvider` interfaces.
- Local Amazon-Dark Git history from `4bbbbd9` through `c762cb9`, the two local v7.330 artifacts, and the v7.326–v7.328 probes supplied directly in this thread. Later audit prose is treated as historical reporting rather than independent runtime proof.
