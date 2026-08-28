# AmazonDark v7.145~search-video-mlt-fix-probe — Search video + More-like-this repair

- Fixes the Search-results More-like-this/two-cards control: the exact 48x48 `.more-like-this-container` wrapper is no longer painted OLED black behind Amazon's stock 32x32 white circular icon.
- Fixes Search sponsored video playback: `.sbv-video-overlay` is released from the broad Search floor owner, the accelerated `video.sbv-video-player-ecx` is kept unfiltered, and TWB is applied as a configurable translucent black overlay background instead of a compositor filter on the video surface.
- Preserves the stock Search video control subtree from AmazonDark's generic Search text/glyph ownership, addressing the malformed mute/sound icon while leaving Amazon's own control artwork authoritative.
- Expands the screenshot/SIGUSR2 probe to capture the exact More-like-this wrapper plus Search sponsored-video shells and every descendant of the visible video overlay for control verification. No recurring observer, timer, RAF, scroll listener, or scan is added.

## v7.144 Home ad dual repair

- Restores Amazon-owned stock paint for the Home Window Display / single-creative hero Sponsored feedback capsule. AmazonDark no longer recolors or reconstructs that hero badge; its semi-transparent capsule, text, and info glyph are left to Amazon.
- Adds TWB coverage for Home `wd-shoppable-*` media and compact standalone `#ad:has(#dynamic-bb)` raster media without changing the configured TWB strength. Prime/rating/icon/glyph/badge/Sponsored artwork stays protected.
- Ships a screenshot/SIGUSR2 dual probe (`AmazonDark-v7.144-home-ad-dual-fix-probe.txt`) that inventories hero Sponsored paint plus visible media in main and child frames. No recurring observer, timer, RAF, scroll listener, or scan is added.

## v7.143 search-results dropdown polish fix probe

Built directly on v7.142. This revision targets only the Search-results dropdown-title controls proven by the v7.141 probe to back the Discover/Seller buttons. It clears the black same-size content shell and the nested text/content plates so the existing `#202324` button floor and `#747a7c` border can show through. It also removes the 8x5 black/inverted arrow painter that becomes a white rectangle and replaces only that exact dropdown-title arrow leaf with a small light-gray chevron. Prime blue, ReviewStar orange, Sources pills/chevron, location strip, result-card image taming, Heart/More-like-this controls, and Add-to-cart styling are otherwise unchanged. The screenshot/SIGUSR2 probe now dumps the exact dropdown-title and dynamic-picker chains for verification.