# Probe-to-ownership map: the five October 10 captures

| Screenshot | Forensic probe | Observed owner | Implemented path | Remaining uncertainty |
|---|---|---|---|---|
| Leave feedback, 1:12 | `AmazonDark-v7.620-ui-viewport-probe-20261010-131204-327-r1.tar` | Amazon WebKit page with nested cross-origin iframes and sponsored-feedback link; modal DOM not fully present in exported hierarchy | document-local semantic feedback-form activation and scoped OLED CSS | Dynamic feedback sheet may be in a remote context not reached by normal WebKit injection; verify on device. |
| iOS share sheet, 1:15 | `...131442-083-r2.tar` | `UIActivityViewController` and hosted `SHSheetSceneViewController` | request dark trait on presented activity controller in Amazon only | Remote ShareSheetUI content may ignore this trait; do not claim verified full OLED. |
| Microphone permission, 1:16 | `...131543-191-r3.tar` | `RCTView#sheet-view > #sheet-inset-view`, `RCTView#actionButton`, `RCTTextView#allowTitle`, leaf 44×44 `RCTUIImageViewAnimated` | native exact gated owner, OLED control fill and mic icon white | Native device rendering not verified. |
| Camera/Image/Guide/Actions, 1:16 | `...131637-612-r4.tar` | `RCTView#plus-menu-modal-container`, `#plus-menu-modal-divider`, `#custom-guide-mode-button`, `#automations-mode-button`, `RNSVGSvgView#cameraButtonIcon`, `#mediaUploadButtonPlusMenuIcon`, `#plus-menu-close-icon`, `RNSVGCircle` backing | native OLED floor/white copy/gray existing divider/glyph recolor, blue badge retained | Native device rendering not verified. |
| Alexa information, 1:17 | `AmazonDark-v7.620-ui-full-probe-20261010-131733-025-r5.tar` | WebKit `#a-page > .a-container.octopus-page-style`, `content-grid-card-cards`, `_Y29ud_bxcGridContent_`, `_Y29ud_bxcGridImage_` | OLED content floors, configurable leaf-only TWB, white neutral copy | White sections painted *inside* authored image pixels are not CSS floors and may remain as media; no Home raster modifications. |

## Black-floors contract

All actual page/card/modal/button **surfaces** introduced by this patch are OLED black. Neutral gray is used only for *existing* borders/divider, secondary labels, and disabled text; selected blue/new accent and authored teal links remain.
