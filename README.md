# AmazonDark v7.476 — PDP offsite UI + strict-CI repair

Direct parent: **v7.475~pdp-offsite-nav-separators**.

v7.475 contained the intended UI changes but failed strict CI because one newly added CSS declaration violated an older frozen regression contract. The failure was reproducible locally in `test_v7406_video_sponsored_footer_restore.py`: the new offsite card rule contained `overflow:hidden!important` inside the source slice that must preserve the authored Sponsored footer without clipping.

v7.476 removes only that clipping declaration. The v7.475 UI work remains:

- offsite/medium standalone wrappers receive OLED floors, one gray border, neutral text promotion and preserved semantic colors;
- PDP `#nav-subnav` links are vertically normalized so `Top` matches its neighbors;
- thin bottom-navigation hairline layers are suppressed without changing tab icons or selection state.

The release was audited against the same version-normalized historical regression corpus used by `scripts/validate.sh`; all **153** Python regression files pass in bounded batches after the v7.476 compatibility test was added.

No MutationObserver, interval, requestAnimationFrame loop, Web scroll listener, TreeWalker, or new recurring scanner is introduced.
