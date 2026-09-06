#!/bin/sh
# Run in NewTerm as mobile. Arming never kills/restarts Amazon or changes its UI.
set -eu
AD_PROBE_ROOT=/var/mobile
AD_PROBE_ARM="$AD_PROBE_ROOT/AmazonDark-v7.339-skeleton.arm"
AD_PROBE_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
case "${1:-}" in
    arm)
        AD_PROBE_LABEL=${2:-both}
        case "$AD_PROBE_LABEL" in home|cart|both) ;; *) printf 'Use arm home, arm cart, or arm both.\n' >&2; exit 1;; esac
        umask 077
        printf '%s %s\n' "$(( $(date +%s) + 300 ))" "$AD_PROBE_LABEL" > "$AD_PROBE_ARM"
        printf 'Armed %s. Start a fresh Amazon process within 5 minutes. Capture ends after 2 minutes.\n' "$AD_PROBE_LABEL"
        ;;
    status)
        if [ -f "$AD_PROBE_ARM" ]; then printf 'Arm file: '; cat "$AD_PROBE_ARM"; else printf 'Not armed for another launch.\n'; fi
        for AD_PROBE_FILE in "$AD_PROBE_ROOT"/AmazonDark-v7.339-skeleton-*.jsonl; do
            [ -f "$AD_PROBE_FILE" ] || continue
            ls -lh "$AD_PROBE_FILE"
            tail -n 1 "$AD_PROBE_FILE"
        done
        ;;
    export)
        [ -d "$AD_PROBE_DOCS" ] || { printf 'Shared Documents folder is missing.\n' >&2; exit 1; }
        set --
        for AD_PROBE_FILE in "$AD_PROBE_ROOT"/AmazonDark-v7.339-skeleton-*.jsonl; do
            [ -f "$AD_PROBE_FILE" ] || continue
            set -- "$@" "${AD_PROBE_FILE##*/}"
        done
        [ "$#" -gt 0 ] || { printf 'No v7.339 skeleton capture found. Force-close Amazon, arm, then reopen it.\n' >&2; exit 1; }
        AD_PROBE_ARCHIVE="$AD_PROBE_DOCS/AmazonDark-v7.339-skeleton-probes-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$AD_PROBE_ARCHIVE" -C "$AD_PROBE_ROOT" "$@"
        rm -f "$AD_PROBE_ARM"
        printf 'Exported %s log(s): %s\n' "$#" "$AD_PROBE_ARCHIVE"
        ;;
    disarm)
        rm -f "$AD_PROBE_ARM"
        printf 'Future launches are unarmed. A running capture ends at its 2-minute deadline or when Amazon closes.\n'
        ;;
    *) printf 'Usage: sh scripts/skeleton-probe.sh arm [home|cart|both] | status | export | disarm\n' >&2; exit 1;;
esac
