# v7.535 validation

- Logos lint passed.
- Emitted ADNewMenus JavaScript reconstructed from the shipped C string include and parsed by Node.
- New modal regression checks exact captured owners, retained layout properties, removal of only the duplicate outline, retained clear control, dark input color scheme, and OLED Update paint.
- Independent execution of the complete version-normalized regression set: 189 passed, two blocked by unavailable `clang` / `clang++`. Optional CSS cascade tests remain skipped when their Python matcher dependencies are absent.
- Strict validation was attempted and stops at the missing Clang toolchain. No successful strict/CI run or built iOS package is claimed here. GitHub macOS CI must complete these checks and produce the package.
- `git diff --check` passed. No device runtime verification was available. Keyboard first-focus appearance is specifically unverified.
