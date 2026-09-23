# Validation — v7.456

Source parent: 615ba69c820e7625cb4e869d604da595ee2f478c (v7.455).

- 131 Python regression entrypoints passed in the available host environment.
- New gate payload compiled as C++98 and emitted the exact JavaScript bytes.
- Node syntax and modeled Share-lock/walk recovery regression passed.
- Existing automatic walker regression fixtures passed.
- `git diff --check` passed.
- Strict validation was attempted and stopped at the existing v7.385 C-linkage test because `clang` is not installed. Three entrypoints requiring clang were excluded from the separate 131-test run. Strict validation is NOT reported as passing.
- Theos/iOS build and physical-device run were not available. CI must build and validate before installation. Stock close-handler behavior is modeled, not device-verified.

## Capture comparison

All five v7.440 captures show root height 779 after the SSF sheet appears, while the product container keeps its original full height:

| Capture timestamp | Initial document height |
| --- | ---: |
| 203032-629-r1 | 14,401 |
| 203542-972-r2 | 14,405 |
| 203852-497-r3 | 14,112 |
| 204028-852-r4 | 13,178 |
| 204505-854-r5 | 12,737 |

The page gains `a-scroll-disabled`, fixed positioning, and later `aria-hidden`. A new SSF container exists under the tweak's hide-only Share stylesheet. This is evidence of a modal lock, not lost product DOM.

v7.454 Cart r3: ten real root steps reach y=2392; mounted nodes grow from 2383 to 5637. v7.453 PDP r2: inventory ends backgrounded after 13 batches/289 nodes, before walking. File size alone does not establish traversal. v7.455 intentionally bypasses automatic PDP walking.

## Acceptance after install

On PDP, screenshot-triggered FULL should record `PDP_SHARE_GATE` with stock-share-close followed by unlocked/ready, multiple changing root offsets, bottom coverage, and restored start offset. Backgrounding before completion is partial, not successful full coverage. Verify one Cart/Search capture still traverses normally. Verify VIEWPORT and TRANSITION export independently as TAR from the terminal.

Outstanding ad/card styling and transition UI reports remain open unless independently verified; no new UI completion claims are made here.
