# AmazonDark v7.0.27~probe

Diagnostic build based directly on v7.0.26.

Certain corrections:
- Removes the unsafe `#gwm-Deck` card-floor owner that blackened color/composited top hero cards.
- Keeps proven below-fold `#gwm-Deck-btf` / legacy floor ownership.
- Restores only `[class*=badgeMessage] { background-color:transparent; box-shadow:none; }` to remove the new white plate behind `Limited time deal`. No `% off` badge repaint and no text-color rule.

Probe target:
- exact hero vs ordinary-row ancestry;
- standalone APE / mobile-mshop-ad frame surfaces;
- Sponsored text and info-glyph hosts;
- pseudo-element/background-image/mask implementations;
- deal/badge message hosts.

Probe shape:
- all WebKit frames receive a tiny documentStart probe bootstrap;
- one fixed current-viewport `elementsFromPoint()` snapshot;
- only bounded local neighborhoods around visible semantic hits;
- child frames reply through probe-only `postMessage`;
- no querySelectorAll, TreeWalker, MutationObserver, scroll listener, interval, RAF loop or recurring probe timer.

Workflow:
Open Amazon on the target Home viewport -> background once -> wait about 2 seconds -> run the supplied single NewTerm export block.
