# AmazonDark v7.401 — native payment sheets + press-state audit

## Base
- Direct parent: `7.400~delivery-instructions-completion`.
- All v7.400 and earlier visual/performance behavior is retained.
- Evidence: `AmazonDark-v7.398-ui-full-probe-20260910-220129-636-r5.zip`, `AmazonDark-v7.398-ui-full-probe-20260910-220150-613-r6.zip`, and the v7.400 Delivery Instructions screenshot/FULL capture for the pressed-row regression.

## 1. Why the two payment menus required native ownership
Both omitted menus are React Native sheets in `AppCXWindow`, not checkout DOM/AUI pages. A generic `bottom-sheet` match is intentionally insufficient because Amazon reuses that identifier in unrelated native sheets.

v7.401 marks a sheet only after one of the stable probe-proven payment families mounts:
- r5: `card-wrapper` below `card-pressable-wrapper`, or `input-wrapper` below `input-pressable-wrapper`;
- r6: a top-level `creatable-sleeve-*` payment row (excluding its image/content wrapper descendants).

Once proven, the exact `RCTView#bottom-sheet` root is associated with the payment family. One bounded mount-time pass (maximum 192 views) repairs siblings that were already mounted before the marker callback. All later paint/text updates remain event-driven through existing React/UIKit hooks.

## 2. r5 payment-entry sheet
The FULL probe shows:
- white `RCTView#bottom-sheet` and white neutral sheet descendants;
- white `card-wrapper` and `input-wrapper` owners (`398 x 41.7`, radius 8);
- white `RCTSinglelineTextInputView` interiors beneath both wrappers;
- dark neutral field labels;
- an anonymous yellow `398 x 46.7` primary action directly below `RCTView#button`;
- dark/secondary legal copy and a neutral `privacy-icon` vector.

Treatment:
- neutral sheet floors -> OLED black;
- field wrappers/interiors -> existing `#303335` control fill with standard gray edge;
- neutral field/header text -> light; secondary neutral legal copy -> readable gray;
- yellow primary action -> OLED black, standard gray edge, retained oval geometry, light text;
- neutral privacy/close/handle vectors -> visible light treatment;
- no `RCTImageView`/payment artwork filtering.

## 3. r6 payment-method chooser
The FULL probe shows five stable row families:
- `creatable-sleeve-Card`
- `creatable-sleeve-ElectronicBenefitTransfer`
- `creatable-sleeve-BankAccount`
- `creatable-sleeve-DirectedSpendBenefitsCard`
- `creatable-sleeve-HealthBenefitsCard`

The `DirectedSpendBenefitsCard-content-wrapper-outline` is captured with stock pale fill `rgba(0.941,0.949,0.949,1)`, proving the neutral selected/pressed painter family. Rows contain authored payment images plus neutral text and 16x16 chevrons.

Treatment:
- sheet floor -> OLED black;
- pale/near-white neutral row repaint -> dark control fill immediately;
- one-pixel row separators -> standard gray;
- neutral row text -> light;
- neutral chevrons -> visible light;
- payment logos/artwork -> untouched.

## 4. Permanent press/highlight policy
The Delivery Instructions screenshot proves Amazon's AUI touch-down painter can repaint an already-themed row white (`.a-touch-press`, historically about rgb(246,246,246)). v7.401 therefore treats press/highlight ownership as part of the default dark-mode contract rather than a later bugfix.

Scoped AUI families now explicitly stay dark through `.a-touch-press` / `:active`:
- Delivery Instructions `.ma-cdp-form` touch checkbox/radio/link rows and accordion headers, including `.ma-physical-key-fob-checkbox`;
- Add-an-address touch rows and location-feedback touch link;
- Help & Contact Us topic rows;
- wrapped legal/help landing rows;
- Help submenu rows;
- suggested-topic/search-suggestion rows.

Existing exact protections remain for the Subscribe/Gift Options checkbox row and checkout delivery-option rows. Checkbox/radio sprites and semantic blue/red/orange/green states are preserved.

Native RN row presses are handled on the same principle through the existing `RCTView -setBackgroundColor:` transaction. Inside a proven payment sheet, a near-white press/highlight repaint is immediately reclaimed by `ADPaymentOwnView7401`; no timer or recurring scan is used.

## 5. Performance / non-interference
v7.401 adds:
- no MutationObserver;
- no interval or recurring timer;
- no RAF loop;
- no Web scroll listener;
- no recurring DOM/native hierarchy scanner;
- no new WKUserScript family;
- no generic `bottom-sheet` ownership;
- no broad `RCTImageView` taming.

The only bounded traversal is the one-time payment-sheet sibling repair after exact payment ownership is proven. Normal runtime work is event-driven by existing mount/layout/background/text callbacks.

## 6. Device verification
After install, verify independently:
1. r5 payment-entry sheet: OLED shell, both inputs dark/gray, labels light, primary oval black/gray/light, privacy/legal content readable, payment semantics intact.
2. r6 payment-method chooser: OLED sheet, all row text light, separators gray, chevrons visible, logos unchanged, and no pale/white row when pressing/holding a payment method.
3. Delivery Instructions: hold the Key/fob row and accordion/touch rows; they must remain black/dark while the authored checkbox state stays correct.
4. Add-address and Help/menu touch rows: press/hold must not flash stock white.
