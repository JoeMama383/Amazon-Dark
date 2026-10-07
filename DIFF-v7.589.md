# AmazonDark v7.589 diff

Target: `v7.589~person-orders-review-menu-followup`

## What changed
- Extended the exact Person `Search orders` magnifier owner to the probe-captured compact 174x50 field; the 20x20 magnifier now paints the same light color as the adjacent text.
- Kept the existing legacy ~360x50 Search-orders owner unchanged.
- Added exact Your Review WebKit ownership scoped by `#cr-single-review`.
- Review body card floor is OLED black and review body text is white.
- Review title and profile-name dark neutral text are white; gray metadata and orange Verified Purchase state are preserved.
- Edit/Delete buttons are OLED black with white text and standardized gray borders.
- Review-page product subheader text is white; its floor remains OLED and the authored divider is recolored gray.
- Repaired a latent v7.588 thumbnail-helper compile regression found during validation: the exact `SNPRootView` check now uses the correct C-string class matcher, and the unrelated helper implementation no longer contaminates the pre-`UIView` isolated compile fixture.
- Package/probe identity bumped to v7.589.
