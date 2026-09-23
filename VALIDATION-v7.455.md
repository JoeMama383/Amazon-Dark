# AmazonDark v7.455 validation

- 133 / 133 Python regression entry points passed in the source workspace.
- New PDP-manual tests compile both new C-string JavaScript includes with `c++ -std=gnu++98 -Wall -Wextra -Werror`, reproduce the exact emitted bytes, and pass `node --check`.
- The PDP route test proves the Product Detail branch selects `ADUIScanPDPManual7455` before the generic `ADUIScanWebViewFull7364` path.
- Static PDP-manual checks prohibit `scrollTo`, `.scrollTop=`, `.scrollLeft=`, native `setContentOffset:` and generic `ADUIScrollCommand7446` use inside the PDP manual path.
- The new product sampler is bounded to 460 visible elements and contains no TreeWalker.
- Shell syntax passed for `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `layout/DEBIAN/postinst`.
- `bash scripts/lint-logos.sh` passed.
- No Theos/iOS SDK compile or on-device execution was possible in this workspace. GitHub Actions build and target-device verification are still required.
