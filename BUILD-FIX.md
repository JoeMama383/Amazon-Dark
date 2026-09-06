# v7.340 compilation repair

The supplied Actions output fails at the first line of
`src/ADSkeletonProbe7339.js.inc`, the `R"AD7339JS(` raw-string delimiter. Once
that delimiter is rejected, JavaScript is parsed as native source, causing the
subsequent `function`, `document`, bracket and `@try` errors. The previous local
compiler accepted the wrapper, so that verification missed the compatibility
problem.

The same wrapper rejection is reproducible in C++98. v7.340 uses ordinary
adjacent escaped C string literals, supported in both C99 and C++98. It does not
require a new compiler dialect or any change to the user's Actions workflow.

## Exact source preservation

- Parent: the delivered `AmazonDark-v7.339-source.zip`, SHA-256
  `11c3ecc495cc122f8ee119712f8589cec4b499f04609a4a8a03a51d60b84c471`.
- Selected UI baseline remains commit
  `1bd6d82bdff18ebba012794ef70e7c288a21336e`, v7.309's exact dog, Cart, footer,
  and XL brand fixes.
- The compiled JavaScript payload is byte-for-byte v7.339, SHA-256
  `b4a265b6044c0fbc5aa077f77a2eb4686b610bee557640abb8404d53d92f229b`.
- `src/Tweak.xm` differs from v7.339 only in its two version labels. The native
  probe header and phone helper differ only in versioned capture filenames and
  labels. Internal `7339` identifiers remain intentional.
- `src/AmazonDarkSB.xm` remains byte-for-byte the v7.338 transition donor. The
  Makefile, Actions workflow, installer, filters and preferences retain their
  prior bytes.

The skeleton probe remains opt-in and records the early Home/Cart paint owners.
No new skeleton coloring is claimed before the device capture is available.

## Verification

Run from the source directory:

```sh
python3 tests/test_probe_embedding.py
python3 tests/test_cold_launch_policy.py
python3 tests/test_startup_safety.py
bash scripts/lint-logos.sh src/Tweak.xm src/AmazonDarkSB.xm
sh -n scripts/skeleton-probe.sh
```

The embedding test compiles the actual shipped include under C99 and C++98,
executes both binaries, and compares their emitted bytes to the previous script.
Its negative control requires C++98 to reject the former raw wrapper. It also
checks agreement between the native capture and helper's v7.340 filenames.

The baseline checks cover all app source outside the previously audited
transition removals, four diagnostic entry points and version labels. Launch
policy tests execute 79 cases against the production selector, and the startup
safety checks retain the v7.338 constructor protections.

A full local Theos rebuild could not run in this session: its restored dependency
directory lacks the Logos launcher and compiler binaries. The previous browser
executable is also absent. The unchanged JavaScript has the earlier fixture
results documented in `SKELETON-AUDIT.md`; v7.340's current verification proves
compiled byte identity. This is not a claim of a new Actions or iPhone run.
The user's macOS Actions build remains the installable-package build.
