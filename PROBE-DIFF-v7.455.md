# R2 Product Detail vs R3 Cart — FULL probe diff

## R2: Product Detail, v7.453, problematic

- WebViews: 1
- PDP detected: yes
- Starting WebKit offset: ~3725 px
- WebKit content height: ~12845 px
- PDP stream: started successfully
- Stream termination: `document-backgrounded`
- Stream batches: 13
- Emitted/visited nodes before stop: 289 / 289
- Automatic Web walk: never started successfully
- `WEB_SWEEP_END`: `root-init-failed totalSteps=0`
- Archive state: partial

## R3: Cart, v7.454, working automatic walk

- WebViews: 1
- PDP detected: no
- Automatic root steps: 10
- Root offsets observed: 0, 685, 1370, 2055, 2375, 2375, 2392, 2392, 2392, 2392
- Mounted nodes grew: 2383 -> 5637
- Post-walk stream: completed
- Stream batches: 186
- Emitted/visited nodes: 5637 / 5637
- Nested-owner initialization later stopped only because Amazon was backgrounded
- Archive state: partial

## What the diff proves

The generic automatic walker is functioning on Cart. The Product Detail failure is route/renderer specific, not a universal probe transport failure and not a simple DOM-size issue: the working Cart capture handled substantially more nodes than the stopped PDP capture.

The product path had already been isolated historically: v7.450 documented that actively driving PDP scroll state could collapse Product Detail's WebKit content height from roughly 11k–13k px to 779 px. v7.453 removed the PDP no-scroll exception, recreating the unsafe architecture. In R2, the up-front exhaustive product serializer also occupied the renderer until backgrounding stopped it before the walk even began.

## v7.455 resolution

- Product Detail: no automatic scroll mutation, no native scroll sweep, no exhaustive full-DOM product serializer.
- Product Detail: one temporary manual-scroll observer plus bounded visible snapshots after 220 ms idle; finish at bottom.
- Cart/Search/other menus: retain the automatic v7.454 walker.
