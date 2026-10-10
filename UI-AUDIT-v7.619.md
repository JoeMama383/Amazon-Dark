# v7.605–v7.619 UI carry-forward verification

**Method:** The original v7.613 source archive was compared byte-for-byte with v7.619. No v7.613 `src/` file was removed. The seven new post-v7.605 JavaScript implementation files **and their gnu++98 includes** are exact byte matches; all seven are appended once into the active shared WebKit theme payload in version order. Earlier v7.600–v7.604 theme implementations are also byte-matched. Regression tests prove source contracts, not actual rendered device pixels.

| First build | Requested implementation family | v7.619 source | Device outcome |
|---|---|---|---|
| 7.605 | Reduced carbon impact rounded authored border visibility | `ADSustainabilityBorder7605.js(.inc)` present, exact | Not verified |
| 7.606 | Climate Pledge Friendly image taming, dark rows, dividers, buttons | `ADClimatePledge7606.js(.inc)` present, exact | Not verified |
| 7.607 | Similar-item count and summarized-information divider | `ADPDPLastMile7607.js(.inc)` present, exact | Not verified |
| 7.608 | Review filter buttons, text, dividers and sprite preservation | `ADReviewFilterMenu7608.js(.inc)` present, exact | Not verified |
| 7.609 | Review photo background-image restoration and OLED review sort popup | `ADReviewBusiness7593.js.inc` + `ADReviewSortPopover7609.js(.inc)` retained | Missing-photo rendering still requires device confirmation |
| 7.610 | Updated Shopping As profile picker, notification neutral surfaces | `ADProfilePickerRepaint7610`, `ADNotificationsController7610` retained | Notification thumbnail recovery has not been proven |
| 7.611 | Your Saves/Lists OLED, gray filter pills and selected blue border | `ADYourSaves7611.js(.inc)` present, exact | Not verified |
| 7.612 | Amazon Live report sheet/video/follow/title card native owners | `ADLiveReportSheet7612`, `ADLiveOwnVideo7612`, follow/title/vector owners retained | Not verified |
| 7.613 | Keep shopping for images and white copy | `ADKeepShopping7613.js(.inc)` present, exact | Image loading still requires device confirmation |
| 7.614–7.619 | Version, compiler, probe transport and CI repairs | UI source preserved; no new UI painting proposed in v7.619 | Universal full menu coverage unverified |

## Known open gaps

The screenshots/probes from v7.605 predate these successive changes. Their issues may be **implemented in source but uncorrected in actual Amazon rendering**. In particular, the Order Details menu, live plus icon, review photos, Keep Shopping media, and universal FULL scanning on every menu cannot be declared fixed without a successful installation and fresh FULL/VIEWPORT captures. The audit specifically avoids that claim.

**See:** `DIFF-v7.619.md`, `VALIDATION-v7.619.md` and the downloadable `AmazonDark-v7.619-UI-source-audit.json` for complete code-source parity data.
