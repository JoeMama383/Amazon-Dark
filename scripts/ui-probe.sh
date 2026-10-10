#!/bin/sh
# AmazonDark v7.617 universal UI probe helper.
# FULL: screenshot-triggered while Amazon stays foregrounded.
# VIEWPORT: arm once, show the target in Amazon, then background Amazon once.
# The app captures the last foreground scene at WillResignActive; export runs afterward.
# FULL, VIEWPORT, and TRANSITION all export one current capture as plain .tar.
set -eu
VER=7.617
# Use the package installed in Amazon, not an uninstalled checkout/helper version.
# This is essential while a newer CI build has failed compilation: the older
# installed tweak can still produce perfectly valid FULL/VIEWPORT captures.
installed=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
RUNTIME_VER=${installed%%~*}
if ! printf '%s\n' "$RUNTIME_VER" | grep -Eq '^7[.][0-9]+$'; then
  RUNTIME_VER=$VER
  RUNTIME_UNKNOWN=1
else
  RUNTIME_UNKNOWN=0
fi
# Preserve the historical helper-version contract used by probe handoff tests.
# If Amazon runs a different installed build (e.g. after a failed CI package),
# use the INSTALLED version for actual receipt discovery and exports.
CUR=${VER#7.}
if [ "$RUNTIME_VER" != "$VER" ]; then
  CUR=${RUNTIME_VER#7.}
fi
NAME=AmazonDark-v$RUNTIME_VER
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

# The receipt discovery above is a hint, not a prerequisite. A valid current
# capture state in an Amazon Documents container is itself authoritative.
for s in "$CONTAINERS"/*/Documents/"$NAME"-ui-full.state "$CONTAINERS"/*/Documents/"$NAME"-ui-viewport.state; do
  [ -f "$s" ] && add_target "${s%/*}"
done

# Include an app Documents directory even when a bootstrap receipt is missing,
# if it has the current runtime's screenshot trigger acknowledgement.
for s in "$CONTAINERS"/*/Documents/"$NAME"-ui-trigger.receipt; do
  [ -f "$s" ] && add_target "${s%/*}"
done

# The Amazon app and this script may have different versions during CI failure.
if [ "$RUNTIME_VER" != "$VER" ]; then
  printf 'Probe helper v%s; installed package %s. Using CURRENT INSTALLED probe v%s, not unbuilt v%s.\n' "$VER" "${installed:-unknown}" "$RUNTIME_VER" "$VER" >&2
fi

probe_diagnostic(){
  printf 'Probe discovery: installed=%s helper=v%s runtime=v%s AmazonTargets=%s\n' "${installed:-unknown}" "$VER" "$RUNTIME_VER" "$(wc -l < "$TARGETS" | tr -d ' ')" >&2
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    for receipt in "$d/$NAME-ui-trigger.receipt"; do
      if [ -f "$receipt" ]; then
        printf 'Amazon screenshot event receipt: ' >&2
        sed -n '1p' "$receipt" >&2
      fi
    done
  done < "$TARGETS"
  # Diagnose other versions without using their historical files as current captures.
  for p in "$CONTAINERS"/*/Documents/AmazonDark-v7.*-ui-full.state; do
    [ -f "$p" ] || continue
    printf 'Other retained FULL state (not exported): %s\n' "${p##*/}" >&2
  done
  if [ "$RUNTIME_UNKNOWN" = 1 ]; then
    printf 'No installed AmazonDark package version found; cannot verify this helper matches the loaded tweak.\n' >&2
  fi
}

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
  BEST_TS=0; BEST_FILE=""; BEST_STATE=""; BEST_DIR=""; SOURCE_STATE=""; TERMINAL=0
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
  SOURCE_STATE=$BEST_STATE
  [ -f "$BEST_FILE" ] || return 5
  if grep -q '================ END RUN ================' "$BEST_FILE" 2>/dev/null; then TERMINAL=1; fi
  case "$BEST_STATE" in
    completed|partial) [ "$TERMINAL" = 1 ] || { [ "$mode" = full ] || return 4; BEST_STATE=partial; };;
    started)
      [ "$mode" = full ] || return 4
      # Export an immutable copy of THIS receipt's evidence, never an older run.
      # A stopped scroll is not proof of completed DOM/native/frame coverage.
      BEST_STATE=partial;;
    *) return 4;;
  esac
  return 0
}

