#!/bin/sh
# AmazonDark opt-in transition/lifecycle probe helper.
# v7.476 export is current-session-only and plain TAR; historical captures are never bundled.
# FULL, VIEWPORT, and TRANSITION deliberately share the same archive format.
set -eu
AD_PROBE_VERSION=7.476
AD_PROBE_CUR=${AD_PROBE_VERSION#7.}
AD_PROBE_ROOT=${AD_PROBE_ROOT:-/var/mobile}
AD_PROBE_CONTAINERS=${AD_PROBE_CONTAINERS:-$AD_PROBE_ROOT/Containers/Data/Application}
AD_PROBE_DOCS=${AD_PROBE_DOCS:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
AD_PROBE_NAME=AmazonDark-v7.476
AD_PROBE_TARGETS=$(mktemp)
AD_PROBE_LAUNCH_ARM="$AD_PROBE_ROOT/AmazonDark-launch-probe.arm"
trap 'rm -f "$AD_PROBE_TARGETS"' EXIT HUP INT TERM
AD_PROBE_SEEN=0
AD_PROBE_READABLE=0

add_target(){ [ -n "$1" ] || return 0; grep -Fqx "$1" "$AD_PROBE_TARGETS" 2>/dev/null || printf '%s\n' "$1" >> "$AD_PROBE_TARGETS"; }

# Metadata route, with fallbacks for the different rootless plutil dialects seen on-device.
for AD_PROBE_META in "$AD_PROBE_CONTAINERS"/*/.com.apple.mobile_container_manager.metadata.plist; do
    [ -f "$AD_PROBE_META" ] || continue
    AD_PROBE_SEEN=$((AD_PROBE_SEEN+1))
    [ -r "$AD_PROBE_META" ] && AD_PROBE_READABLE=$((AD_PROBE_READABLE+1))
    AD_PROBE_ID=$(plutil -extract MCMMetadataIdentifier raw -o - "$AD_PROBE_META" 2>/dev/null || true)
    if [ -z "$AD_PROBE_ID" ]; then
        AD_PROBE_ID=$(plutil -convert xml1 -o - "$AD_PROBE_META" 2>/dev/null | awk '
          /<key>MCMMetadataIdentifier<\/key>/ {take=1}
          take && /<string>/ {s=$0;sub(/^.*<string>/,"",s);sub(/<\/string>.*$/,"",s);print s;exit}' || true)
    fi
    if [ -z "$AD_PROBE_ID" ]; then
        AD_PROBE_ID=$(plutil -p "$AD_PROBE_META" 2>/dev/null | awk '
          /"MCMMetadataIdentifier"/ && /"com[.]amazon[.]Amazon"/ {print "com.amazon.Amazon";exit}' || true)
    fi
    [ "$AD_PROBE_ID" = com.amazon.Amazon ] && add_target "${AD_PROBE_META%/*}/Documents"
done

# Read the current receipt or verified recent receipts left during upgrade.
# Historical discovery glob remains read-only: "$AD_PROBE_DIR"/AmazonDark-v7.*-probe-status.json is never copied by export.
AD_PROBE_RECEIPTS=0
for AD_PROBE_RECEIPT in "$AD_PROBE_CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json; do
    [ -f "$AD_PROBE_RECEIPT" ] || continue
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT##*/}
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER#AmazonDark-v7.}
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER%-probe-status.json}
    case "$AD_PROBE_RECEIPT_VER" in ''|*[!0-9]*) continue;; esac
    [ "$AD_PROBE_RECEIPT_VER" -ge 344 ] 2>/dev/null || continue
    [ "$AD_PROBE_RECEIPT_VER" -le "$AD_PROBE_CUR" ] 2>/dev/null || continue
    if LC_ALL=C grep -Eq '"bundle"[[:space:]]*:[[:space:]]*"com[.]amazon[.]Amazon"' "$AD_PROBE_RECEIPT" &&
       LC_ALL=C grep -Eq '"event"[[:space:]]*:[[:space:]]*"PROBE_BOOTSTRAP"' "$AD_PROBE_RECEIPT" &&
       LC_ALL=C grep -Eq '"version"[[:space:]]*:[[:space:]]*"v7[.]'"$AD_PROBE_RECEIPT_VER"'-' "$AD_PROBE_RECEIPT"; then
        AD_PROBE_RECEIPTS=$((AD_PROBE_RECEIPTS+1))
        add_target "${AD_PROBE_RECEIPT%/*}"
    fi
done

