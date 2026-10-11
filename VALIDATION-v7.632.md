# AmazonDark v7.632 — Validation

- Source checked from the complete v7.631 tree; package, probes, tweak and identity synchronized to v7.632.
- **21/21 focused normalized regression tests PASS**, including precisely failing v7.375, checkout handoff v7.439, historical handoffs v7.525/v7.531, current v7.631 performance fast-path, WebKit/performance probes v7.625–v7.630, Alexa final-paint and native clang fixture.
- Logos lint PASS. Shell helper syntax and v7.631 Node route-gating harness PASS.
- Full `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` attempted locally and timed out during slow historical v7.388 probe-handoff test, after passing the original v7.375 failure. This is **not** a claim that full strict validation completed. A separate wider run had 120 subsequent tests produce no reported failure before the job timed out. CI still needs to run the entire suite and Theos compile.
- No claim about iPhone build, installed performance, or resolved lag.
