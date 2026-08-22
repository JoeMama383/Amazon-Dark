# AmazonDark v6.0.210

Base: v6.0.185~probe, carrying v6.0.206, v6.0.207 and v6.0.209.

## The change

`disableStyleSheetsProxy` goes from `false` to `true`.

That proxy wraps `insertRule` / `deleteRule` and the stylesheet collections so any sheet
created after `enable()` re-enters Dark Reader and is re-themed. Search results and PDP
build sheets continuously during hydration, and every one of them re-enters — on the
main thread, in exactly the window where taps are not registering.

This is confirmed by the only toggle in this session that provably works: with **Web
Dark Reader disabled, pages load instantly**. The cost is Dark Reader's, and the proxy
is its largest per-mutation component.

This fix was applied once before, in v6.0.166/167, but that was on a different branch.
v6.0.206–209 are all built on v6.0.185, where the setting was still `false`.

**The trade:** stylesheets injected after the first pass are no longer auto-themed, so a
late-hydrating widget can stay light until something else triggers a re-apply. Watch
Home and Search for anything that renders light and stays light.

## Why the v6.0.208/209 switches are not in play

v6.0.208's switches read `fileExistsAtPath:@"/var/mobile/.ad_off_*"` from inside
Amazon, which is sandboxed and cannot stat outside its own container — all four were
inert. v6.0.209 moved them onto the prefs domain, and `offTWB = 1` still did not take
effect on device, so that mechanism is unproven too. They remain in the source but
should not be trusted until one is shown to change something visible.

The existing **Web Dark Reader** preference does work, and it is what identified the
cause.

## Kept

- **v6.0.206** — 16 `:where(div,span,section):has(> …)` instances scoped to
  `[data-component-type=s-search-result]`; zero unconstrained `:has()` remain.
- **v6.0.207** — PDP and Search schedule the contrast lanes idle-only, so they cannot be
  promoted to deadline tasks mid-hydration.

## Verification

- `disableStyleSheetsProxy:true` confirmed in the emitted fixes payload.
- All payloads parse; balance 0/0/0; `scripts/lint-logos.sh`.

## If this is not enough

The next step is not another setting. It is to stop calling `enable()` on repeat visits:
run Dark Reader once, capture `exportGeneratedCSS()`, and inject that as a plain
stylesheet on later loads — no sheet parsing, no DOM walk, no observer. That is a real
build, and worth doing only if this one moves the needle in the right direction first.
