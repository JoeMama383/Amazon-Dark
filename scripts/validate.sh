#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

# Debian maintainer scripts must be executable or dpkg-deb refuses to package.
mode=$(stat -c '%a' layout/DEBIAN/postinst 2>/dev/null || stat -f '%Lp' layout/DEBIAN/postinst 2>/dev/null || echo 0)
case "$mode" in 5??|7??) ;; *) echo "validate: layout/DEBIAN/postinst must be executable (mode=$mode)" >&2; exit 1;; esac

bash scripts/lint-logos.sh

# Source regression set is tests/test_*.py; execution uses a normalized temporary copy.
# Current-version synchronization is checked once here instead of rewriting every
# historical regression file on each build. Historical tests are frozen at the
# v7.460 baseline and receive version-token normalization only in a temporary copy.
pkg_version=$(sed -n 's/^Version:[[:space:]]*//p' layout/DEBIAN/control | head -n 1)
case "$pkg_version" in *~*) ;; *) echo "validate: malformed package version: $pkg_version" >&2; exit 1;; esac
cur_version=${pkg_version%%~*}
cur_slug=${pkg_version#*~}
cur_tag="v${cur_version}-${cur_slug}"

require_literal(){ grep -Fq "$2" "$1" || { echo "validate: version sync missing '$2' in $1" >&2; exit 1; }; }
require_literal src/Tweak.xm "#define AD_VERSION \"$cur_tag\""
require_literal scripts/ui-probe.sh "VER=$cur_version"
require_literal scripts/skeleton-probe.sh "AD_PROBE_VERSION=$cur_version"
require_literal scripts/skeleton-probe.sh "AD_PROBE_NAME=AmazonDark-v$cur_version"
require_literal src/ADUniversalUIProbe7362.inc "AMAZONDARK v$cur_version UNIVERSAL"
require_literal src/ADUniversalUIProbe7362.js.inc "version:'$cur_version'"
require_literal src/ADUniversalUIProbe7362.frame.js.inc "version:'$cur_version'"
require_literal src/ADUIProbeViewportSample7449.js.inc "version:'$cur_version'"
require_literal src/ADPDPMainStream7451.js.inc "version:'$cur_version'"
require_literal src/AmazonDarkSB.xm "AmazonDark-v$cur_version-launch-sb-probe.txt"

auto_cleanup=''
py_count=0
if command -v python3 >/dev/null 2>&1; then
  test_tmp="$ROOT/.ad-regressions.$$"
  rm -rf "$test_tmp"
  mkdir -p "$test_tmp"
  source_test_count=0
  for f in tests/test_*.py; do
    [ -f "$f" ] || continue
    source_test_count=$((source_test_count + 1))
  done
  [ "$source_test_count" -gt 0 ] || { echo "validate: no Python regressions found" >&2; exit 1; }
  cp -R tests/. "$test_tmp/"
  auto_cleanup="$test_tmp"
  trap 'rm -rf "${auto_cleanup:-}"' EXIT HUP INT TERM
  AD_TEST_TMP="$test_tmp" AD_CUR_VERSION="$cur_version" AD_CUR_PKG="$pkg_version" AD_CUR_TAG="$cur_tag" python3 - <<'PY'
import os
from pathlib import Path
root=Path(os.environ['AD_TEST_TMP'])
cur=os.environ['AD_CUR_VERSION']
pkg=os.environ['AD_CUR_PKG']
tag=os.environ['AD_CUR_TAG']
# v7.460 is the frozen historical-test baseline. Only build/version identity
# tokens are normalized; behavior/selectors/assertions are otherwise untouched.
repls=(
    ('7.460~home-hero-pill-owner-fix', pkg),
    ('v7.460-home-hero-pill-owner-fix', tag),
    ('AmazonDark-v7.460', 'AmazonDark-v'+cur),
    ('ad7460-home-hero-pill', 'ad7461-home-hero-pill'),
    ('v7.460', 'v'+cur),
    ('7.460', cur),
)
for p in root.glob('test_*.py'):
    s=p.read_text()
    for old,new in repls:
        s=s.replace(old,new)
    p.write_text(s)
PY
  for f in "$test_tmp"/test_*.py; do
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