ad_report(){
    printf 'Helper version: %s\nUTC: ' "$AD_PROBE_VERSION"; date -u
    printf 'Installed package: '; dpkg-query -W -f='${Package} ${Version}\n' com.joemama383.amazondark 2>&1 || true
    printf 'plutil: %s; metadata files seen=%s readable=%s\n' "$(command -v plutil || printf missing)" "$AD_PROBE_SEEN" "$AD_PROBE_READABLE"
    printf 'Verified Amazon startup receipts: %s\n' "$AD_PROBE_RECEIPTS"
    printf 'Amazon container matches: %s\n' "$(wc -l < "$AD_PROBE_TARGETS" | tr -d ' ')"
    while IFS= read -r AD_PROBE_DIR; do
        printf 'Amazon Documents: %s\n' "$AD_PROBE_DIR"
        for AD_PROBE_FILE in "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm" "$AD_PROBE_DIR/$AD_PROBE_NAME-probe-export.state" "$AD_PROBE_DIR/$AD_PROBE_NAME-probe-status.json"; do
            if [ -f "$AD_PROBE_FILE" ]; then printf '%s: ' "${AD_PROBE_FILE##*/}"; cat "$AD_PROBE_FILE"; printf '\n';
            else printf 'Missing: %s\n' "${AD_PROBE_FILE##*/}"; fi
        done
        for AD_PROBE_FILE in "$AD_PROBE_DIR/$AD_PROBE_NAME"-skeleton-*.jsonl; do
            [ -f "$AD_PROBE_FILE" ] || continue
            ls -ln "$AD_PROBE_FILE"
            head -n 1 "$AD_PROBE_FILE"
        done
    done < "$AD_PROBE_TARGETS"
    printf 'SpringBoard artwork log: '
    if [ -f "$AD_PROBE_ROOT/$AD_PROBE_NAME-launch-sb-probe.txt" ]; then ls -ln "$AD_PROBE_ROOT/$AD_PROBE_NAME-launch-sb-probe.txt";
    else printf 'missing\n'; fi
}

make_tar(){
    out=$1; stage=$2; base=${out##*/}; tmp="$AD_PROBE_DOCS/.${base%.tar}.partial.tar"
    rm -f "$tmp"
    command -v tar >/dev/null 2>&1 || { printf 'tar is required for probe export.\n' >&2; return 1; }
    (cd "$stage" && tar -cf "$tmp" .)
    mv "$tmp" "$out"
    chmod 666 "$out" 2>/dev/null || true
}
pick_current_capture(){
    BEST_MS=0; BEST_FILE=""; BEST_DIR=""; BEST_LABEL=""; BEST_ARM=0
    while IFS= read -r AD_PROBE_DIR; do
        state="$AD_PROBE_DIR/$AD_PROBE_NAME-probe-export.state"
        [ -f "$state" ] || continue
        line=$(cat "$state" 2>/dev/null || true); set -- $line
        label=${1:-}; arm=${2:-0}
        case "$label" in home|cart|both|launch|transition) ;; *) continue;; esac
        case "$arm" in ''|*[!0-9]*) continue;; esac
        for f in "$AD_PROBE_DIR/$AD_PROBE_NAME"-skeleton-*-$label.jsonl; do
            [ -f "$f" ] || continue
            # The arm-state file is rewritten on every arm. Requiring the capture to be
            # newer than that marker prevents a prior capture from the same wall-clock
            # second from being mistaken for the new session.
            [ "$f" -nt "$state" ] 2>/dev/null || continue
            b=${f##*/}; sess=${b#"$AD_PROBE_NAME-skeleton-"}; ms=${sess%%-*}
            case "$ms" in ''|*[!0-9]*) continue;; esac
            sec=$((ms/1000))
            [ "$sec" -ge "$arm" ] 2>/dev/null || continue
            [ "$ms" -gt "$BEST_MS" ] 2>/dev/null || continue
            BEST_MS=$ms; BEST_FILE=$f; BEST_DIR=$AD_PROBE_DIR; BEST_LABEL=$label; BEST_ARM=$arm
        done
    done < "$AD_PROBE_TARGETS"
    [ "$BEST_ARM" -gt 0 ] 2>/dev/null || return 2
    [ -n "$BEST_FILE" ] || return 3
    grep -q '"event":"SESSION_START"' "$BEST_FILE" 2>/dev/null || return 4
    return 0
}

