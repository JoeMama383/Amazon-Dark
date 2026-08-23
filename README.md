# AmazonDark v7.0.34~probe

Diagnostic build based **directly on v7.0.33**. No production styling/TWB changes.

## Purpose
Pinpoint the four missing visual leaves in the Home category/ad card (e.g. Disney apparel / mugs / phone cases / keychains) without a document-wide scan.

## Trigger workflow
1. Open Amazon and leave the affected card visible.
2. Background Amazon.
3. Run: `notifyutil -p com.colindavidr.amazondark/probe-disney-media-7034`
4. SpringBoard automatically relays the completed report to:
   `/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents/AmazonDark-disney-media-probe-7034.txt`

## Probe scope
- manual only; never runs automatically;
- current main WebUI frame only;
- fixed 8 x 10 viewport point grid using `elementsFromPoint()`;
- at most 5 hit-stack elements, 5 ancestors, and 6 immediate visible children per sampled branch;
- hard cap: 180 unique records;
- records IMG/SVG/source state, background image/color, WebKit mask image, blend/isolation/filter/opacity, fill/stroke, pseudo-element paint, and geometry;
- no `querySelectorAll`, TreeWalker, MutationObserver, scroll listener, interval, RAF, or recurring timer.

The probe intentionally changes **no** Home styling.
