# AmazonDark v7.464 — PDP ad + book polish

Direct parent: **v7.463~pdp-reviews-polish**. The three supplied v7.463 VIEWPORT captures are the selector/paint evidence for this pass.

This build fixes the currently visible PDP issues without adding observers, polling, RAF loops, Web scroll listeners, or recurring DOM traversal:

- delivers the exact PDP child-ad repair sheet through a dedicated all-frame WebKit content world, so late SafeFrame/APE hydration no longer leaves the top standalone-ad heading black/hidden or the half-carousel renderer white
- keeps the compact/offsite ad shell OLED, forces its brand/product heading white, preserves ratings/semantic colors, and retains the existing configurable image taming
- makes the half-carousel `gridContainer`/grid/swiper neutral floors OLED, neutral copy white, and arrow controls dark with gray edges
- removes the square outer border from the BTF/hero standalone placements while preserving the child renderer’s existing rounded inner border; the separate ILM family keeps its accepted outer-edge ownership
- changes the Books subnav shadow/divider to the standard `#494d4d` gray
- removes the white Book details expander fade, makes the captured Book details text white, and makes the captured Customer reviews rating text white

FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.464 and remain separate workflows.
