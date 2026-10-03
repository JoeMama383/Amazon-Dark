# AmazonDark v7.561 audit

- Base: v7.560~returns-success-alert-oled.
- Evidence: v7.556 VIEWPORT r2 Refunds/Exchanges help article.
- Captured owner: `div.cs-help-note`, rect ~402x89, background `rgb(250,251,252)`, border `rgb(175,203,214)`.
- Captured child paragraph `p.take_action`: transparent background, white neutral copy.
- Captured action anchor: authored blue (`rgb(33,98,161)`).
- Production change: only `.cs-help-note { background:#000!important; }` under the existing `.cs-help-v4 .cs-help-content article.help-content` family.
- Border, radius, layout, anchor color, and article typography remain authored/existing-theme owned.
- No MutationObserver, timer, RAF, scroll listener, polling, hierarchy scan, or delayed repair added.
