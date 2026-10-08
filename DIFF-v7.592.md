# v7.592 — probe-backed UI completion

Base: the supplied v7.591 regression-recovery source ZIP. The v7.591 Menu/Person/WebKit/native FULL dispatcher and additive-only native thumbnail overlay policy remain intact.

| Requested surface | Implementation / audit result |
| --- | --- |
| Authentication and expanded help | OLED card, Verify control and footer retained; actual `.a-global-nav-wrapper` and its sprite logo now covered; footer pseudo-gradient removed; exact Authentication required native bar OLED. Neutral help copy white, links preserved, secondary copy gray. |
| One Medical account holder / confirmation | Existing picker headers, avatar, chevron and divider fixes retained. Confirmation now targets captured `section-container` / privacy-banner topology instead of requiring the absent content-container witness. Continue OLED/gray/white; dynamic links retained. |
| Health AI cards and quick actions | Doctor inline background image is preserved (background shorthand previously deleted it) and preference-tamed on its actual lane. Small illustration glyphs are not brightness-tamed. Neutral titles/copy white, secondary gray, semantic offer blue retained. Quick actions gray/gray/white; trailing white fade removed. Input inner plane OLED. |
| Health AI sidebar | Sign-in button gets OLED/gray/white CSS in its actual shadow root, including after component upgrade and real UI events. No recurring observer or timer. |
| Medical storefront, search, ZIP, links sheet | Existing OLED floors, media taming and dynamic colors retained. Search magnifier white; square outer search fill transparent; send control matches dark host without a separate border; Get started OLED/gray/white. Logo inversion lives on leaf only. ZIP input outer line transparent in document and sheet shadow CSS. |
| Coupons | Existing green claimed/unclaimed tile palette and white text retained. Actual claimed `couponSuccessIcon…` SVG's first path black, second path white. Unclaimed checkbox untouched. |
| Product viewer / similar items / Other Sellers | Captured thumbnail leaf-to-SNP-root depth corrected from <10 to <12; eight captured thumbnail chains now qualify. Additive overlay policy preserves Person/Home images. Sustainability copy blue, rating count white, Other Sellers dollar/cents white. |
| Your Review / Search Orders | Existing review title/name/body/actions and pushed Search Orders exact renderer ownership retained; review secondary metadata explicitly gray. No broad text or raster inversion. |
| Shop the Show | Captured neutral hero/product shells now OLED, all existing scoped hero/product media taming retained. Reused product images restore both contentMode and clipsToBounds when no longer in product mode. |
| FULL export | FULL receives a bounded iOS background task to unwind when switching to NewTerm; secondary native sweeps stop on background. Export can archive the current unfinished capture as an honest partial snapshot rather than withholding all evidence. It never fabricates completion, rewrites the live receipt or falls back to an older run. |

Evidence reviewed: 14 v7.585 viewport captures (211332 through 220603), relevant v7.584 predecessor captures, 23 follow-up screenshots IMG_7604–IMG_7632, supplied transcript requests and the current v7.591 export-error screenshot. Not every number in those screenshot ranges was supplied/relevant. Screenshots show paint, while probes supply exact owners and ancestry; neither substitutes for a fresh device test of this build.

No unrelated Person/Home shared overlay teardown, native geometry rewrite, production recurring scan, or automatic git push was introduced.