case "${1:-}" in
 arm)
    AD_PROBE_LABEL=${2:-both}
    case "$AD_PROBE_LABEL" in home|cart|both|launch|transition) ;; *) printf 'Use arm home, cart, both, launch, or transition.\n' >&2; exit 1;; esac
    [ -s "$AD_PROBE_TARGETS" ] || { ad_report; printf 'Cannot identify Amazon data container. Open Amazon once, then retry; send this output if still missing.\n' >&2; exit 1; }
    AD_PROBE_INSTALLED=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
    case "$AD_PROBE_INSTALLED" in 7.476~*) ;; *) printf 'Install the v7.476 Actions package first. Installed: %s\n' "$AD_PROBE_INSTALLED" >&2; exit 1;; esac
    AD_PROBE_NOW=$(date +%s); AD_PROBE_EXPIRY=$((AD_PROBE_NOW+300)); umask 077
    while IFS= read -r AD_PROBE_DIR; do
        mkdir -p "$AD_PROBE_DIR"
        printf '%s %s\n' "$AD_PROBE_EXPIRY" "$AD_PROBE_LABEL" > "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"
        printf '%s %s\n' "$AD_PROBE_LABEL" "$AD_PROBE_NOW" > "$AD_PROBE_DIR/$AD_PROBE_NAME-probe-export.state"
        printf 'Armed %s in %s\n' "$AD_PROBE_LABEL" "$AD_PROBE_DIR"
    done < "$AD_PROBE_TARGETS"
    if [ "$AD_PROBE_LABEL" = launch ] || [ "$AD_PROBE_LABEL" = transition ]; then
        printf '%s\n' "$AD_PROBE_EXPIRY" > "$AD_PROBE_LAUNCH_ARM"; chmod 600 "$AD_PROBE_LAUNCH_ARM" 2>/dev/null || true
    else rm -f "$AD_PROBE_LAUNCH_ARM"; fi
    if [ "$AD_PROBE_LABEL" = launch ]; then
        printf 'Force-close and open Amazon within 5 minutes. Each fresh process records at most 20 seconds and stops on background. Export returns only the newest capture from this arm.\n'
    elif [ "$AD_PROBE_LABEL" = transition ]; then
        printf 'Force-close and reopen Amazon within 5 minutes, then reproduce the transition. One fresh process records up to 120 seconds and stays armed across background/foreground cycles. Export returns only the newest transition capture created by this arm.\n'
    else
        printf 'Force-close and open Amazon within 5 minutes. Capture runs for up to 2 minutes. Export returns only the newest capture from this arm.\n'
    fi
    printf 'After opening Amazon, status should show SESSION_START and a nonempty current-version capture file.\n'
    ;;
 status) ad_report ;;
 export)
    [ -d "$AD_PROBE_DOCS" ] || { printf 'Shared Documents folder is missing: %s\n' "$AD_PROBE_DOCS" >&2; exit 1; }
    AD_PROBE_STAGE=$(mktemp -d)
    trap 'rm -f "$AD_PROBE_TARGETS"; rm -rf "$AD_PROBE_STAGE"' EXIT HUP INT TERM
    ad_report > "$AD_PROBE_STAGE/diagnostic-status.txt" 2>&1
    rc=0; pick_current_capture || rc=$?
    if [ "$rc" -eq 0 ]; then
        cp "$BEST_FILE" "$AD_PROBE_STAGE/"
        if [ -f "$BEST_DIR/$AD_PROBE_NAME-probe-status.json" ]; then cp "$BEST_DIR/$AD_PROBE_NAME-probe-status.json" "$AD_PROBE_STAGE/"; fi
        if { [ "$BEST_LABEL" = launch ] || [ "$BEST_LABEL" = transition ]; } && [ -f "$AD_PROBE_ROOT/$AD_PROBE_NAME-launch-sb-probe.txt" ]; then
            tail -c 2097152 "$AD_PROBE_ROOT/$AD_PROBE_NAME-launch-sb-probe.txt" > "$AD_PROBE_STAGE/launch-springboard-last2MiB.txt"
        fi
        {
            printf 'AmazonDark v%s transition/lifecycle probe\n' "$AD_PROBE_VERSION"
            printf 'mode=%s\n' "$BEST_LABEL"
            printf 'armed_epoch=%s\n' "$BEST_ARM"
            printf 'session_ms=%s\n' "$BEST_MS"
            printf 'source=%s\n' "${BEST_FILE##*/}"
            printf 'archive=plain-tar\n'
            printf 'exported_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
        } > "$AD_PROBE_STAGE/manifest.txt"
        archive="$AD_PROBE_DOCS/$AD_PROBE_NAME-$BEST_LABEL-probe-$(date +%Y%m%d-%H%M%S)-$$.tar"
    else
        {
            printf 'AmazonDark v%s transition/lifecycle probe\n' "$AD_PROBE_VERSION"
            printf 'capture=missing\nreason_code=%s\n' "$rc"
            printf 'archive=plain-tar\n'
            printf 'exported_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
        } > "$AD_PROBE_STAGE/manifest.txt"
        archive="$AD_PROBE_DOCS/$AD_PROBE_NAME-transition-diagnostic-$(date +%Y%m%d-%H%M%S)-$$.tar"
    fi
    make_tar "$archive" "$AD_PROBE_STAGE"
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    rm -f "$AD_PROBE_LAUNCH_ARM"
    if [ "$rc" -eq 0 ]; then
        printf 'Exported exactly one current v%s %s capture plus diagnostics:\n%s\n' "$AD_PROBE_VERSION" "$BEST_LABEL" "$archive"
    else
        printf 'No current capture matched this arm; exported diagnostics only:\n%s\n' "$archive"
    fi
    ;;
 disarm)
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    rm -f "$AD_PROBE_LAUNCH_ARM"
    printf 'Future launches disarmed. The export state is preserved so the current capture can still be exported.\n'
    ;;
 *) printf 'Usage: sh scripts/skeleton-probe.sh arm [home|cart|both|launch|transition] | status | export | disarm\n' >&2; exit 1;;
esac
