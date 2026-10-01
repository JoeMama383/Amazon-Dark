# Validation

192 version-normalized Python regressions passed, including C99/C++98 probe embedding, Node payload parsing and the new keyboard evidence runtime fixture. Two checks are blocked by unavailable clang/clang++: sponsored C linkage and Objective-C++ syntax preflight. Strict validation was attempted and stopped at missing clang. No full iOS build or on-device verification is claimed. GitHub CI must pass before installation.

Logos lint and git diff --check passed. Tweak.xm remains below the existing 856000-byte gate. Diagnostic behavior is bounded and only records while an opt-in transition capture is active. Remote keycap colors remain outside this app-local probe's visibility.
