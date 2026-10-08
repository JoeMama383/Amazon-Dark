# AmazonDark v7.596 validation

Command: `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`.

Result: **PASS — all 251 Python regression scripts**, plus the validation wrapper's logo, source and probe checks. No skipped regression was counted as a pass.

New checks exercise:

- Recorder reinjection, buffer bounds, unsupported WebKit APIs, input/resource aggregation, deadline/pagehide cleanup, stopped-document restart, and absence of URL/input-value collection.
- C++98 timing-scope inactive/generation guards; Objective-C++/gnu++98 syntax preflight of the complete new native recorder against declaration stubs.
- Shell arm/export behavior with mock app receipts/package state, stale-session rejection and one-file current-session TAR contents.
- Probe-shaped thank-you fixtures: exact floors/buttons/glyphs/dividers, semantic-color and unrelated-menu negatives, artwork-only dimming at disabled/0/45/100 strength, generated include equality and idempotent delivery.
- Repeated Medical delivery/event bursts, stable shadow styles, removed duplicate image work and unreachable helpers.
- Executed production cache guards: reuse for unchanged preferences, regeneration for dimming-toggle/strength changes, clamping and immutable non-dependent scripts. All 18 supplied core modules must have matching format slots.

Historical tests retain their existing payload checks. Five historical core-hash normalizers were updated only for the independently tested cache-key/format-slot correction; the old 17-slot assertion now requires 18. The Medical extraction boundary was moved to include its new idempotent event guard.

Environment: Linux, Python 3.12, Node, Clang via Zig 0.13; tinycss2/cssselect2/lxml for CSS fixture matching. The compiler declaration stubs validate syntax, not Apple SDK ABI or device behavior.

**Limits:** no Theos/iOS SDK package build or iPhone execution was available here. The supplied pre-change FULL probe completed, but no post-change device probe, screenshot or measured speedup is claimed. The repository CI must build the installable package after the source is pushed; visual and performance confirmation require a device run.
