# AmazonDark v7.571 — Search see-all + Interests welcome sheet

Probe evidence used
- v7.570 Search viewport: `div.s-breeze-see-all-container > span.a-button.a-button-base.a-button-small` is the surviving white `See all` control; its child `i.a-icon.a-icon-arrow.a-icon-small` is the dark chevron.
- v7.570 Interests viewport: the popup is `._bW9ia_auto-creation-new-customers-bottom-sheet_2d0vA` inside `.a-sheet-web-container/.a-sheet-web/.a-sheet-content-container`. The captured title, close icon, content rows, and orange sparkle have exact `_bW9ia_` owners.

Changes
- Search Prime Big Deals `See all`: OLED black floor, standard `#747a7c` gray border, white label, white chevron.
- Interests welcome popup: all captured sheet/fade paint owners are OLED black with background images/shadows removed; stock geometry is untouched.
- Popup header and body copy are white. The title graphic and close X are whitened.
- Orange sparkle artwork remains authored and unfiltered. Dynamic semantic color classes are excluded from generic whitening and retain current color.
- No observer, timer, RAF, recurring DOM walk, or route-wide generic button rule was added.
