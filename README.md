# AmazonDark v7.463 — PDP reviews polish

v7.463 is a probe-backed PDP follow-up to v7.462.

It addresses the new viewport-reported issues on the product reviews flow:

- forces the related-products / “Customers who bought this item also bought” carousel floor to OLED black by owning the exact `#relatedProductZone4_feature_div` carousel shell
- forces the “Rate today’s book shopping experience” header strip to OLED black by owning the exact `#heimdallShoppingCxFeedback_feature_div` widget container / fieldset while preserving the gray rating buttons
- restores the hidden “See more reviews” row to white text by owning `#cm_cr_top_reviews_to_arp_button`
- forces the “Upload your video” chevron to white by owning the exact `_dnNlL_vseUploadButton_` supplemental icon

The implementation remains declarative CSS only inside the existing probe-backed PDP owner block. No observers, polling, MutationObserver, scroll listeners, or recurring DOM walks are added. FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.463.
