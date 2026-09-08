# AmazonDark v7.373 — checkout delivery press state

Direct parent: **v7.372~byg-loader-badge-parity**.

The two v7.371 FULL captures prove the pressed delivery-option root is
`.rcx-checkout-delivery-option-a-control-row-new.a-touch-press` and computes
`rgb(246,246,246)`. v7.373 keeps only that pressed/active floor OLED black,
keeps its label wrapper transparent, and explicitly leaves `.a-icon-radio`
unfiltered so selected blue / unselected stock radio artwork is preserved.

Parent `src/Tweak.xm` SHA-256: `a43bb960295aabccbb89ebc2bc6963e6785dcc2a13bdedc397df1f29b4b2a813`.
No shared renderer or recurring runtime mechanism is added.
