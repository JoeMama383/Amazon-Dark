# Amazon Dark

True dark mode for the Amazon Shopping iOS app — a real dark theme, not a colour inversion.

Rootless jailbreak (NathanLR / ellekit), arm64 + arm64e, iOS 15+.
Built against Amazon Shopping **27.11.8**.

---

## Why v5 is a rewrite

Every v3.x build applied a `colorInvert` CAFilter to the top-level `UIWindow`, then
tried to *counter-invert* image layers back to normal. That approach fails for a
reason no amount of tuning fixes: an inversion cannot tell a background from a
photograph. Every image class must be enumerated and exempted by hand, the
counter-filters land a layout pass late, and anything missed ships as a negative.
The binary only defines **8** image-view classes, and the tweak was chasing them
one regression at a time.

v5 stops inverting anything.

| Surface | Method | Images |
|---|---|---|
| Web views (Home, Cart, product, search) | Bundled **Dark Reader** engine | Untouched by design |
| Native chrome (tab bar, nav/search bar) | Amazon's **own** native dark theme | Amazon's own assets |
| Native content (cells, sheets, RN views) | **Dark Reader colour algorithm, ported to Obj-C** | Never on the code path |

Images are safe *structurally*, not by exemption. The colour engine intercepts
colour **declarations** — `backgroundColor`, `textColor`, `tintColor`, `borderColor`.
It never touches `layer.contents`, never installs a `CAFilter`, and never sees a
`CGImage`. A photograph is not a colour, so it is never modified. There is no
allowlist left to maintain.

---

## How the colour engine works

`src/ADColor.m` is a port of Dark Reader's dynamic-theme algorithm
(`modify-colors.ts` + `matrix.ts`). Each colour is converted to HSL and re-mapped
along a curve chosen by its role:

- **Backgrounds** fall toward the dark pole (default `#181a1b`), clamped so a light
  surface lands under 40% lightness.
- **Text and tints** rise toward the light pole (default `#e8e6e3`), floored at 55%
  lightness so nothing goes muddy. Blue hues are nudged toward 220° so links stay
  readable.
- **Borders** compress toward the middle so dividers stay visible without glowing.

Hue and saturation survive the transform, so Amazon orange stays orange and link
blue stays blue — they just sit at a lightness that works on a dark surface. The
brightness/contrast/grayscale/sepia sliders are applied afterwards as a 5×5 colour
matrix, deliberately **without** Dark Reader's invert term.

The port is differential-tested against a direct transcription of the upstream
TypeScript: **bit-identical across 2,187 colour/role combinations**.

Tinting is treated as foreground, which is what keeps tab-bar glyphs visible once
the bar behind them goes dark — the exact failure that broke v3.2.1.

---

## Build

CI builds the rootless `.deb` on every push (`.github/workflows/build.yml`) and
attaches it to releases. Locally, with Theos installed:

