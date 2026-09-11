#!/bin/sh
# NewTerm/mobile. Resolve Amazon's data container; never write probe data into another app.
set -eu
AD_PROBE_VERSION=7.398
AD_PROBE_ROOT=${AD_PROBE_ROOT:-/var/mobile}
AD_PROBE_CONTAINERS=${AD_PROBE_CONTAINERS:-$AD_PROBE_ROOT/Containers/Data/Application}
AD_PROBE_DOCS=${AD_PROBE_DOCS:-/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents}
AD_PROBE_NAME=AmazonDark-v7.398
AD_PROBE_TARGETS=$(mktemp)
AD_PROBE_LAUNCH_ARM="$AD_PROBE_ROOT/AmazonDark-launch-probe.arm"
trap 'rm -f "$AD_PROBE_TARGETS"' EXIT HUP INT TERM
AD_PROBE_SEEN=0
AD_PROBE_READABLE=0
# Support Apple's plutil and the rootless plutil variants used on the phone.
for AD_PROBE_META in "$AD_PROBE_CONTAINERS"/*/.com.apple.mobile_container_manager.metadata.plist; do
    [ -f "$AD_PROBE_META" ] || continue
    AD_PROBE_SEEN=$((AD_PROBE_SEEN+1))
    if [ -r "$AD_PROBE_META" ]; then AD_PROBE_READABLE=$((AD_PROBE_READABLE+1)); fi
    AD_PROBE_ID=$(plutil -extract MCMMetadataIdentifier raw -o - "$AD_PROBE_META" 2>/dev/null || true)
    # A successful non-Amazon identifier is definitive. Fall back to alternate plutil
    # dialects only when the preferred extraction was unsupported/empty.
    if [ -z "$AD_PROBE_ID" ]; then
        AD_PROBE_ID=$(plutil -convert xml1 -o - "$AD_PROBE_META" 2>/dev/null | awk '
          /<key>MCMMetadataIdentifier<\/key>/ {take=1}
          take && /<string>/ {s=$0;sub(/^.*<string>/,"",s);sub(/<\/string>.*$/,"",s);print s;exit}' || true)
    fi
    if [ -z "$AD_PROBE_ID" ]; then
        AD_PROBE_ID=$(plutil -p "$AD_PROBE_META" 2>/dev/null | awk '
          /"MCMMetadataIdentifier"/ && /"com[.]amazon[.]Amazon"/ {print "com.amazon.Amazon";exit}' || true)
    fi
    if [ "$AD_PROBE_ID" = com.amazon.Amazon ]; then
        printf '%s\n' "${AD_PROBE_META%/*}/Documents" >> "$AD_PROBE_TARGETS"
    fi
done
# Read the current receipt or verified recent receipts left during upgrade.
# These identify Amazon without relying on the phone's plutil implementation.
AD_PROBE_RECEIPTS=0
for AD_PROBE_RECEIPT in "$AD_PROBE_CONTAINERS"/*/Documents/AmazonDark-v7.*-probe-status.json; do
    [ -f "$AD_PROBE_RECEIPT" ] || continue
    # The receipt filename and payload must agree on a supported AmazonDark version.
    # This removes the per-release duplicated filename/regex allowlist that broke v7.391.
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT##*/}
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER#AmazonDark-v7.}
    AD_PROBE_RECEIPT_VER=${AD_PROBE_RECEIPT_VER%-probe-status.json}
    case "$AD_PROBE_RECEIPT_VER" in ''|*[!0-9]*) continue;; esac
    [ "$AD_PROBE_RECEIPT_VER" -ge 344 ] 2>/dev/null || continue
    [ "$AD_PROBE_RECEIPT_VER" -le 399 ] 2>/dev/null || continue
    if LC_ALL=C grep -Eq '"bundle"[[:space:]]*:[[:space:]]*"com[.]amazon[.]Amazon"' "$AD_PROBE_RECEIPT" &&
       LC_ALL=C grep -Eq '"event"[[:space:]]*:[[:space:]]*"PROBE_BOOTSTRAP"' "$AD_PROBE_RECEIPT" &&
       LC_ALL=C grep -Eq '"version"[[:space:]]*:[[:space:]]*"v7[.]'"$AD_PROBE_RECEIPT_VER"'-' "$AD_PROBE_RECEIPT"; then
        AD_PROBE_RECEIPTS=$((AD_PROBE_RECEIPTS+1))
        AD_PROBE_DIR=${AD_PROBE_RECEIPT%/*}
        if ! grep -Fqx "$AD_PROBE_DIR" "$AD_PROBE_TARGETS"; then
            printf '%s\n' "$AD_PROBE_DIR" >> "$AD_PROBE_TARGETS"
        fi
    fi
done
ad_report() {
    printf 'Helper version: %s\nUTC: ' "$AD_PROBE_VERSION"
    date -u
    printf 'Installed package: '
    dpkg-query -W -f='${Package} ${Version}\n' com.joemama383.amazondark 2>&1 || true
    printf 'plutil: %s; metadata files seen=%s readable=%s\n' "$(command -v plutil || printf missing)" "$AD_PROBE_SEEN" "$AD_PROBE_READABLE"
    printf 'Verified Amazon startup receipts: %s\n' "$AD_PROBE_RECEIPTS"
    printf 'Amazon container matches: %s\n' "$(wc -l < "$AD_PROBE_TARGETS" | tr -d ' ')"
    while IFS= read -r AD_PROBE_DIR; do
        printf 'Amazon Documents: %s\n' "$AD_PROBE_DIR"
        for AD_PROBE_FILE in "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm" "$AD_PROBE_DIR"/AmazonDark-v7.*-probe-status.json; do
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
    if [ -f "$AD_PROBE_ROOT/AmazonDark-v7.398-launch-sb-probe.txt" ]; then
        ls -ln "$AD_PROBE_ROOT/AmazonDark-v7.398-launch-sb-probe.txt"
        tail -n 12 "$AD_PROBE_ROOT/AmazonDark-v7.398-launch-sb-probe.txt"
    else printf 'Missing: AmazonDark-v7.398-launch-sb-probe.txt\n'; fi
}
case "${1:-}" in
 arm)
    AD_PROBE_LABEL=${2:-both}
    case "$AD_PROBE_LABEL" in home|cart|both|launch|transition) ;; *) printf 'Use arm home, cart, both, launch, or transition.\n' >&2; exit 1;; esac
    [ -s "$AD_PROBE_TARGETS" ] || { ad_report; printf 'Cannot identify Amazon data container. Open Amazon once, then retry; send this output if still missing.\n' >&2; exit 1; }
    AD_PROBE_INSTALLED=$(dpkg-query -W -f='${Version}' com.joemama383.amazondark 2>/dev/null || true)
    case "$AD_PROBE_INSTALLED" in 7.398~*) ;; *) printf 'Install the v7.398 Actions package first. Installed: %s\n' "$AD_PROBE_INSTALLED" >&2; exit 1;; esac
    umask 077
    while IFS= read -r AD_PROBE_DIR; do
        mkdir -p "$AD_PROBE_DIR"
        printf '%s %s\n' "$(( $(date +%s) + 300 ))" "$AD_PROBE_LABEL" > "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"
        printf 'Armed %s in %s\n' "$AD_PROBE_LABEL" "$AD_PROBE_DIR"
    done < "$AD_PROBE_TARGETS"
    if [ "$AD_PROBE_LABEL" = launch ] || [ "$AD_PROBE_LABEL" = transition ]; then
        printf '%s\n' "$(( $(date +%s) + 300 ))" > "$AD_PROBE_LAUNCH_ARM"
        chmod 600 "$AD_PROBE_LAUNCH_ARM" 2>/dev/null || true
    else
        rm -f "$AD_PROBE_LAUNCH_ARM"
    fi
    if [ "$AD_PROBE_LABEL" = launch ]; then
        printf 'Force-close and open Amazon within 5 minutes. Repeat cold launches as needed within that window. Each process records at most 20 seconds and stops on background.\n'
    elif [ "$AD_PROBE_LABEL" = transition ]; then
        printf 'Reproduce the target transition within 5 minutes. The armed trace records startup/native lifecycle evidence for up to 120 seconds per fresh process and stays armed across background/foreground cycles. For app-switcher/warm-resume issues, open Amazon, let the target page settle, enter the switcher, capture the teal card if it appears, then return to Amazon before exporting.\n'
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
        for AD_PROBE_FILE in "$AD_PROBE_DIR"/AmazonDark-v7.*-skeleton-*.jsonl "$AD_PROBE_DIR"/AmazonDark-v7.*-probe-status.json; do
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
    if [ -f "$AD_PROBE_ROOT/AmazonDark-v7.398-launch-sb-probe.txt" ]; then
        tail -c 4194304 "$AD_PROBE_ROOT/AmazonDark-v7.398-launch-sb-probe.txt" > "$AD_PROBE_STAGE/launch-springboard-last4MiB.txt"
    fi
    AD_PROBE_ARCHIVE="$AD_PROBE_DOCS/$AD_PROBE_NAME-probes-$(date +%Y%m%d-%H%M%S)-$$.tar"
    # No gzip child process or compression dependency. Publish only after success.
    if tar -cf "$AD_PROBE_ARCHIVE.partial" -C "$AD_PROBE_STAGE" .; then
        mv "$AD_PROBE_ARCHIVE.partial" "$AD_PROBE_ARCHIVE"
    else
        rm -f "$AD_PROBE_ARCHIVE.partial"
        AD_PROBE_ARCHIVE="${AD_PROBE_ARCHIVE%.tar}.txt"
        # Keep the failure evidence obtainable even if archiving itself fails.
        cat "$AD_PROBE_STAGE/diagnostic-status.txt" > "$AD_PROBE_ARCHIVE"
        for AD_PROBE_FILE in "$AD_PROBE_STAGE"/*.jsonl "$AD_PROBE_STAGE"/*/*.jsonl "$AD_PROBE_STAGE"/*/*-probe-status.json "$AD_PROBE_STAGE/launch-springboard-last4MiB.txt"; do
            [ -f "$AD_PROBE_FILE" ] || continue
            printf '\nFILE: %s\n' "${AD_PROBE_FILE#"$AD_PROBE_STAGE"/}" >> "$AD_PROBE_ARCHIVE"
            cat "$AD_PROBE_FILE" >> "$AD_PROBE_ARCHIVE"
        done
    fi
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    rm -f "$AD_PROBE_LAUNCH_ARM"
    printf 'Exported %s app capture(s), status report and available SpringBoard log:\n%s\n' "$AD_PROBE_COUNT" "$AD_PROBE_ARCHIVE"
    if [ "$AD_PROBE_COUNT" -eq 0 ]; then printf 'No app capture ran. Upload this archive anyway: it contains the failure diagnostics.\n'; fi
    ;;
 disarm)
    while IFS= read -r AD_PROBE_DIR; do rm -f "$AD_PROBE_DIR/$AD_PROBE_NAME-probe.arm"; done < "$AD_PROBE_TARGETS"
    rm -f "$AD_PROBE_LAUNCH_ARM"
    printf 'Future launches disarmed. Existing capture stops at its deadline or app close.\n'
    ;;
 *) printf 'Usage: sh scripts/skeleton-probe.sh arm [home|cart|both|launch|transition] | status | export | disarm\n' >&2; exit 1;;
esac
