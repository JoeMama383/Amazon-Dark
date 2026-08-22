# AmazonDark v6.0.209 — switches that actually fire

## What went wrong in v6.0.208

The four bisect switches read `fileExistsAtPath:@"/var/mobile/.ad_off_*"`. That runs
inside Amazon, which is sandboxed and cannot stat paths outside its own container. Every
flag read `NO`, so all four were inert — which is why the app stayed fully dark with
`.ad_off_twb` set, when it should have left product images visibly untamed.

The same sandbox silently blocked the probe writes for three earlier builds. The lesson
was available and I did not apply it. `.ad_dr_proxy` and `.ad_no_defer` from v6.0.166
and v6.0.171 have the identical defect, so any conclusion drawn from those toggles is
void as well.

## The fix

All four switches move onto `NSUserDefaults(suiteName: com.colindavidr.amazondark)` —
the same path every other preference already uses, which reaches Amazon through
`cfprefsd` and is permitted inside the sandbox. That mechanism is proven: it is how the
theming toggles work today.

Set with `defaults write`, force-quit Amazon, relaunch.

    defaults write com.colindavidr.amazondark offSymbols  -bool YES
    defaults write com.colindavidr.amazondark offTWB      -bool YES
    defaults write com.colindavidr.amazondark offContrast -bool YES
    defaults write com.colindavidr.amazondark offBoot     -bool YES

Clear one with `-bool NO`.

**Confirm a switch is live before spending a test on it.** `offTWB YES` must leave
product images with pale studio backdrops. If theming looks unchanged, the switch did
not take and the test is meaningless — that is exactly the trap v6.0.208 fell into.

## Kept

- **v6.0.206** — 16 `:where(div,span,section):has(> …)` instances scoped to
  `[data-component-type=s-search-result]`; zero unconstrained `:has()` remain.
- **v6.0.207** — PDP and Search schedule the contrast lanes idle-only, so they cannot be
  promoted to deadline tasks mid-hydration.

Both are real reductions. Neither fixed the tap delay.

## Verification

- Each switch: one struct field, one prefs read, four use sites.
- The sandboxed `ADWebFlag208` reader is gone from the source.
- Declared-before-use audit clean; balance 0/0/0; payloads parse; lint-logos.
