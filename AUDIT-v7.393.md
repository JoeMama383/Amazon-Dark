# AmazonDark v7.393 — payment + help article UI audit

## Base
- Direct parent: `7.392~probe-handoff-ci-fix`.
- Parent source ZIP SHA-256: `2c084183775731d0b838017e662301d8cdc000d38827549a5fb87adf01fbdb76`.
- Payment evidence: `AmazonDark-v7.392-ui-full-probe-20260910-164643-822-r1` plus the reported payment screenshot.
- Privacy evidence: `AmazonDark-v7.392-ui-full-probe-20260910-165949-923-r2`.
- Returns evidence: `AmazonDark-v7.392-ui-full-probe-20260910-170806-026-r3` plus the reported Returns screenshot.
- Consumer Use Tax evidence: `AmazonDark-v7.392-ui-full-probe-20260910-170908-156-r4` plus the reported Tax screenshot.

## 1. Select a Payment Method
### Probe finding
The previous payment CSS was scoped through `form.pmts-select-payment-instrument-form`. r1 proves that hidden form and the visible React payment UI are siblings, not ancestor/descendant. The selectors therefore could not reach the actual white owners.

The capture identifies stable rendered owners:
- `selected-primary-pm-card`: light-blue floor and authored 2px Amazon-blue border;
- `unselected-primary-pm-card`, `unselected-primary-pm-loan`, `selected-balance-pm-giftcard`, `claim-code`: stock white card/utility floors;
- `sticky-footer`: stock white floor;
- `heading`: captured `3px rgb(203,160,221) auto` outline, which is the reported purple rectangle;
- semantic `switch`, `switch-knob-wrapper`, `outline-*` painters carrying Amazon's actual off/on state;
- semantic `[data-testid=image]` wrappers for the primary Visa / Store Card art.

### v7.393 correction
- Removes the false form-ancestor gate and anchors on the rendered payment `data-testid` owners.
- Uses direct `background:#000!important` ownership; no giant inset-shadow seal is added.
- Does not assign the selected card border color, preserving the authored blue selection ring.
- Recolors only unselected/utility border colors to `#747a7c`, preserving existing border geometry.
- Makes neutral payment copy pure white while anchor / `data-testid=link` descendants remain `currentColor`.
- Leaves switch/knob/outline filter state untouched.
- Removes only the exact payment heading outline.
- Adds primary Visa / Store Card semantic image wrappers to the existing checkout TWB brightness factor; loan/Affirm and gift-card artwork are not generalized into the filter.

## 2. Shared help-article ink contract
Privacy, Returns and Consumer Use Tax all use `.cs-help-v4 > .cs-help-content > article.help-content`.

v7.393 applies one bounded article contract:
- ordinary neutral-dark headings/body/list/container text -> AmazonDark light ink;
- anchors and `.a-color-link` descendants -> `currentColor` so authored blue remains authored;
- `.lead`, `.a-color-secondary`, `.a-color-tertiary` and descendants are excluded from the white override and retain their authored gray/dynamic foreground;
- the help subheader's dark `h4` is flipped light without recoloring its parent link.

This avoids the earlier over-broad draft that would have flattened the probe-proven gray lead text to white.

## 3. Privacy Notice + Was-this-information-helpful
The r2 capture records the visible feedback owner as `#hmd-FeedbackBox`: stock white floor/light border with two white `.a-button-base` controls. It also records hidden, already-mounted `#hmd-ConfirmYesBox`, `#hmd-ReasonBox`, `#hmd-ConfirmNoBox`, and `#hmd-CustomerServiceHub` states.

v7.393 themes the complete hmd family in one pass:
- OLED black panel floors;
- one `#747a7c` panel border;
- light neutral copy, with secondary-gray text preserved;
- OLED black Yes/No/follow-up buttons with `#747a7c` borders and light text;
- transparent button inner layers so borders do not double;
- `#303335` reason-entry wrapper with gray border and light textarea copy;
- authored links and radio/control sprites untouched.

## 4. Returns and Refunds
The r3 capture proves each bright topic group is a `div.a-box` under `.cs-help-landing-section`, with an `.a-box-list` and `a.a-touch-link` rows. The outer card is the white painter; the row links are transparent. Existing row separators are 1px stock-light borders. Touch-link chevrons are `i.a-icon-touch-link`.

v7.393 therefore:
- themes only the `div.a-box` card shell, not every `.a-box` anchor;
- keeps the card's existing radius/layout and changes floor to OLED black plus border color to `#747a7c`;
- keeps inner shell/list transparent;
- recolors existing list-row separators to `#747a7c` without adding borders to rows that had none;
- makes row copy light and touch-link chevrons white;
- preserves ordinary non-row article links;
- paints the existing `p.lead` and `.cs-help-landing-section` external bottom-border pixels black so the bright divider lines disappear into the OLED floor rather than becoming extra visible separators.

## 5. Consumer Use Tax Requirements
The r4 capture proves the bright region is one `table.a-bordered`: the table has a stock-light outer border while `th` and `td` are the actual white cell painters.

v7.393:
- keeps table dimensions, radius, rows, columns and border widths unchanged;
- makes the table and `th`/`td` cell floors OLED black;
- makes table copy light;
- changes existing table/cell border colors to `#747a7c`;
- preserves authored links and the gray lead text;
- uses the same hmd feedback-family treatment at the bottom.

## 6. Probe metadata
The outer v7.392 probe identity was current while the embedded Web DOM payload still serialized `version:'7.391'`. v7.393 advances only that inner label to `7.393`; FULL/VIEWPORT trigger behavior and capture scope are unchanged.

## Performance / architecture
- New visual work is declarative CSS inside the already-existing checkout/floor user script plus one additional selector in the already-existing checkout TWB stylesheet.
- Payment uses direct background paint instead of an inset 9999px paint seal.
- No MutationObserver.
- No `setInterval`.
- No requestAnimationFrame loop.
- No Web scroll listener.
- No recurring timer or hierarchy scan.
- No new WKUserScript.
- No generic image-taming expansion.
- No SpringBoard/app-switcher snapshot replacement.

## Validation
- `scripts/lint-logos.sh`: PASS.
- `AD_STRICT_VALIDATE=1 sh scripts/validate.sh`: the tool execution window reached its time limit after the first 30 regression scripts, all of which passed through v7.377.
- Remaining tests 31-50 were run in two bounded segments: PASS.
- Combined Python regression result: 50/50 PASS.
- `test_probe_handoff.py`, including the v7.392 no-plutil receipt recovery path: PASS.
- Reconstructed `ADCheckoutFloorJS7369`: Node syntax PASS.
- Reconstructed checkout stylesheet: 135 qualified CSS rules, 0 TinyCSS parse errors, 0 cssselect2 selector parse errors.
- Theos/iOS SDK is not installed in this artifact environment; GitHub Actions / phone Theos remains the authoritative compile/link/package proof.
