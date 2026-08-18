# AmazonDark v6.0.127

## v6.0.127 — consistent Sponsored label + info glyph paint

Built directly from the confirmed-good v6.0.126 production source. The Share-mask fix is retained unchanged.

The Home/Keep Shopping ad surfaces use more than one Sponsored template. v5.446 already had two relevant behaviors: exact Sponsored labels were pinned to light ink, and the tiny ad-feedback sprite was normalized by the donor glyph path. v6.0.127 ports that result as first-paint CSS instead of reviving the donor's broad runtime `sponsorFix376()` scan.

- Sponsored label families (`sponsored-label`, `adFeedbackMainComponent`, and the direct host of the `ad-feedback-spr` leaf) are pinned to pure white.
- The actual `ad-feedback-spr` bitmap leaf is pinned to the same white visual ink with `brightness(0) invert(1)`.
- SVG/path variants inside those exact Sponsor families are also pinned white.
- These leaves are added to Dark Reader's inline-style ignore list so later theme/hydration passes cannot darken one template independently.
- No MutationObserver, timer, scroll listener, RAF, document-wide query, or runtime text walk is added.

