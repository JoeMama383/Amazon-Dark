# Validation

193 version-normalized Python regressions passed. Two checks could not run because clang/clang++ are unavailable: sponsored C linkage and Objective-C++ syntax preflight. Strict validation stops at that missing compiler. No full iOS build or device verification is claimed; GitHub CI must pass before installation.

C99/C++98 probe embedding, Node parsing/runtime tests, and the actual C++98 rolling-budget burst/recovery fixture passed. Logos lint and git diff --check passed. Tweak.xm is 855775 bytes, below the 856000-byte gate.

This release repairs missing diagnostic coverage, not the unproven keyboard appearance cause. Remote keycap pixels remain outside the app-local trace.
