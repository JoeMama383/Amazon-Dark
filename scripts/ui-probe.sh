#!/bin/sh
# AmazonDark v7.366 universal UI probe helper.
# `arm` is a one-shot VIEWPORT capture: create the app-local arm then signal Amazon.
# FULL capture is intentionally screenshot-only and needs no shell command.
set -eu
VER=7.366
NAME=AmazonDark-v7.366
ROOT=${AD_UI_ROOT:-/var/mobile}
CONTAINERS=${AD_UI_CONTAINERS:-$ROOT/Containers/Data/Application}
SHARED=${AD_UI_SHARED:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
TARGETS=$(mktemp)
trap 'rm -f "$TARGETS"' EXIT HUP INT TERM

add_target(){ [ -n "$1" ] || return 0; grep -Fqx "$1" "$TARGETS" 2>/dev/null || printf '%s\n' "$1" >> "$TARGETS"; }

# Best source after the package has run once: the signed-in-app bootstrap receipt.
for r in "$CONTAINERS"/*/Documents/"$NAME-probe-status.json" "$CONTAINERS"/*/Documents/AmazonDark-v7.365-probe-status.json "$CONTAINERS"/*/Documents/AmazonDark-v7.364-probe-status.json "$CONTAINERS"/*/Documents/AmazonDark-v7.363-probe-status.json "$CONTAINERS"/*/Documents/AmazonDark-v7.362-probe-status.json; do
  [ -f "$r" ] || continue
  if grep -Eq '"bundle"[[:space:]]*:[[:space:]]*"com[.]amazon[.]Amazon"' "$r" 2>/dev/null; then add_target "${r%/*}"; fi
done

# Metadata fallback for a clean install before a current receipt exists.
for p in "$CONTAINERS"/*/.com.apple.mobile_container_manager.metadata.plist; do
  [ -f "$p" ] || continue
  id=$(plutil -extract MCMMetadataIdentifier raw -o - "$p" 2>/dev/null || true)
  [ "$id" = com.amazon.Amazon ] && add_target "${p%/*}/Documents"
done

installed=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
find_pid(){
  line=$(ps -A -o pid=,comm= 2>/dev/null | grep '/Amazon[.]app/Amazon' | head -1 || true)
  set -- $line
  if [ -n "${1:-}" ]; then printf '%s\n' "$1"; return 0; fi
  pgrep -x Amazon 2>/dev/null | head -1 || true
}

case "${1:-}" in
  arm)
    case "$installed" in 7.366~*) ;; *) printf 'Install/open the v7.366 package first. Installed: %s\n' "$installed" >&2; exit 1;; esac
    [ -s "$TARGETS" ] || { printf 'Amazon Documents not found. Open Amazon once, then rerun.\n' >&2; exit 1; }
    pid=$(find_pid); [ -n "$pid" ] || { printf 'Amazon is not running. Leave the target screen open, then rerun.\n' >&2; exit 1; }
    while IFS= read -r d; do mkdir -p "$d"; printf 'viewport %s\n' "$(date +%s)" > "$d/$NAME-ui-viewport.arm"; chmod 600 "$d/$NAME-ui-viewport.arm" 2>/dev/null || true; done < "$TARGETS"
    kill -USR2 "$pid"
    printf 'Armed and triggered one universal VIEWPORT capture in Amazon PID %s. No scrolling is performed.\n' "$pid"
    ;;
  export)
    [ -d "$SHARED" ] || { printf 'Shared Documents missing: %s\n' "$SHARED" >&2; exit 1; }
    found=0; partial=0
    while IFS= read -r d; do
      for kind in ui-full-probe ui-viewport-probe; do
        newest=""
        for f in $(ls -1t "$d"/AmazonDark-v7.366-${kind}-*.txt 2>/dev/null || true); do
          if grep -q '================ END RUN ================' "$f" 2>/dev/null; then newest=$f; break; fi
          partial=1
        done
        [ -n "$newest" ] || continue
        cp -f "$newest" "$SHARED/"; chmod 666 "$SHARED/${newest##*/}" 2>/dev/null || true; ls -lh "$SHARED/${newest##*/}"; found=$((found+1))
      done
    done < "$TARGETS"
    if [ "$found" -eq 0 ]; then
      [ "$partial" -eq 0 ] || { printf 'Newest v7.366 universal UI probe is still sweeping. Keep Amazon foregrounded, then rerun export.\n' >&2; exit 1; }
      printf 'No completed v7.366 universal UI captures found.\n' >&2; exit 1
    fi
    ;;
  status)
    printf 'Installed: %s\n' "$installed"
    while IFS= read -r d; do printf 'Amazon Documents: %s\n' "$d"; ls -1t "$d"/AmazonDark-v7.366-ui-*-probe-*.txt 2>/dev/null | head -6 || true; [ -f "$d/$NAME-ui-viewport.arm" ] && printf 'Viewport arm: '; [ -f "$d/$NAME-ui-viewport.arm" ] && cat "$d/$NAME-ui-viewport.arm"; done < "$TARGETS"
    ;;
  disarm)
    while IFS= read -r d; do rm -f "$d/$NAME-ui-viewport.arm"; done < "$TARGETS"; printf 'Viewport UI probe disarmed.\n'
    ;;
  *)
    printf 'Usage: sh scripts/ui-probe.sh arm | export | status | disarm\n' >&2
    printf 'FULL probe: take a screenshot. VIEWPORT probe: run `sh scripts/ui-probe.sh arm`.\n' >&2
    exit 1
    ;;
esac
