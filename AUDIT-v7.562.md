# AmazonDark v7.562 audit

- Base: v7.561~help-note-oled.
- User target: Seller Messaging Assistant / contact-seller screen shown in the supplied screenshot.
- Probe caveat: the attached `AmazonDark-v7.556-ui-viewport-probe-20261003-141804-879-r2(1).tar` is the earlier Refunds help-article viewport capture, not the Seller Messaging screen. v7.562 therefore does not claim probe-derived DOM selectors for this screen.
- Production ownership is gated to Amazon's Seller Messaging contact-seller route (`/gp/help/contact-seller/contact-seller.html`) and child frames whose referrer is that route.
- Structural page/card/container floors are OLED black; neutral chat bubbles/controls use the standard medium gray; structural borders use the established gray family.
- Neutral dark copy is lightened while anchors, buttons, role-buttons, and Amazon semantic color families preserve authored `currentColor` behavior.
- Product media: a bounded route-local pass inspects at most 120 `document.images` entries and marks only 64..320 pt non-logo/avatar/icon/sprite candidates for the existing configured TWB brightness.
- No MutationObserver, interval, timeout, RAF, scroll listener, polling loop, or recurring hierarchy traversal is added.
- v7.561 help-note OLED, v7.560 Returns success-alert, v7.559 order-item OLED/count geometry, and v7.558 Filters/probe-routing ownership are retained.
