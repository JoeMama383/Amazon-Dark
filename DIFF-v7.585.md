# AmazonDark v7.585 diff

Base: `v7.584~medical-health-ai-theme`
Target: `v7.585~medical-auth-probe-followup`

## Probe-driven fixes

- One Medical standalone account-holder picker (`v7.584 VIEWPORT r4`):
  - exact picker floor -> OLED black;
  - black heading/subheading/account labels -> white;
  - secondary gray copy -> legible gray;
  - existing avatar tile -> dark gray with recolored authored border;
  - existing 1 px divider -> standardized gray;
  - chevron -> white;
  - teal links / blue information icon remain authored.
- Health AI / Warbler (`v7.584 VIEWPORT r1/r3`):
  - quick-action buttons -> dark gray, gray border, white text;
  - recommendation-card and image-lane floors -> OLED black;
  - neutral card title/copy -> white, secondary copy -> legible gray;
  - dynamic blue card paint preserved;
  - recommendation artwork joins the existing preference-controlled brightness leaf filter;
  - chat textarea floor -> OLED black;
  - sidebar CID sign-in `arc-button` shadow-root button -> OLED black, gray border, white text using an exact event-driven shadow style, no observer/timer/poll.
- Verification/auth (`v7.584 VIEWPORT r5`):
  - PUI loading overlay -> OLED black while spinner artwork remains untouched;
  - verification card / nested floor -> OLED black;
  - neutral heading/instruction/label copy -> white;
  - OTP field wrapper remains dark while preserving authored focus-state border color;
  - yellow Verify button -> OLED black, gray border, white text;
  - footer divider -> standardized gray;
  - secondary gray text -> legible gray;
  - authored link colors preserved; expander/dropdown glyphs are whitened.

## Retained / synchronized

- v7.582 Prime transition loading paint is unchanged; its current-version regression anchor is synchronized to v7.585.
- v7.583 Prime refinement divider recolor is unchanged; its current-version regression anchor is synchronized to v7.585.
- FULL / VIEWPORT / TRANSITION probe identity is bumped to v7.585 with current-session TAR behavior retained.
- No new recurring DOM walker, MutationObserver, interval, timeout, RAF loop, scroll listener, or geometry scan was introduced.
