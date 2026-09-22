#!/bin/sh
# AmazonDark v7.446 universal UI probe helper.
# FULL: screenshot-triggered. VIEWPORT: one-shot arm + SIGUSR2.
# Exports are deliberately mode-specific and contain exactly one current capture.
set -eu
VER=7.446
CUR=${VER#7.}
NAME=AmazonDark-v$VER
ROOT=${AD_UI_ROOT:-/var/mobile}
CONTAINERS=${AD_UI_CONTAINERS:-$ROOT/Containers/Data/Application}
SHARED=${AD_UI_SHARED:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
TARGETS=$(mktemp)
trap 'rm -f "$TARGETS"' EXIT HUP INT TERM

add_target(){ [ -n "$1" ] || return 0; grep -Fqx "$1" "$TARGETS" 2>/dev/null || printf '%s\n' "$1" >> "$TARGETS"; }

# Prefer signed AmazonDark bootstrap receipts; filename/payload version must agree.
for r in "$CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json; do
  [ -f "$r" ] || continue
  rv=${r##*/}; rv=${rv#AmazonDark-v7.}; rv=${rv%-probe-status.json}
  case "$rv" in ''|*[!0-9]*) continue;; esac
  [ "$rv" -ge 344 ] 2>/dev/null || continue
  [ "$rv" -le "$CUR" ] 2>/dev/null || continue
  if grep -Eq '"bundle"[[:space:]]*:[[:space:]]*"com[.]amazon[.]Amazon"' "$r" 2>/dev/null &&
     grep -Eq '"event"[[:space:]]*:[[:space:]]*"PROBE_BOOTSTRAP"' "$r" 2>/dev/null &&
     grep -Eq '"version"[[:space:]]*:[[:space:]]*"v7[.]'"$rv"'-' "$r" 2>/dev/null; then
    add_target "${r%/*}"
  fi
done

# Clean-install metadata fallback.
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

make_zip(){
  out=$1; stage=$2; base=${out##*/}; tmp="$SHARED/.${base%.zip}.partial.zip"
  rm -f "$tmp"
  if command -v zip >/dev/null 2>&1; then
    (cd "$stage" && zip -q -r "$tmp" .)
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar --format zip -cf "$tmp" -C "$stage" .
  elif tar --help 2>&1 | grep -q -- '--format'; then
    tar --format=zip -cf "$tmp" -C "$stage" .
  else
    printf 'No ZIP-capable archiver found (need zip or bsdtar).\n' >&2
    return 1
  fi
  mv "$tmp" "$out"
  chmod 666 "$out" 2>/dev/null || true
}

find_capture(){
  mode=$1
  BEST_TS=0; BEST_FILE=""; BEST_STATE=""; BEST_DIR=""
  now=$(date +%s)
  while IFS= read -r d; do
    state="$d/$NAME-ui-$mode.state"
    [ -f "$state" ] || continue
    line=$(cat "$state" 2>/dev/null || true)
    set -- $line
    status=${1:-}; ts=${2:-0}; file=${3:-}
    case "$ts" in ''|*[!0-9]*) continue;; esac
    case "$file" in "$NAME-ui-$mode-probe-"*.txt|no-capture) ;; *) continue;; esac
    [ "$ts" -gt "$BEST_TS" ] 2>/dev/null || continue
    BEST_TS=$ts; BEST_FILE="$d/$file"; BEST_STATE=$status; BEST_DIR=$d
  done < "$TARGETS"
  [ "$BEST_TS" -gt 0 ] 2>/dev/null || return 2
  age=$((now-BEST_TS))
  if [ "$age" -lt -5 ]; then return 3; fi
  case "$BEST_STATE" in completed|partial) ;; *) return 4;; esac
  [ -f "$BEST_FILE" ] || return 5
  grep -q '================ END RUN ================' "$BEST_FILE" 2>/dev/null || return 4
  return 0
}

