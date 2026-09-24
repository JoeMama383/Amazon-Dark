#!/bin/sh
# AmazonDark v7.473 universal UI probe helper.
# FULL: screenshot-triggered while Amazon stays foregrounded.
# VIEWPORT: arm once, show the target in Amazon, then background Amazon once.
# The app captures the last foreground scene at WillResignActive; export runs afterward.
# FULL, VIEWPORT, and TRANSITION all export one current capture as plain .tar.
set -eu
VER=7.473
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

make_tar(){
  out=$1; stage=$2; base=${out##*/}; tmp="$SHARED/.${base%.tar}.partial.tar"
  rm -f "$tmp"
  command -v tar >/dev/null 2>&1 || { printf 'tar is required for probe export.\n' >&2; return 1; }
  (cd "$stage" && tar -cf "$tmp" .)
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
  [ "$age" -ge -5 ] || return 3
  case "$BEST_STATE" in completed|partial) ;; *) return 4;; esac
  [ -f "$BEST_FILE" ] || return 5
  grep -q '================ END RUN ================' "$BEST_FILE" 2>/dev/null || return 4
  return 0
}

case "${1:-}" in
  arm)
    case "$installed" in "$VER"~*) ;; *) printf 'Install/open the v%s package first. Installed: %s\n' "$VER" "$installed" >&2; exit 1;; esac
    [ -s "$TARGETS" ] || { printf 'Amazon Documents not found. Open Amazon once, then rerun.\n' >&2; exit 1; }
    now=$(date +%s)
    while IFS= read -r d; do
      mkdir -p "$d"
      # Never let an old VIEWPORT state masquerade as the capture requested by this arm.
      rm -f "$d/$NAME-ui-viewport.state"
      printf 'viewport %s\n' "$now" > "$d/$NAME-ui-viewport.arm"
      chmod 600 "$d/$NAME-ui-viewport.arm" 2>/dev/null || true
    done < "$TARGETS"
    printf 'Armed one v%s VIEWPORT capture for Amazon\047s next background transition.\n' "$VER"
    printf 'Return to Amazon, leave the exact target scene visible, then background Amazon once. The capture freezes that last foreground scene; export from NewTerm afterward.\n'
    ;;
  export)
    mode=${2:-}
    case "$mode" in full|viewport) ;; *) printf 'Use exactly one mode: sh scripts/ui-probe.sh export full | export viewport\n' >&2; exit 1;; esac
    [ -d "$SHARED" ] || { printf 'Shared Documents missing: %s\n' "$SHARED" >&2; exit 1; }
    rc=0
    if [ "$mode" = viewport ]; then
      tries=0
      while :; do
        rc=0; find_capture "$mode" || rc=$?
        case "$rc" in 0|3|5) break;; esac
        tries=$((tries+1)); [ "$tries" -ge 10 ] && break
        sleep 1
      done
    else
      find_capture "$mode" || rc=$?
    fi
    case "$rc" in
      0) ;;
      2)
        if [ "$mode" = full ]; then
          printf 'No current v%s FULL capture state found. Take one screenshot in Amazon and let FULL complete before exporting.\n' "$VER" >&2
        else
          printf 'No current v%s VIEWPORT capture state found. Arm it, show the target in Amazon, then background Amazon once before exporting.\n' "$VER" >&2
        fi
        exit 1;;
      3) printf 'The newest v%s %s capture timestamp is in the future. Check the clock before triggering another capture.\n' "$VER" "$mode" >&2; exit 1;;
      4)
        if [ "$mode" = full ]; then
          printf 'The current v%s FULL capture is still running or incomplete. Leave Amazon visible while the automatic walk runs, then return to the terminal to export. Status reports partial captures separately.\n' "$VER" >&2
        else
          printf 'The current v%s VIEWPORT background capture did not reach a terminal state. Re-arm it and background Amazon again.\n' "$VER" >&2
        fi
        exit 1;;
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
      printf 'archive=plain-tar\n'
      printf 'exported_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
    } > "$stage/manifest.txt"
    archive="$SHARED/${BEST_FILE##*/}"
    archive="${archive%.txt}.tar"
    make_tar "$archive" "$stage"
    printf 'Exported exactly one %s v%s %s capture as TAR:\n%s\n' "$BEST_STATE" "$VER" "$mode" "$archive"
    ;;
  status)
    printf 'Installed: %s\n' "$installed"
    while IFS= read -r d; do
      printf 'Amazon Documents: %s\n' "$d"
      for mode in full viewport; do
        state="$d/$NAME-ui-$mode.state"
        if [ -f "$state" ]; then printf '%s state: ' "$mode"; cat "$state"; else printf '%s state: none\n' "$mode"; fi
      done
      if [ -f "$d/$NAME-ui-viewport.arm" ]; then printf 'Viewport next-background arm: '; cat "$d/$NAME-ui-viewport.arm"; fi
    done < "$TARGETS"
    ;;
  disarm)
    while IFS= read -r d; do rm -f "$d/$NAME-ui-viewport.arm"; done < "$TARGETS"
    printf 'VIEWPORT next-background arm cleared. FULL remains screenshot-triggered only.\n'
    ;;
  *)
    printf 'Usage: sh scripts/ui-probe.sh arm | export full | export viewport | status | disarm\n' >&2
    printf 'FULL: screenshot in Amazon, let the automatic walk finish, then export full from the terminal. Product Detail closes its screenshot Share sheet first. VIEWPORT: arm, show target in Amazon, background once, then export viewport.\n' >&2
    exit 1
    ;;
esac
