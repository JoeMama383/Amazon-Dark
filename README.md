# AmazonDark v7.411 — permission first-paint owner fix

Direct parent: **v7.410~permission-text-location-firstpaint**.

This release corrects two false timing assumptions in v7.410 using the supplied transition evidence. Permission button labels now have an exact ancestry-based white-text owner that does not wait for Camera/Microphone sheet classification. The Choose-your-location transition now owns its full-width neutral 8–24 pt presentation plates immediately and recognizes the early 394 pt scroll-content child before the concrete RCTScrollView mounts, eliminating the top/side white first-paint rails without changing the orange selected-address edge or authored blue links.

All v7.409 button-border/checkbox corrections, v7.408 inactive-switcher hardening, v7.407 PDP skeleton handling, and earlier theming remain inherited. FULL, VIEWPORT, and TRANSITION probe identities are regenerated to v7.411.
