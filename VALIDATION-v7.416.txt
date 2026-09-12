# AmazonDark v7.416 audit — canonical location-menu owner

## Release
- Version: `7.416~location-canonical-owner`
- Runtime: `v7.416-location-canonical-owner`
- Direct parent: `7.415~location-text-finalize-fix`

## Probe reconciliation
The recent v7.406–v7.414 FULL/VIEWPORT/TRANSITION captures were reconciled against the current source instead of adding another menu-specific owner.

The critical finding is that two React roots may coexist while the location UI is open:
1. a full-screen `SNPRootView -> RCTRootContentView` at roughly `430x932`, containing the visible lower inset ~394pt location scroller and the actual ZIP/cards/country-row pixels;
2. a parallel `AppCXBottomSheet -> AppCXBottomSheetContentView -> SNPRootView -> WrappedNileFeatureContainer -> navigation-root` tree, which recent v7.414/v7.415 code incorrectly promoted to the primary location owner.

That split ownership explains why rules could be present and tests could pass while the visible menu remained stock or intermittent.

The paired v7.414 good/bad location probes additionally prove the intermittent text issue is a lifecycle overwrite, not a different renderer: identical `RCTTextView` hashes/frames/ancestry end either stock dark or correctly light, while Amazon-blue link runs remain identical. The v7.413 ZIP probe proves the stock 394x44 white input, 394x45 yellow Apply control, dark header/button text and 1pt header separator. The v7.413/414 location captures prove the three ~140x130 address cards and their cached React background/border raster. Historical v7.411 transition evidence retains early top-rail/clipping-shell OLED ownership.

## v7.416 correction
- Deletes both competing location systems: `ADLocationAux*7412` and `ADLocationNile*7414`.
- Uses one canonical event-driven owner based on the actual full-screen location root and lower inset ~394pt `RCTScrollView` ancestry.
- Once the exact main-address wrapper marks the root, that marker also covers pre-window hydration while navigating into ZIP / country / current-location submenus.
- No route strings and no descendant scan are required to classify normal location descendants.

### Choose your location
- Exact address cards are intercepted at their own `setBackgroundColor:` path, including before window attachment when their structural wrapper is already present.
- Stock bright background writes become OLED immediately.
- Core Animation `backgroundColor` animation is removed only for these owned cards.
- UIView and CALayer display are invalidated so React cannot leave a stale white cached border/background raster visible.
- Header, description, names, addresses and neutral body text are lightened at React text assignment, legacy 3-argument text finalization, and final draw/layout.
- Authored Amazon-blue links and selected orange border remain authored.

### Enter a US zip code
- Exact 394x44 `RCTSinglelineTextInputView`: `#303335` fill, `#747a7c` existing React border, light field/placeholder text.
- Exact 394x40-52 Apply family: stock Amazon-yellow first assignment is recognized from the incoming candidate color, then persisted as the Apply identity; final surface is OLED, existing React edge is gray, text is light.
- This candidate-color ownership prevents the old failure where the button became black but a later saturated yellow border survived.
- Header neutral text is light and the 1pt neutral separator is gray.
- Back chevron remains authored.

### Ship outside the US
- Wide neutral country/list rows and bright list surfaces under the canonical scroller become OLED.
- Neutral country names and section headers become light.
- Thin separators and neutral React border writes become standard AmazonDark gray.
- Authored chevrons/icons/SVG/sprites remain untouched.

### Use my current location
- Uses the same canonical location owner; neutral floors/text/borders cannot fall back to a separate submenu implementation.
- If Amazon presents the existing permission sheet after the action, inherited v7.408–v7.411 permission ownership remains intact.

## Text policy
- Only neutral black/gray/white runs are theme-owned.
- Saturated semantic colors are preserved.
- The old screen-position-based text preservation heuristic is removed from active location text ownership; it was capable of preserving stock-dark neutral text simply because it appeared low on the screen.

## First-paint/lifecycle policy
- Main card ownership can run before window attachment from exact structural ancestry.
- Once the full-screen location root is marked, submenu setters can be corrected before first presentation.
- React text is corrected at assignment + final commit + final draw/layout instead of by timers or retries.
- Existing v7.411 top-rail / expanding shell transition ownership remains unchanged.

## Architecture / performance
- `ADLocationAux*7412`: removed.
- `ADLocationNile*7414`: removed.
- New production MutationObserver: 0.
- New setInterval/polling loop: 0.
- New requestAnimationFrame loop: 0.
- New Web scroll listener: 0.
- New delayed retry: 0.
- New recurring hierarchy scan: 0.
- New WKUserScript family: 0.
- New production hook class: 0; existing React hooks are reused.

Source reduction:
- v7.415 `src/Tweak.xm`: 11,980 lines / 806,985 bytes.
- v7.416 `src/Tweak.xm`: 11,519 lines / 781,965 bytes.
- Reduction: 25,020 bytes (~3.10%) while retaining current theming and all universal probes.

## Validation
- `scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- `layout/DEBIAN/postinst` mode: 0755.
- 88/88 non-exhaustive Python regression files: PASS from the final packaged tree.
- Exhaustive historical `tests/test_probe_handoff.py`: PASS from the final packaged tree, including real-tar export, receipt discovery without plutil, version mismatch rejection, Amazon-only arming and failure fallback coverage.
- All impacted v7.408-v7.416 location/permission regressions, universal-probe tests, probe embedding, direct-parent handoff, Logos lint and dead-code/optimization audit: PASS.
- `test_v7416_skeleton_direct_parent_handoff.py`: PASS with v7.415 receipt and plutil unavailable.
- The full strict serial `scripts/validate.sh` run exceeded this environment's external wall-clock ceiling after 48 PASS outputs and no failure; every Python regression file, including the exhaustive handoff test, was also executed independently to completion and passed.
- `COMMANDS.md` retains `sh scripts/validate.sh` in the phone push workflow, satisfying the inherited CI/handoff contract.
- Local Theos/iOS SDK compile/link/package is unavailable here. GitHub Actions / the phone build remains the authoritative compile proof.
