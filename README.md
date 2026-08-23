# AmazonDark v7.0.25

Compile-fix rebuild of v7.0.24.

Functional behavior is unchanged:
- below-carousel Home floor ownership remains scoped away from the top hero/carousel;
- percent-off/deal badges remain excluded from floor paint and badgeLabel remains red/white;
- product media/asin-metadata multiply compositing remains normalized;
- ad-card text remains white with transparent text backgrounds;
- ANXTabBarView remains OLED black;
- v6.0.185-style local tab bitmap->template/tint/touch/selection/indicator mechanics remain active;
- all bottom-nav glyphs and the selected indicator remain white.

Compile fix:
- forward-declares ADLightText706() before the v7.0.24 tab helper block uses it.
