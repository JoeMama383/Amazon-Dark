# v7.446 validation

124 runnable Python regressions passed, including the emitted main/frame JavaScript batch collector, nested/document scroll restoration with content growth, and isolated FULL/VIEWPORT ZIP export including partial capture and repeated-export behavior. C++98 string embedding and Node syntax checks passed. Logos lint and helper shell syntax passed.

One existing C-linkage test could not run because clang is unavailable. No Theos/iOS SDK compile, installation, live WebKit timing, or on-device responsiveness verification was performed. GitHub Actions and the phone remain necessary compile/device checks.

Production Tweak.xm is byte-identical to v7.445 after release-identity normalization. The exact native skeleton scale fix is inherited; the new changes are diagnostic capture and export behavior. Native callback/deadline code is source-reviewed but cannot be executed against UIKit here.

Evidence remains best-effort: up to 24000 nodes per main snapshot; up to eight initially discovered large overflow owners; 120 Web sweep steps; 240-second FULL deadline; 45-second VIEWPORT deadline; existing output budgets. Frame internals are inspected but not scrolled. Missing responses and incomplete batches are flagged; cross-frame completeness remains unverified. These limitations prevent a foolproof/all-content claim.

Outstanding UI issues are retained in README.md. No previously unverified ad interior fix is claimed by this release.
