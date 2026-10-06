# AmazonDark v7.572 — Prime label + video audit

- Captured Search refinement renderer: `Prime Big Deals` label (`.sf-mobile-filter-hve > .a-size-small.a-color-base`) is now pure white without depending on the absent `.s-mobile-toolbar` ancestor.
- Pill floor, gray border, Prime brand art, toggle, and neighboring refinement geometry remain unchanged.
- v7.571 VIEWPORT audit of the large sponsored video found the real 420x236 `<video>` mounted with a 640x360 stream, `readyState=4`, paused/muted, opacity 1, and no poster/background-image.
- AmazonDark keeps that video element `filter:none`; no display, visibility, opacity, source, poster, currentTime, autoplay, or playback state is changed. The posterless black paused presentation is therefore left unchanged.
