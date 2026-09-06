#!/bin/sh
# NewTerm/mobile. Resolve Amazon's data container; never write probe data into another app.
set -eu
AD_PROBE_VERSION=7.341
AD_PROBE_ROOT=${AD_PROBE_ROOT:-/var/mobile}
AD_PROBE_CONTAINERS=${AD_PROBE_CONTAINERS:-$AD_PROBE_ROOT/Containers/Data/Application}
AD_PROBE_DOCS=${AD_PROBE_DOCS:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
AD_PROBE_NAME=AmazonDark-v7.341
AD_PROBE_TARGETS=$(mktemp)
trap 'rm -f "$AD_PROBE_TARGETS"' EXIT HUP INT TERM
AD_PROBE_SEEN=0
AD_PROBE_READABLE=0
# Support Apple's plutil and the rootless plutil variants used on the phone.
for AD_PROBE_META in "$AD_PROBE_CONTAINERS"/*/.com.apple.mobile_container_manager.metadata.plist; do
    [ -f "$AD_PROBE_META" ] || continue
    AD_PROBE_SEEN=$((AD_PROBE_SEEN+1))
    if [ -r "$AD_PROBE_META" ]; then AD_PROBE_READABLE=$((AD_PROBE_READABLE+1)); fi
    AD_PROBE_ID=$(plutil -extract MCMMetadataIdentifier raw -o - "$AD_PROBE_META" 2>/dev/null || true)
    if [ "$AD_PROBE_ID" != com.amazon.Amazon ]; then
        AD_PROBE_ID=$(plutil -convert xml1 -o - "$AD_PROBE_META" 2>/dev/null | awk '
          /<key>MCMMetadataIdentifier<\/key>/ {take=1}
          take && /<string>/ {s=$0;sub(/^.*<string>/,"",s);sub(/<\/string>.*$/,"",s);print s;exit}' || true)
    fi
    if [ "$AD_PROBE_ID" != com.amazon.Amazon ]; then
        AD_PROBE_ID=$(plutil -p "$AD_PROBE_META" 2>/dev/null | awk '
          /"MCMMetadataIdentifier"/ && /"com[.]amazon[.]Amazon"/ {print "com.amazon.Amazon";exit}' || true)
    fi
    if [ "$AD_PROBE_ID" = com.amazon.Amazon ]; then
        printf '%s\n' "${AD_PROBE_META%/*}/Documents" >> "$AD_PROBE_TARGETS"
    fi
done
ad_report() {
    printf 'Helper version: %s\nUTC: ' "$AD_PROBE_VERSION"
    date -u
    printf 'Installed package: '
    dpkg-query -W -f='${Package} ${Version}\n' com.joemama383.amazondark 2>&1 || true
    printf 'plutil: %s; metadata files seen=%s readable=%s\n' "$(command -v plutil || printf missing)" "$AD_PROBE_SEEN" "$AD_PROBE_READABLE"
    printf 'Amazon container matches: %s\n' "$(wc -l < "$AD_PROBE_TARGETS" | tr -d ' ')"
    while IFS= read -r AD_PROBE_DIR; do
        printf 'Amazon Documents: %s\n' "$AD_PROBE_DIR"
        for AD_PROBE_FILE in "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm" "$AD_PROBE_DIR/$AD_PROBE_NAME-probe-status.json"; do
            if [ -f "$AD_PROBE_FILE" ]; then
                printf '%s: ' "${AD_PROBE_FILE##*/}"
                cat "$AD_PROBE_FILE"
                printf '\n'
            else printf 'Missing: %s\n' "${AD_PROBE_FILE##*/}"; fi
        done
        for AD_PROBE_FILE in "$AD_PROBE_DIR"/AmazonDark-v7.*-skeleton-*.jsonl; do
            [ -f "$AD_PROBE_FILE" ] || continue
            ls -ln "$AD_PROBE_FILE"
            head -n 1 "$AD_PROBE_FILE"
        done
    done < "$AD_PROBE_TARGETS"
    printf 'SpringBoard artwork log:\n'
    if [ -f "$AD_PROBE_ROOT/AmazonDark-v7.338-launch-sb-probe.txt" ]; then
        ls -ln "$AD_PROBE_ROOT/AmazonDark-v7.338-launch-sb-probe.txt"
        tail -n 12 "$AD_PROBE_ROOT/AmazonDark-v7.338-launch-sb-probe.txt"
    else printf 'Missing: AmazonDark-v7.338-launch-sb-probe.txt\n'; fi
}
case "${1:-}" in
 arm)
    AD_PROBE_LABEL=${2:-both}
    case "$AD_PROBE_LABEL" in home|cart|both|launch) ;; *) printf 'Use arm home, cart, both, or launch.\n' >&2; exit 1;; esac
    [ -s "$AD_PROBE_TARGETS" ] || { ad_report; printf 'Cannot identify Amazon data container. Open Amazon once, then retry; send this output if still missing.\n' >&2; exit 1; }
    AD_PROBE_INSTALLED=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
    case "$AD_PROBE_INSTALLED" in 7.341~*) ;; *) printf 'Install the v7.341 Actions package first. Installed: %s\n' "$AD_PROBE_INSTALLED" >&2; exit 1;; esac
    umask 077
    while IFS= read -r AD_PROBE_DIR; do
        mkdir -p "$AD_PROBE_DIR"
        printf '%s %s\n' "$(( $(date +%s) + 300 ))" "$AD_PROBE_LABEL" > "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"
        printf 'Armed %s in %s\n' "$AD_PROBE_LABEL" "$AD_PROBE_DIR"
    done < "$AD_PROBE_TARGETS"
    if [ "$AD_PROBE_LABEL" = launch ]; then
        printf 'Force-close and open Amazon within 5 minutes. Repeat cold launches as needed within that window. Each process records at most 20 seconds and stops on background.\n'
    else
        printf 'Force-close and open Amazon within 5 minutes. Home/Cart capture runs for up to 2 minutes.\n'
    fi
    printf 'After opening Amazon, status must show SESSION_START and a nonempty capture file.\n'
    ;;
 status) ad_report ;;
 export)
    [ -d "$AD_PROBE_DOCS" ] || { printf 'Shared Documents folder is missing: %s\n' "$AD_PROBE_DOCS" >&2; exit 1; }
    AD_PROBE_STAGE=$(mktemp -d)
    trap 'rm -f "$AD_PROBE_TARGETS"; rm -rf "$AD_PROBE_STAGE"' EXIT HUP INT TERM
    ad_report > "$AD_PROBE_STAGE/diagnostic-status.txt" 2>&1
    AD_PROBE_COUNT=0
    while IFS= read -r AD_PROBE_DIR; do
        AD_PROBE_UUID=${AD_PROBE_DIR%/Documents}; AD_PROBE_UUID=${AD_PROBE_UUID##*/}
        mkdir -p "$AD_PROBE_STAGE/$AD_PROBE_UUID"
        for AD_PROBE_FILE in "$AD_PROBE_DIR"/AmazonDark-v7.*-skeleton-*.jsonl "$AD_PROBE_DIR/$AD_PROBE_NAME-probe-status.json"; do
            [ -f "$AD_PROBE_FILE" ] || continue
            cp "$AD_PROBE_FILE" "$AD_PROBE_STAGE/$AD_PROBE_UUID/"
            case "$AD_PROBE_FILE" in *.jsonl) AD_PROBE_COUNT=$((AD_PROBE_COUNT+1));; esac
        done
    done < "$AD_PROBE_TARGETS"
    # Recover any capture from the previous helper's outside-container location too.
    for AD_PROBE_FILE in "$AD_PROBE_ROOT"/AmazonDark-v7.*-skeleton-*.jsonl; do
        [ -f "$AD_PROBE_FILE" ] || continue
        cp "$AD_PROBE_FILE" "$AD_PROBE_STAGE/"
        AD_PROBE_COUNT=$((AD_PROBE_COUNT+1))
    done
    if [ -f "$AD_PROBE_ROOT/AmazonDark-v7.338-launch-sb-probe.txt" ]; then
        tail -c 4194304 "$AD_PROBE_ROOT/AmazonDark-v7.338-launch-sb-probe.txt" > "$AD_PROBE_STAGE/launch-springboard-last4MiB.txt"
    fi
    AD_PROBE_ARCHIVE="$AD_PROBE_DOCS/$AD_PROBE_NAME-probes-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
    tar -czf "$AD_PROBE_ARCHIVE" -C "$AD_PROBE_STAGE" .
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    printf 'Exported %s app capture(s), status report and available SpringBoard log:\n%s\n' "$AD_PROBE_COUNT" "$AD_PROBE_ARCHIVE"
    if [ "$AD_PROBE_COUNT" -eq 0 ]; then printf 'No app capture ran. Upload this archive anyway: it contains the failure diagnostics.\n'; fi
    ;;
 disarm)
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    printf 'Future launches disarmed. Existing capture stops at its deadline or app close.\n'
    ;;
 *) printf 'Usage: sh scripts/skeleton-probe.sh arm [home|cart|both|launch] | status | export | disarm\n' >&2; exit 1;;
esac
