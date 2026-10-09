#!/bin/sh
# One bounded foreground session. No screenshots, UI scrolling or historical bundles.
set -eu
VER=7.615
ROOT=${AD_UI_ROOT:-/var/mobile}
CONTAINERS=${AD_UI_CONTAINERS:-$ROOT/Containers/Data/Application}
SHARED=${AD_UI_SHARED:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
NAME=AmazonDark-v$VER-performance
TARGETS=$(mktemp)
STAGE=''
trap 'rm -f "$TARGETS"; [ -z "$STAGE" ] || rm -rf "$STAGE"' EXIT HUP INT TERM
for receipt in "$CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json; do
  [ -f "$receipt" ] || continue
  rv=${receipt##*/}; rv=${rv#AmazonDark-v7.}; rv=${rv%-probe-status.json}
  case "$rv" in ''|*[!0-9]*) continue;; esac
  [ "$rv" -ge 344 ] && [ "$rv" -le "${VER#7.}" ] || continue
  if grep -Eq '"bundle"[[:space:]]*:[[:space:]]*"com[.]amazon[.]Amazon"' "$receipt" &&
     grep -Eq '"event"[[:space:]]*:[[:space:]]*"PROBE_BOOTSTRAP"' "$receipt" &&
     grep -Eq '"version"[[:space:]]*:[[:space:]]*"v7[.]'"$rv"'-' "$receipt"; then
    d=${receipt%/*}; grep -Fqx "$d" "$TARGETS" || printf '%s\n' "$d" >> "$TARGETS"
  fi
done
[ -s "$TARGETS" ] || { echo 'Open Amazon once to create its probe receipt, then retry.' >&2; exit 1; }
case "${1:-}" in
  arm)
    installed=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
    case "$installed" in "$VER"~*) ;; *) echo "Install/open v$VER first. Installed: $installed" >&2; exit 1;; esac
    while IFS= read -r d; do
      printf 'armed\n' > "$d/$NAME.state"
      date +%s > "$d/$NAME.arm"
      chmod 600 "$d/$NAME.arm"
    done < "$TARGETS"
    echo "Armed v$VER performance capture. Return to Amazon and reproduce the lag for up to 90 seconds."
    echo 'Backgrounding ends the session early. Avoid UI/transition probes during this measurement.'
    ;;
  export)
    [ -d "$SHARED" ] || { echo "Shared Documents missing: $SHARED" >&2; exit 1; }
    latest=0; chosen=''; state=''
    while IFS= read -r d; do
      [ -f "$d/$NAME.state" ] || continue
      ts=$(stat -c %Y "$d/$NAME.state" 2>/dev/null || stat -f %m "$d/$NAME.state")
      if [ "$ts" -ge "$latest" ]; then latest=$ts; chosen=$d; state=$(cat "$d/$NAME.state"); fi
    done < "$TARGETS"
    [ "$state" = completed ] || { echo "Performance capture is ${state:-missing}. Return to Amazon if armed; wait a few seconds after finishing before export." >&2; exit 1; }
    [ -s "$chosen/$NAME.json" ] || { echo 'Capture file missing.' >&2; exit 1; }
    STAGE=$(mktemp -d)
    cp "$chosen/$NAME.json" "$STAGE/"
    out="$SHARED/$NAME-$(date +%Y%m%d-%H%M%S)-$$.tar"
    (cd "$STAGE" && tar -cf "$out.partial" "$NAME.json")
    mv "$out.partial" "$out"; chmod 666 "$out" 2>/dev/null || true
    printf 'Exported one performance session: %s\n' "$out"
    ;;
  *) echo 'Usage: sh scripts/performance-probe.sh arm | export' >&2; exit 1;;
esac
