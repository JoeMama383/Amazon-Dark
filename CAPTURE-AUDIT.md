# v7.341 capture-path repair and transition investigation

## What the screenshot proves

The v7.340 helper found no matching capture at `/var/mobile`. The screenshot
shows export attempts, not the preceding arm/install/startup sequence. It cannot
establish whether arming was omitted, an older process/package was running, or
file access failed.

Source inspection establishes a transport defect: v7.340 read and wrote directly
under `/var/mobile`, outside Amazon's data container, and discarded read/open
errors. The established explicit app probes use `NSDocumentDirectory` instead.
Apple's guidance describes app file access within permitted containers:
[Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively).
A jailbreak does not justify assuming every injected app has unrestricted file
access. Container-local handoff removes that assumption; the new receipt and
export report distinguish failure stages on this particular phone.

## What changes

The helper resolves `com.amazon.Amazon` using MCM metadata and supports plutil's
raw extraction, XML and pretty output forms. It checks the installed version,
then writes `AmazonDark-v7.341-probe.arm` inside each matching Amazon Documents
directory. The app independently resolves its own `NSDocumentDirectory`, writes
a bootstrap receipt, validates the request, and confirms capture-file creation
before starting any observation. File-creation/write errors update that receipt.

Export copies Amazon capture logs and receipts, recovers previous root-level
captures, includes the existing SpringBoard log (last 4 MiB), and always produces
a status archive when the shared output folder is available. It reports the
number of captures; an archive containing only diagnostics is not presented as a
successful app capture. Other apps' Documents are never scanned or exported.

## Transition observations

The new `launch` mode is armed before a fresh Amazon process. It reuses the
native recorder, samples available display callbacks including inactive startup,
and stops at background or after 20 seconds. This is a recording duration,
not a display/launch deadline. It creates no overlay, ready listener, PID launch
classifier, screenshot, snapshot mutation or animation override. It does not
restart on warm foreground. All existing SpringBoard source bytes are retained.

The recorder captures large view floors, image-view identities/sizes, presentation
backgrounds/opacity/frame, layer animation keys/durations and app lifecycle times.
Model opacity can already be zero during a visible fade, so eligibility also
considers presentation opacity. The existing splash painter is observed before
and after its own writes, with all original production statements retained.
This matters because its repeated assignment of `alpha=1` could interfere with
a fade; the new data can establish whether that occurs on the bad launch.

Apple describes [presentation-layer state](https://developer.apple.com/documentation/quartzcore/calayer/presentation%28%29)
and [animation keys](https://developer.apple.com/documentation/quartzcore/calayer/animationkeys%28%29)
as the relevant read interfaces. Only numeric/technical state is exported.

Launch capture deliberately omits the WebKit skeleton observer. Its native scan
has a 220-view visit cap and a soft 2 ms traversal budget, logs truncation and
observed frame timing, and requests the screen's available maximum frame rate.
It can add diagnostic overhead; actual device logs are needed to assess that.
It is not a physical pixel recording or proof of every composited frame. It
cannot directly observe a SpringBoard frame before the app exists. The inherited
SpringBoard log supplies artwork source/replacement decisions for that interval.

## Validation and limits

- The shipped helper was executed against temporary binary plist fixtures and
  actual filesystem/tar operations. Tests cover three plutil forms, wrong-package
  and invalid-mode rejection, empty capture, absent container, old-path recovery,
  receipt/SpringBoard inclusion, disarming, and excluding another app's files.
- The entire app source compares to the selected v7.309 transformation after
  removing only the exact documented probe integrations, including the two new
  splash observations. SpringBoard remains SHA-256
  `076a9bc1c1cc0424e4bd79e79306b5791da90bfd66f5c973ddbb86c1215f3806`.
- The shipped skeleton JavaScript bytes are unchanged. Its compiled C99/C++98
  embedding regression and the existing launch-policy/startup-safety checks pass.
- The full source compiles, links and packages locally for arm64 and arm64e with
  `-std=gnu++98` applied as a local verification argument. The archived Makefile
  and macOS Actions workflow are unchanged. Local dependency symlinks were
  restored from their own tracked definitions to run this build.
- The Linux compiler reports its known arm64e ABI warning. The local .deb is
  excluded from the source handoff; install the usual macOS Actions artifact.
- No new on-device capture or visual fix is claimed yet. The next evidence is the
  exported launch capture and a separate Home/Cart skeleton capture.

Run `tests/test_probe_handoff.py`, `tests/test_probe_embedding.py`,
`tests/test_cold_launch_policy.py`, `tests/test_startup_safety.py` and the retained
Logos linter to reproduce the host checks.
