# AmazonDark v7.454 — carousel correction + FULL walk-first probe

Parent: v7.453-isolated-probe. Source handoff; device behavior still requires installation verification.

## What changed

- Fixes the probe-recorded PDP sponsored grid carousel with exact child-frame selectors. The outer grid shell and carousel cards are OLED black, neutral borders are standardized to `#494d4d`, and the recorded price/currency leaves are white.
- Does **not** target the carousel arrow controls, CTA/link colors, or authored media, so their stock styling is preserved.
- FULL now starts the guarded document/visible-panel walk before the expensive detailed DOM stream. A slow serializer can no longer block the automatic walk from ever starting.
- Fixed-height vertical panels can be found directly from visible hit-test/ancestor geometry before DOM inventory exists. Horizontal carousels are excluded because discovery requires real vertical scroll span.
- After the root/primary pass, FULL runs detailed mounted-DOM inventory, walks any newly discovered nested owners, then runs an incremental unseen-node catch-up and coverage check.
- The stream keeps a per-run WeakSet so the catch-up does not serialize the same mounted elements again.

## v7.453 device evidence that drove this build

The r2 FULL capture did start the PDP stream, but the document was backgrounded while the stream was still running. It ended with `document-backgrounded`; the subsequent root walk returned `root-init-failed` with `totalSteps=0`. The capture still recorded the exact ad carousel nodes that are targeted by the v7.454 UI patch.

So v7.453 was **not** a deliberate manual-scroll FULL mode. Manually scrolling while Amazon stayed foreground could expose additional virtualized content, but the intended automatic walk never got a chance to run in that capture.

## FULL workflow

Take one screenshot in Amazon and keep Amazon foregrounded. v7.454 should begin moving the document/visible vertical panel automatically. Do not switch to NewTerm until the automatic movement has stopped and the view has returned to its original offset. Then run `sh scripts/ui-probe.sh status`; a successful run should report FULL `completed`, not `partial`, before export.

Manual scrolling is compatible, but it is not required and is not the default contract.

VIEWPORT and TRANSITION remain separate exports and keep their existing behavior.