case "${1:-}" in
  arm)
    case "$installed" in "$RUNTIME_VER"~*) ;; *) printf 'Install/open a compiled AmazonDark build first. Installed: %s\n' "$installed" >&2; exit 1;; esac
    [ -s "$TARGETS" ] || { printf 'Amazon Documents not found. Open Amazon once, then rerun.\n' >&2; exit 1; }
    if [ "${2:-}" = full ]; then
      if [ "$RUNTIME_VER" != "$VER" ]; then
        printf 'Foreground FULL fallback requires installed v%s, but active package is v%s. Use screenshot FULL on the installed build or install v%s.\n' "$VER" "$RUNTIME_VER" "$VER" >&2
        exit 1
      fi
      now=$(date +%s)
      while IFS= read -r d; do
        mkdir -p "$d"
        # Never export a stale FULL state from before this explicit arm.
        rm -f "$d/$NAME-ui-full.state"
        printf 'full %s\n' "$now" > "$d/$NAME-ui-full.arm"
        chmod 600 "$d/$NAME-ui-full.arm" 2>/dev/null || true
      done < "$TARGETS"
      printf 'Armed ONE v%s FULL scan on Amazon next foreground. Return to the intended Amazon menu and leave it foregrounded until traversal completes, then export full. No screenshot is needed for this fallback.\n' "$RUNTIME_VER"
      exit 0
    fi
    [ "${2:-}" = '' ] || { printf 'Usage: arm [full]. Plain arm is VIEWPORT; arm full is foreground FULL fallback.\n' >&2; exit 1; }
    now=$(date +%s)
    while IFS= read -r d; do
      mkdir -p "$d"
      # Never let an old VIEWPORT state masquerade as the capture requested by this arm.
      rm -f "$d/$NAME-ui-viewport.state"
      printf 'viewport %s\n' "$now" > "$d/$NAME-ui-viewport.arm"
      chmod 600 "$d/$NAME-ui-viewport.arm" 2>/dev/null || true
    done < "$TARGETS"
    printf 'Armed one v%s VIEWPORT capture for Amazon\047s next background transition.\n' "$RUNTIME_VER"
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
        probe_diagnostic
        if [ "$mode" = full ]; then
          printf 'No current v%s FULL capture state found in the installed app. If Amazon is open, take a screenshot IN Amazon and wait. If a trigger receipt appears but no state, the screenshot callback arrived but FULL did not start.\n' "$RUNTIME_VER" >&2
        else
          printf 'No current v%s VIEWPORT capture state found. Arm, return to Amazon, then background it once.\n' "$RUNTIME_VER" >&2
        fi
        exit 1;;
      3) printf 'The newest v%s %s capture timestamp is in the future. Check the clock before triggering another capture.\n' "$RUNTIME_VER" "$mode" >&2; exit 1;;
      4)
        if [ "$mode" = full ]; then
          printf 'The current v%s FULL capture is still running or incomplete. Leave Amazon visible while the automatic walk runs, then return to the terminal to export. Status reports partial captures separately.\n' "$RUNTIME_VER" >&2
        else
          printf 'The current v%s VIEWPORT capture is queued or still running. Wait a few seconds and export viewport again; re-arm only if it never reaches a terminal state.\n' "$RUNTIME_VER" >&2
        fi
        exit 1;;
      *) printf 'The current v%s %s capture file is missing. Trigger a fresh capture.\n' "$RUNTIME_VER" "$mode" >&2; exit 1;;
    esac
    stage=$(mktemp -d)
    trap 'rm -f "$TARGETS"; rm -rf "$stage"' EXIT HUP INT TERM
    cp "$BEST_FILE" "$stage/"
    if [ "$SOURCE_STATE" = started ] || [ "$TERMINAL" = 0 ]; then
      printf 'Capture has no committed completion receipt; exporting available evidence as partial. Full coverage is not certified.\n' >&2
    fi
    {
      printf 'AmazonDark v%s universal UI probe\n' "$RUNTIME_VER"
      printf 'mode=%s\n' "$mode"
      printf 'source=%s\n' "${BEST_FILE##*/}"
      printf 'state=%s\n' "$BEST_STATE"
      printf 'receipt_epoch=%s\n' "$BEST_TS"
      printf 'source_state=%s\nterminal_marker=%s\n' "$SOURCE_STATE" "$TERMINAL"
      printf 'archive=plain-tar\n'
      printf 'exported_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
    } > "$stage/manifest.txt"
    archive="$SHARED/${BEST_FILE##*/}"
    archive="${archive%.txt}.tar"
    make_tar "$archive" "$stage"
    printf 'Exported exactly one %s v%s %s capture as TAR:\n%s\n' "$BEST_STATE" "$RUNTIME_VER" "$mode" "$archive"
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
    printf 'Additional FULL fallback: sh scripts/ui-probe.sh arm full (scan on next Amazon foreground).\n' >&2
    printf 'FULL: screenshot in Amazon OR arm full then return to Amazon; leave foregrounded for the walk. VIEWPORT: arm, show target in Amazon, background once.\n' >&2
    exit 1
    ;;
esac
