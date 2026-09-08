# AmazonDark v7.370 audit — reliable checkout script reinstall + probe-correct colors

## Production baseline

- Direct parent: **v7.369~checkout-isolated-theme**.
- Parent `src/Tweak.xm` SHA-256: `6ae2a20245f24ef0338c92c7dfbc1d7f86120a3bff0028831ee28d36a4e9f59e`.
- v7.370 is a forward fix on the already-pushed v7.369 base. It does not return to v7.367 and does not reincorporate rejected v7.368 code into the shared WebUI program.

## Why v7.369 could still fail to theme the two checkout menus

v7.369 correctly moved checkout styling into independent document-start `WKUserScript`s (`ADCheckoutFloorJS7369` and `ADCheckoutTWBJS7369`). However, Amazon calls `WKUserContentController -removeAllUserScripts` during WebKit lifecycle/navigation work. That API removes the actual isolated checkout scripts.

The existing AmazonDark hook cleared the associated-object receipts for the shared core WebUI script, shared TWB script and privacy script before calling `ADAttachScriptsToUCC710(self)`, but it did **not** clear `kADCheckoutFloorUS7369` or `kADCheckoutTWBUS7369`. The real checkout scripts could therefore be gone while AmazonDark still believed both were installed. `ADAttachScriptsToUCC710` then skipped them.

v7.370 clears both checkout receipts before the common reattach call. This is the primary reliability repair.

## Probe-backed color corrections

### Before-you-go / recommendation menu

The v7.367 FULL r1 probe shows product-title spans in the `_mobileDenseGridProductTitle_` family are nested under `a.a-link-normal`. v7.369's generic neutral rule excluded all descendants of anchors, so those baseline-black product titles could remain black after the checkout script finally ran.

v7.370 keeps link descendants authored by default and explicitly flips the exact `_mobileDenseGridProductTitle_` family light. Structural DIVs receive `color` only, not a broad white `-webkit-text-fill-color`, and semantic price/success/link/deal/coupon/promotion/saving/discount families reset text-fill to `currentColor`. This preserves Amazon-authored red/green/blue instead of baking those colors into AmazonDark.

The existing v7.369 control ownership is retained:
- OLED black recommendation floors and fixed footer;
- OLED/gray/light `Continue to checkout`;
- `#303335` add-circle fill, `#747a7c` edge and white plus;
- Prime artwork unfiltered;
- checkout-only TWB for product images.

### Place Your Order

The v7.367 FULL r2 probe shows two important black anchors use `a-color-base`:
- the delivery-option expander link; and
- the sustainability / `Lower carbon delivery` link containing the green leaf artwork.

v7.369's blanket `.a-link-normal` blue override could recolor the sustainability text blue. v7.370 stops forcing all checkout links blue. Normal Amazon links keep their authored blue because anchor descendants remain outside neutral whitening, while `a.a-color-base` is explicitly flipped light. Semantic color families keep authored `color` and receive only `-webkit-text-fill-color:currentColor` protection.

The existing exact owners remain:
- OLED checkout cards/panels/line items;
- OLED/gray/light Place Order controls;
- Cart-style quantity stepper (transparent fieldset; `#303335` inner floor; `#747a7c` edge; white trash/plus);
- Prime and sustainability leaf unfiltered;
- checkout product media in the isolated TWB lane.

## Native checkout header

v7.369 already scoped the yellow/orange image-backed navigation plane to `AMSModalLayoutFullScreenViewController` plus a `Place Your Order` title. v7.370 fixes a timing/lookup weakness: fallback title discovery no longer stops at the first label (which can be `DONE`); it scans the checkout navigation descendants until the actual Place Your Order title is found.

While the exact checkout nav is owned, all descendant labels are kept light, covering both the title and `DONE`. Original label colors and navigation tint are stored and restored if UIKit reuses the views outside the checkout state.

## Regression boundary / performance

- `ADFloorJS()` SHA-256: `5fcc2badb75d385b84a9e67a1daab376c1dd277479c6c1071ead93e3ee96221d` — unchanged.
- `ADTWBJS()` SHA-256: `74035e2572891f3b6014522bf4838d19a72a1dc1dfb894363eb8fec53cae5dd9` — unchanged.
- `ADCoreWebJS7271()` SHA-256: `e3d9e2edec398c434986eb423aa1d9a4a4fbde73db21d19be5727934a517f480` — unchanged.
- `src/AmazonDarkSB.xm`, `src/ADSkeletonProbe7339.js.inc`, `Makefile`, and `.github/workflows/build.yml` are byte-identical to v7.369.
- No MutationObserver, interval, RAF loop, web scroll listener, recurring hierarchy scanner or renderer polling was added.
- Universal probe architecture is still exactly two categories: screenshot-triggered finite FULL sweep and armed one-shot VIEWPORT capture.

## Validation

- 23/23 Python regression scripts: PASS.
- New `test_v7370_checkout_script_reinstall.py`: PASS, including Node `--check` of the reconstructed isolated checkout floor JavaScript. This specifically guards against the v7.368 broken-string failure mode.
- `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `layout/DEBIAN/postinst`: shell syntax PASS.
- `scripts/lint-logos.sh`: PASS under Bash.
- Logos balance remains 72 `%hook` + 2 `%hookf` / 74 `%end`.
- The three browser-renderer `.cjs` tests require Playwright, which is not installed in this container; their inherited test files were not changed by the checkout repair except current version identity where applicable.
- Local Theos package compilation is unavailable in this container; GitHub Actions/on-device Theos remains the compile/link/package authority.
