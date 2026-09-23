# AmazonDark v7.455 audit — Product Detail manual FULL isolation

## Direct parent

`v7.454~carousel-probe-order` (`AmazonDark-v7.454-carousel-probe-order-source.zip`).

## Probe diff: problematic PDP R2 vs working Cart R3

### PDP R2 — v7.453

- `FULL_ROUTE_POLICY pdpDetected=1 universalWebWalk=1 webviews=1`
- Product WebView started at offset about `3725` with content height about `12845`.
- The full mounted-DOM stream started successfully and produced 13 batches / 289 emitted nodes before the document was hidden.
- The stream terminated with `reason=document-backgrounded`.
- The subsequent automatic walk ended `root-init-failed totalSteps=0`.
- Coverage was partial.

The user's observed UI freeze ended only after backgrounding Amazon. In this capture, backgrounding is also what terminated the product serializer before the automatic walker could run.

### Cart R3 — v7.454

- `FULL_ROUTE_POLICY pdpDetected=0 ... webviews=1`
- The automatic root walker ran 10 steps: `0 -> 685 -> 1370 -> 2055 -> 2375 -> 2392`.
- Mounted node count grew `2383 -> 5637`, proving lazy content was being exposed normally.
- The later read-only stream completed 186 batches / 5,637 emitted nodes.
- Only after that did backgrounding stop nested-owner initialization, so the exported run was partial even though the main automatic document walk worked.

### Historical Product Detail control

The v7.450 audit already isolated programmatic Product Detail scroll mutation as unsafe. Historical v7.435 PDP captures had roughly 7,530 / 7,546 / 9,074 mounted nodes and 11,341 / 11,341 / 13,076 px document heights before active sweep; after the probe drove those product renderers, final WebKit content height was 779 px. v7.450 therefore introduced a PDP no-scroll policy. v7.453 later removed that protection when Product routing was made universal again.

## Diagnosis

There are two product-specific risks and neither exists in the working Cart trace:

1. An exhaustive PDP style serializer can occupy the product renderer long enough to make it appear locked; R2 only stopped once the document was backgrounded.
2. Programmatically driving PDP scroll state was already shown historically to destabilize/collapse the product renderer.

Therefore changing scheduler order around the same product operations is the wrong fix. The safe boundary is to stop doing both operations on PDP while leaving the proven generic walker alone elsewhere.

## v7.455 implementation

PDP FULL now uses user-driven scroll checkpoints:

- no `ADUIScrollCommand7446` in the PDP branch;
- no native `setContentOffset:` PDP sweep;
- no exhaustive `ADPDPMainStream7451` run on the PDP WebView;
- one temporary capture-phase scroll listener observes user movement only;
- after 220 ms scroll idle, a bounded visible sampler records technical paint/media/DOM metadata without visible text values;
- the sampler is capped at 460 unique visible elements and contains no TreeWalker;
- reaching the bottom finishes automatically; backgrounding early finishes partial; timeout is 300 seconds;
- non-PDP FULL remains the inherited automatic root/owner walker and mounted-DOM catch-up path.

## Device boundary

Static tests prove route separation, zero PDP scroll writes in the new path, bounded sampling, and JavaScript syntax. Only installation on the target Amazon/iOS build can confirm the Product Detail freeze is gone.
