# Validation — v7.522

- Logos lint and git diff --check: pass.
- 176 normalized regression scripts attempted after final source/command edits: 174 completed successfully; two blocked by missing Clang/Clang++ (test_v7385_sponsored_c_linkage and test_v7480_build_syntax_guard). Not a strict-suite pass. Inherited optional-dependency skips remain possible.
- New compiled regression executes the shipped horizontal adjustment, verifies centering and repeat-call stability, and verifies unchanged vertical position.
- Tweak.xm remains below the existing 856,000-byte limit.
- Source based on remote v7.521 commit 19f38b70.
- Supplied v7.521 r1 confirms full seven-step native traversal/restoration and the preserved 60-point thumbnail column causing text offset.
- v7.522 iOS/Theos compilation and on-device visual verification remain pending. No changes to scanning behavior or TAR exports.
