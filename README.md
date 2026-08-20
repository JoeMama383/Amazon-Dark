# AmazonDark v6.0.167

One change, on the 6.0.165 tree. Everything else is untouched.

## What the bisection established

Not argued — eliminated, one toggle at a time:

- 5.43.0 renders the heavy PDP section (slowly); 6.0.165 never finishes.
- White Background Taming off: still fails. TWB excluded.
- 5.43.0 has no symbols script at all and fails the same way. Symbols script excluded,
  and with it the whole 96KB of bootstrap growth between the two builds.
- Tweak fully off: renders fine. So it is us.
- What both builds share is exactly three things: an identical `darkreader.js`, an
  equivalent theme object, and the documentStart floor sheet.
- Independent confirmation: when Dark Reader silently failed to apply while the rest of
  the tweak still ran, performance jumped roughly tenfold.

The cost is Dark Reader's dynamic theme, not the code around it. The 824ms of native
hook time measured across a whole session was never going to explain this.

## The change

`disableStyleSheetsProxy` was `false`, which leaves Dark Reader's CSSOM proxy
installed. That proxy wraps `insertRule`/`deleteRule` and the sheet collections so
stylesheets created after `enable()` get re-themed. Amazon's PDP builds a large number
of sheets during hydration and each one re-enters Dark Reader through it. Turning the
proxy off keeps the initial theming pass and drops the re-entry.

`ignoreImageAnalysis:['*']` was already set, so Dark Reader is not fetching or
analysing those publisher images. If Dark Reader is the cause it is the stylesheet and
DOM pass, which is what this targets.

**The trade, stated plainly:** stylesheets injected after the first pass are no longer
auto-themed, so a late-hydrating widget can stay light until something else triggers a
re-apply. Visible but usable, versus content that never appears.

## Switchable

Both sides can be compared in one install:

    touch /var/mobile/.ad_dr_proxy   restore the proxy (6.0.165 behaviour)
    rm    /var/mobile/.ad_dr_proxy   proxy off (6.0.167 default)

Relaunch Amazon after either. The flag is read once per launch.

## If it does not help

Then the stall is Dark Reader's initial pass rather than the proxy, and the next step
is a different architecture, not another knob: cache `exportGeneratedCSS()` per origin
and inject it as a plain stylesheet on subsequent loads, so heavy pages get themed CSS
with no DOM walk at all.

## Fix from v6.0.166

v6.0.166 failed to compile: `ADDRProxyWanted166` was defined above `ADThemeLiteral`,
but `ADFixesLiteral` sits above that and calls it — used before declared. The helper is
now defined above `ADFixesLiteral`. No other change.

The clang harness in this repo compiled only the instrumentation core, which is why it
did not catch this. It now also compiles the real `ADFixesLiteral` region against
Foundation stubs, and a declared-before-use audit runs over every `static AD*` helper.

## Verification

- Both emitted variants of the fixes literal (`proxy:true` and `proxy:false`) parse as
  JavaScript.
- Format specifiers and arguments in the fixes literal: 2 and 2.
- Bootstrap payload unchanged; all other payloads parse.
- Whole-file balance 0/0/0, `scripts/lint-logos.sh`.
- v6.0.163 hook instrumentation retained; dump file is now `-167`.
