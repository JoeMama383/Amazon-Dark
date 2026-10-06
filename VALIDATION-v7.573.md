# AmazonDark v7.573 — PDP family / sponsored / review polish

- Customers-also-bought multi-bundle and Frequently Bought Together product-image families now use the configured image-taming brightness while retaining visibility, opacity, and normal blending.
- The lower PDP single-video ad was audited from the supplied v7.571 VIEWPORT r2 capture: the real 393x221 `<video>` is mounted with 1920x1080 metadata, opacity 1, `filter:none`, paused/muted, `readyState=1`, and no poster attribute. The blank pre-play state is therefore left untouched.
- The lower video ad Sponsored pill was captured at `rgba(255,255,255,0.9)` and is inverted to `rgba(0,0,0,0.9)`. Only the pill/container background changes; Sponsored text and the info glyph are not modified by the new rule.
- Customer-review AI summary controls captured as `button.dpx-reviews-pill` (`rgb(194,220,255)`) are changed to medium gray `#303335`, standard gray border `#747a7c`, and white text.
- No observer, timer, RAF, playback-state rewrite, source/poster mutation, or recurring DOM walker was added.
