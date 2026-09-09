# AmazonDark v7.376 — warm/app-switcher source correction

## Backtrack

The project already solved this architecture once. v7.335/v7.336 deliberately removed both the app-switcher cover subsystem and the v7.307 warm-splash hide/show state machine, restoring the v6.0.185 behavior: UIKit snapshots the already-themed live scene and a settled process foregrounds directly. Later launch work rebased on v7.307; the warm-suppression state machine returned and v7.350 explicitly retained that contract.

In the current v7.375 source, `gADOrdinaryWarmResume7307` remains latched during a foreground session and `ADOwnAmazonSplash7307` writes `vc.view.hidden=YES` / `alpha=0` for AXU/Tez. That mutates the live hierarchy at exactly the lifecycle boundaries from which iOS derives warm transitions and switcher imagery. The v7.375 black per-window snapshot cover then hid the symptom instead of removing that mutation.

## v7.376 correction

1. Remove `AmazonDarkWarmSnapshotCover7375` and every install/remove helper.
2. Remove the UIApplication/UIScene warm-classification observer and all `gADOrdinaryWarmResume7307` / suppression-latch state.
3. Remove `ADReleaseWarmSplash7307` and every hidden/alpha write made for warm suppression.
4. Keep exact AXU/Tez pixel theming only: OLED controller floor + the accepted v7.350 splash seal. Amazon/UIKit own presentation visibility/timing/dismissal.
5. Leave SpringBoard saved `SceneContent` snapshots pass-through; no new switcher hook or snapshot deletion is added.
6. Preserve all v7.375 checkout/BYG/TWB/CI fixes unchanged.

## Expected behavior

- App switcher displays the menu/page Amazon was actually showing when backgrounded.
- Warm same-process foreground returns to that live page without an AmazonDark black cover or AmazonDark hide/show transition.
- Genuine native splash presentation remains dark rather than white, but Amazon controls whether it appears.
- Cold launch artwork policy remains unchanged.

## Performance

This patch deletes production lifecycle observers/state and one full-window cover. It adds no timer, MutationObserver, RAF, polling loop, recurring scan, or switcher hook.
