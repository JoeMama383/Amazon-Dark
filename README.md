# AmazonDark v7.408 — permission/location completion + switcher hardening

Direct parent: **v7.407~pdp-transition-skeleton-dark**.

This release themes the three probe-captured native React sheets requested after v7.407: Camera access, Microphone/voice access, and Choose your location. It also closes the repeated gray/white app-switcher regression at the architectural level: neutral bright, near-full-screen `UIVisualEffectView` shields inside Amazon `AppCXWindow` are suppressed only while the app is inactive, regardless of which foreground sheet/controller caused backgrounding. Active UI effects are restored if reused.

See `AUDIT-v7.408.md` for the exact ownership and preservation rules.