```bash
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The Dark Reader engine is vendored at `Resources/darkreader.js` (MIT) and installed
beside the dylib as `AmazonDark.bundle`. To refresh it:

```bash
npm pack darkreader && tar -xzO -f darkreader-*.tgz package/darkreader.js > Resources/darkreader.js
```

## Install

```bash
ssh root@<device> "rm -f /var/mobile/*.deb"
scp packages/*.deb root@<device>:/var/mobile/
ssh root@<device> "dpkg -i /var/mobile/com.colindavidr.amazondark_*.deb"
```

Then **force-quit and relaunch Amazon**. No respring — the tweak injects per-app.
Injection must be enabled for Amazon in NathanLR's app list, or the dylib never loads.

## Verify

```bash
ssh root@<device> "find /var/mobile/Containers/Data/Application -name 'AmazonDark.log' 2>/dev/null | head -1 | xargs cat"
```

Logging goes to `$TMPDIR` because a sandboxed app cannot write to `/var/mobile`.

## Settings

Settings → AmazonDark: master toggle, per-surface toggles, brightness / contrast /
grayscale / sepia, and hex background/text poles. Set the background pole to
`#000000` for OLED black. Changes apply on next foreground.

If a native screen ever looks wrong, turn off **Recolor native content** — web and
native chrome keep working independently.

---

## Notes

- `Info.plist` of the app hard-pins `UIUserInterfaceStyle = Light`. That is why every
  earlier attempt to force the trait alone kept getting clawed back; the window-level
  override in `ADForceWindowsDarkTrait` is what actually sticks.
- Amazon ships a complete native dark theme gated behind one Weblab
  (`NAVX_DARK_MODE_IOS_1283655`, default treatment `C` = off). v5 flips it client-side
  for the chrome. Server-driven SSNAP content will not return dark colour tokens for
  accounts outside the cohort — which is precisely why the local colour engine exists.
- Zero Obj-C runs in `%ctor` (raw `write()` only); all work is deferred to the main
  queue. Every hook body is wrapped in `@try/@catch`. No auto-`killall` in `postinst`.

## Credits

Colour algorithm ported from [Dark Reader](https://github.com/darkreader/darkreader)
(MIT, © Dark Reader Ltd.) — see `Resources/DARKREADER-LICENSE`.

High-FPS display-link forcing pattern adapted from [PoomSmart/CAHighFPS](https://github.com/PoomSmart/CAHighFPS) (MIT).

## v6.0.17

- Restores the v5.446 long-review/description expander-fade fix: Amazon's white read-more scrim is neutralized before it can paint over long copy.
- Uses CSS-only paint suppression on the known expander fade elements/pseudo-elements; no observer, timer, DOM scan, or scroll-time work is added.
- Deliberately does **not** revive the old broad `[class*=gradient]` suppression that historically hid real content.
- Preserves the confirmed-working v6.0.16 store/avatar protection, v6.0.15 native ad islands, checkbox, chrome, fast-scroll floor, and reversible 60/120 Hz behavior.

## v6.0.16

- Restores v5.446 protection for small circular content images so store/shop logos and review/profile avatars are not claimed by the generic monochrome glyph repair.
- Uses only candidate-local checks: content ancestry, meaningful image alt text, and circular display geometry backed by a larger natural bitmap. No new observer, timer, DOM sweep, or pixel analysis.
- Preserves v6.0.15 native ad islands and all known-good 6.x performance, checkbox, chrome, fast-scroll, and reversible 60/120 Hz behavior.

## v6.0.15

- Treats Home promotional/sponsored carousel cards as **Amazon-native ad islands**: generic contrast, glyph, TWB, and backdrop painters skip those subtrees.
- Restores the v5.446 web-image backdrop policy: no blanket `img { background }`; only explicitly opted-in `img[data-adbackdrop]` can receive a dark backing. This removes the rectangular black plates behind transparent brand/logo artwork.
- Adds the v5.446-style Dark Reader escape path in a leaner form: ad roots are marked before Dark Reader starts, ignored by inline-style processing, and any Dark Reader inline ownership metadata/custom properties are stripped without deleting Amazon's original inline CSS values.
- Ad-only DOM churn no longer schedules a full contrast-repair sweep.
- The proven checkbox, dark top chrome, reversible 60/120 Hz force, fast-scroll dark floor, and v6.0.13 runtime cleanup are otherwise unchanged.

## v6.0.14

- Fast-scroll white-floor follow-up: darkens the inner `WKContentView` root canvas so recycled/unpainted WebKit tiles cannot expose the stock white content backing during aggressive flings.
- Adds a root-only documentStart floor for `html`, `body`, `#a-page`, `#gwm-PageContent`, and `main` before Dark Reader parses.
- No per-scroll repaint loop. v6.0.11 live 60/120 Hz toggle behavior and the working v5.446 checkbox/top-chrome owners are unchanged.

## v6.0.11

- Keeps the v5.446 checkbox first-paint CSS, `sym413`, and `stockCheckbox434` owner byte-identical to the working donor.
- Restores the missing v5.446 dependency in the broad glyph-repair pass: native checkbox/Compare subtrees are excluded **before** generic inversion, and generic glyph writes are tagged `gfix1` / `gfix2` so `stockCheckbox434` can remove them if they ever collide. This is the path that produced the white-box regression.
- Preserves the confirmed-good v6.0.6 dark top chrome and the bounded v6.0.7 launch/performance architecture.
- Changes the refresh-rate option to **Force 120 Hz**. AmazonDark still exposes both ProMotion bundle opt-ins, but now also attempts the private per-process `CADisplay` minimum-frame-duration policy before every display-link request.
- Uses the open-source CAHighFPS high-FPS pattern for the public-facing display-link setters: `frameInterval=1`, `preferredFramesPerSecond=0` (highest available), and a `30...120` range with 120 preferred/max on a 120-Hz panel. Amazon attempts to lower these values are intercepted while the preference is enabled.
- Does not inject a new hook into `backboardd` or force SpringBoard system-wide. The first private-force test stays scoped to Amazon so a bad private selector cannot destabilize the rest of the UI.
- The one-shot verifier now reports private-force API/hook availability plus display refresh, display-link maximum/actual FPS, minimum frame duration, requested range, and measured target timing.


## v6.0.11
- Makes Force 120 Hz truly live-toggleable: OFF restores tracked display links to 60 Hz and private CADisplay duration 4; ON reapplies the proven v6.0.10 120-Hz force immediately.
- Bundle high-refresh opt-ins now report enabled only while the preference is enabled.
- The one-shot verifier now runs in both ON and OFF states so an old 120-Hz report cannot be mistaken for a fresh disabled result.
- Adds a constant-time dark backing floor to WKWebView/WKScrollView so fast 120-Hz flings reveal the dark theme rather than WebKit's default white backing while lazy tiles/content catch up.
- Checkbox and v5.446 top-chrome logic are unchanged from v6.0.10.
