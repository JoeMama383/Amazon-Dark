# Validation — v7.521

- Base: fd2be84b (v7.520).
- Logos lint: OK.
- git diff --check: OK.
- 175 normalized regression scripts attempted after final COMMANDS.md edits: 173 completed successfully; two blocked by absent Clang/Clang++ (test_v7385_sponsored_c_linkage.py and test_v7480_build_syntax_guard.py). This is not a strict-suite pass. Some inherited scripts have optional dependency skips.
- New inset-plane regression compiles and executes the shipped geometry expression with g++ against the captured left child and negative controls.
- Source size: Tweak.xm 855,878 bytes, below existing 856,000-byte gate.
- Device evidence applies to v7.520 r5: seven Person offsets, bottom reached, zero restored, no truncated snapshots. It captured the border owner and covering child.
- v7.521 iOS/Theos build, border rendering, offline/refresh replacement and timing improvement have not been tested on-device. GitHub CI remains strict. Phone commands explicitly use non-strict validation because Python is absent there.
- No changes to FULL route selection, scroll steps, hydration waits, viewport/transition capture semantics or plain TAR exports.
