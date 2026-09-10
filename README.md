# AmazonDark v7.389 — checkout sheet + switcher snapshot fix

Direct parent: `7.388~native-work-optimization`.

This is a narrow theming release based on two v7.388 probe captures. It darkens the
portal-mounted checkout Subscribe & Save bottom sheet and removes the exact teal
checkout-only background shield that was being captured in the iOS app switcher.

The Subscribe & Save sheet uses the existing AmazonDark visual contract: OLED black
sheet floors, light neutral text, `#303335` controls, `#747a7c` borders, light control
text/glyphs, and authored link colors.

The switcher fix is not a generic app-switcher cover. It matches only the
probe-proven full-screen checkout `UIVisualEffectView` containing the exact teal
background child while Amazon is inactive/backgrounded. Normal snapshots outside
checkout remain untouched.

No new timer, polling loop, MutationObserver, recurring DOM scan, generic snapshot
replacement, or SpringBoard scene painter is introduced. Existing v7.388 runtime
optimizations and all other theming are preserved.

See `AUDIT-v7.389.md` and `COMMANDS.md`.