case "${1:-}" in
  arm)
    case "$installed" in "$VER"~*) ;; *) printf 'Install/open the v%s package first. Installed: %s\n' "$VER" "$installed" >&2; exit 1;; esac
    [ -s "$TARGETS" ] || { printf 'Amazon Documents not found. Open Amazon once, then rerun.\n' >&2; exit 1; }
    pid=$(find_pid); [ -n "$pid" ] || { printf 'Amazon is not running. Leave the target screen open, then rerun.\n' >&2; exit 1; }
    while IFS= read -r d; do
      mkdir -p "$d"
      rm -f "$d/$NAME-ui-viewport.state"
      printf 'viewport %s\n' "$(date +%s)" > "$d/$NAME-ui-viewport.arm"
      chmod 600 "$d/$NAME-ui-viewport.arm" 2>/dev/null || true
    done < "$TARGETS"
    kill -USR2 "$pid"
    printf 'Triggered one v%s universal VIEWPORT capture in Amazon PID %s. No scrolling is performed.\n' "$VER" "$pid"
    ;;
  export)
    mode=${2:-}
    case "$mode" in full|viewport) ;; *) printf 'Use exactly one mode: sh scripts/ui-probe.sh export full | export viewport\n' >&2; exit 1;; esac
    [ -d "$SHARED" ] || { printf 'Shared Documents missing: %s\n' "$SHARED" >&2; exit 1; }
    rc=0; find_capture "$mode" || rc=$?
    case "$rc" in
      0) ;;
      2) printf 'No current v%s %s capture state found. %s\n' "$VER" "$mode" "$( [ "$mode" = full ] && printf 'Take a screenshot first.' || printf 'Run arm with the target visible first.' )" >&2; exit 1;;
      3) printf 'The newest v%s %s capture timestamp is in the future. Check the clock before triggering another %s capture.\n' "$VER" "$mode" "$mode" >&2; exit 1;;
      4) printf 'The current v%s %s capture is still running or incomplete. Keep Amazon foregrounded, then retry this same export. Use status for the exact state.\n' "$VER" "$mode" >&2; exit 1;;
      *) printf 'The current v%s %s capture file is missing. Trigger a fresh capture.\n' "$VER" "$mode" >&2; exit 1;;
    esac
    stage=$(mktemp -d)
    trap 'rm -f "$TARGETS"; rm -rf "$stage"' EXIT HUP INT TERM
    cp "$BEST_FILE" "$stage/"
    {
      printf 'AmazonDark v%s universal UI probe\n' "$VER"
      printf 'mode=%s\n' "$mode"
      printf 'source=%s\n' "${BEST_FILE##*/}"
      printf 'state=%s\n' "$BEST_STATE"
      printf 'finished_epoch=%s\n' "$BEST_TS"
      printf 'exported_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
    } > "$stage/manifest.txt"
    archive="$SHARED/${BEST_FILE##*/}"
    archive="${archive%.txt}.zip"
    make_zip "$archive" "$stage"
    printf 'Exported exactly one %s v%s %s capture:\n%s\n' "$BEST_STATE" "$VER" "$mode" "$archive"
    ;;
  status)
    printf 'Installed: %s\n' "$installed"
    while IFS= read -r d; do
      printf 'Amazon Documents: %s\n' "$d"
      for mode in full viewport; do
        state="$d/$NAME-ui-$mode.state"
        if [ -f "$state" ]; then printf '%s state: ' "$mode"; cat "$state"; else printf '%s state: none\n' "$mode"; fi
      done
      if [ -f "$d/$NAME-ui-viewport.arm" ]; then printf 'Viewport arm: '; cat "$d/$NAME-ui-viewport.arm"; fi
    done < "$TARGETS"
    ;;
  disarm)
    while IFS= read -r d; do rm -f "$d/$NAME-ui-viewport.arm"; done < "$TARGETS"
    printf 'Viewport UI probe disarmed. FULL remains screenshot-triggered only.\n'
    ;;
  *)
    printf 'Usage: sh scripts/ui-probe.sh arm | export full | export viewport | status | disarm\n' >&2
    printf 'FULL: take one screenshot, then export full. VIEWPORT: arm, then export viewport.\n' >&2
    exit 1
    ;;
esac
