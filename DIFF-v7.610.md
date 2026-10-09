# AmazonDark v7.610 — updated profile and notification follow-up

Parent: full v7.609 source.

## Profile picker, confirmed from viewport r6
The updated **Shopping as** bottom sheet moved into `UIWindow` under `AMSModalLayoutOverlay` rather than `AppCXWindow`. The prior owner `ADPersonSavingsSheetRoot7259` refused any non-AppCXWindow host, so the profile picker lost its dark styling. The v7.610 exact owner accepts the new modal host only when the existing `sheet-view` / `sheet-inset-view` / `profile-picker-close-bottomsheet-button` witness is present.

- Recolors neutral white/near-white sheet and card backgrounds to OLED black; exact highlighted profile card and Switch Accounts surfaces to medium gray.
- Recolors existing neutral-light borders/dividers gray without drawing new geometry.
- Restores light neutral text, including the newly black-on-black About You item and white-on-black heading/close.
- Keeps authored blue/teal navigation and action text, badges, profile avatars and other sprites unchanged.
- Runs one bounded 192-node catch-up pass only when the exact profile-picker witness first mounts. All other paint is triggered by existing native mount/text/background events; no recurring scanner/observer.

## Notifications, conservatively scoped (screenshot only)
The supplied r7 viewport **does not contain the notifications list**. It reports `webviews=0` but consists of the underlying Alexa/React UI, not rows visible in the screenshot. A definitive DOM/native owner therefore cannot be established from r7. To avoid breaking unrelated menus, this build adds a **conditional**, non-universal native fallback that only runs if a React `UIViewController` class contains `Notification` plus `List`, `Inbox`, `Screen`, or `Center`. When it matches, it turns pale neutral notification row backgrounds OLED and recolors existing thin dividers gray, preserves all authored teal/dark text colors, and tames any loaded, non-template notification thumbnails using the existing single native TWB overlay (no image-fetch or image-data rewriting).

**Limit:** r7 cannot prove that this controller is the real notifications owner or why the blank placeholders appear. Missing source images cannot be restored by CSS or a tint filter. Collect a new foregrounded FULL/VIEWPORT notification screen probe before claiming that issue is fully repaired.

No geometry changes, no blanket saturation filters, no new network routines or recurring observers. Includes v7.609 review photo fix.
