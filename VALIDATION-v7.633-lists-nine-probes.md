# AmazonDark v7.633 — Nine-probe fix validation

## Source baseline & probe coverage
Source: previously released v7.633 web-cache C++98 compatibility archive. Analyzed all nine v7.630 TAR captures in user-uploaded archive and all eight screenshots. The nine captures are NOT nine independent WebKit documents: two OMG quick-list viewport captures, one native grocery viewport, one native grocery with bottom sheet, one native-only FULL, one detailed Wishlist FULL, one Create List viewport, one lists overview viewport, and one Your Saves/Add content viewport.

Visual captures identify unresolved dark-on-dark titles and prices, neutral white cards, sheets and controls, and yellow/orange UI buttons. The included repair is CSS-exact for WebKit; native repairs are hooked at authored React screen/accessibility owner events, including the exact orange Add Item plate in the native r7 capture.

## Checks run locally
- JavaScript grammar `node --check src/ADListsRegistry7633.js`: PASS.
- Shipped `.js.inc` byte-equivalent to source JavaScript; compiled/ran as adjacent C++ string literals in gnu++98 and clang++: PASS.
- Script runtime injects exactly one stylesheet even when invoked twice; JS brightness preference gets numeric value: PASS.
- `bash scripts/lint-logos.sh`: PASS.
- v7.596 web-cache gnu++98 fixture: PASS.
- v7.631 Search/PDP fast-path fixture: PASS.
- v7.633 inherited portable cache guard fixture: PASS.
- `bash -n` three probe helpers: PASS.
- New scoped UI/performance static regression test: PASS.
- Version-normalized recent historical regressions v7.596–v7.633: 45/45 PASS.
- Broader scripts/validate.sh ran for 175 seconds without a reported failure before historical regressions hit the execution limit around v7.519. The entire historical suite did not finish; strict/full-suite PASS is not claimed.

## Cannot claim without device
- No iOS SDK/Theos on this host, so native rootless `.deb` was not compiled here. The existing-clone GitHub Actions build produces that package.
- New surfaces still need post-install native view/paint confirmation; the nine captures alone cannot prove that React's live navigation will always map to one owner.
- The screenshot-only `In-Store/Delivery/Pickup` selector and isolated Alexa Shopping List title bar are not represented by matching probe identifiers; their exact final dark styling remains to be confirmed.
- Check local source validation log for historical regression suite completion state; neither screenshot quality nor on-device latency can be guaranteed from static tests.
