#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"


# Debian maintainer scripts must be executable or dpkg-deb refuses to package.
mode=$(stat -c '%a' layout/DEBIAN/postinst 2>/dev/null || stat -f '%Lp' layout/DEBIAN/postinst 2>/dev/null || echo 0)
case "$mode" in 5??|7??) ;; *) echo "validate: layout/DEBIAN/postinst must be executable (mode=$mode)" >&2; exit 1;; esac

# Always available on the jailbroken-device push path.
bash scripts/lint-logos.sh

# Python is guaranteed in CI, but is intentionally optional on-device.
# This keeps the phone push workflow dependency-free while CI remains strict.
py_count=0
if command -v python3 >/dev/null 2>&1; then
  for f in tests/test_*.py; do
    [ -f "$f" ] || continue
    python3 "$f"
    py_count=$((py_count + 1))
  done
  echo "python-regressions: OK ($py_count)"
elif [ "${AD_STRICT_VALIDATE:-0}" = "1" ]; then
  echo "validate: python3 is required in strict/CI mode" >&2
  exit 127
else
  echo "python-regressions: SKIP (python3 unavailable on this device; GitHub CI enforces them)"
fi
