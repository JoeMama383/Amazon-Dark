# v7.639 verification

## Completed

- Verified the `ad7482-new-menus` CSS returns to the exact v7.638 SHA-256 (`6e0157c06835898f8c6443d561825853181b5b3adc863fe55d00d5317ef9ea50`) after normalizing only the three v7.639 release-comment stamps; all CSS selectors, declaration values, specificity, and geometry are unchanged. The base `.js.inc` remains independently parsed by the original historical tests.
- Executed the newly shipped v7.639 stylesheet selection JS in Node on main Search `/s`, PDP `/dp/...`, non-hot main menus and child Search frames. The hot routes keep 247 rule lines, versus 411 in the full sheet. Non-hot routes and every child frame retain the *identical full CSS*, not just matching sample declarations.
- Verified all 164 removed rules are one-line complete rules and that every top-level comma-separated selector belongs to explicitly unrelated owners (parens/brackets respected). `#search` and `#dp` selectors survive the hot branch.
- Confirmed the four PDP-only source helpers retain their existing underlying strings; their route gate operates only in main Search/Home and leaves the mixed PDP/Returns helper intact. Tested C++98 macro alias self-call semantics in a standalone compiled fixture.
- **87 source regression scripts passed** in the focused menu/CoreWeb/versions 7.631–7.639 selection, plus separate C++98 native macro and Node JavaScript syntax checks. Includes checkout, product, Search, Interests, medical/Warbler, auth, privacy, Cart, Prime, native keyboard, account menus and probe contracts. The v7.637 theme freeze verifies unchanged payloads after stripping the newly named route-selection mechanism.
- `bash scripts/lint-logos.sh` passed; new `ADNewMenus7482.js.inc` parsed as a valid JavaScript program through Node's syntax check; the `layout/DEBIAN/postinst` executable bit and all v7.639 version stamps are present.

## Limits

The full sequential 302-test `scripts/validate.sh` run was attempted locally but exceeded the execution time of the interactive environment before completion; this is **not** a full green-suite claim. The GitHub Actions pipeline runs the full regression suite and builds the linked `.deb`; confirm that Actions passes before installing. Actual on-device Search/PDP responsiveness and visuals are not verified locally. No forced stylesheet trial is needed for the next ordinary-use comparison.
