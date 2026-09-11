# AmazonDark v7.398 — legal/help completion

v7.398 is built directly on v7.397 and preserves the completed checkout/address transition, payment auxiliary controls, address/pickup, Subscribe & Save, keyboard, app-switcher, and prior UI work.

The new pass re-audits every recent FULL probe instead of adding broad recolors. The key correction is structural: Privacy Notice and Conditions of Use mount `article.help-content` below wrapper nodes, so the old direct-child selector never owned most of their body text. v7.398 uses the stable descendant article family, makes ordinary legal copy white (including the Conditions of Use message blocks), keeps authored blue links and explicit secondary/tertiary gray families dynamic, and hides the stock light article separator on OLED.

The shared help search now removes only Amazon's dark image-backed magnifier and redraws a static gray magnifier matching the placeholder. Every pre-mounted `help-content-submenu*` AUI card is darkened with gray row dividers, white neutral text and white chevrons. The feedback No-path's nested radio shell, an instructional figure's white AUI frame, the probe-captured LLM summary shell, and the related-help AUI card outside the article are also covered without altering radio/thumb art, instructional imagery, or authored links.

The payment FULL probe also exposed two latent white states that had not yet become visible in screenshots: the hidden installments bottom-sheet button footer and a generic checkout `loading-spinner-blocker`. Both are now covered inside checkout only, while checkbox/radio art and blue links remain authored.

v7.397's financing button, Prime Store Card upsell and default-ordering alert fixes remain intact, as does v7.396's native checkout address transition-floor seal.

No MutationObserver, polling loop, interval, RAF loop, Web scroll listener, recurring hierarchy scan, additional WKUserScript, or generic card/image recolor is added.

See `AUDIT-v7.398.md` and `COMMANDS.md`.
