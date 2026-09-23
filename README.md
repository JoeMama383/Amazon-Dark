# AmazonDark v7.459 — reliable VIEWPORT + Home hero sponsored pill

v7.459 is built directly from the exact v7.458 source. It addresses the two failures captured on-device after v7.458: VIEWPORT captures that often remained nonterminal after Amazon was backgrounded, and the Home single-video hero card's bright translucent Sponsored pill.

The supplied successful v7.458 VIEWPORT archive showed why the probe was unreliable: a 2,046-node capture was split across 107 WebKit continuation callbacks and took roughly six seconds to become terminal. On iOS, Amazon could be suspended before those continuations completed. v7.459 keeps FULL cooperative, but makes VIEWPORT one finite WebKit evaluation: it traverses the current document/shadow trees once, rejects off-screen nodes before computed-style serialization, records intersecting visible nodes, and returns terminal data without a continuation chain. The VIEWPORT final cross-frame flush is 200 ms instead of FULL's unchanged 900 ms. `ui-probe.sh export viewport` also waits up to ten seconds for an already in-flight terminal write, so switching quickly to NewTerm no longer creates a false failure.

The same probe identifies the Home hero pill exactly as `_single-video-card_style_sponsored-label-pill__*`, computed as `rgba(255,255,255,0.6)`. v7.459 changes only that Home-dashboard family to `rgba(0,0,0,0.6)`: identical 60% opacity, black instead of white. The Sponsored text/glyph colors are not overwritten.

No production MutationObserver, polling loop, RAF loop, scroll listener, or recurring hierarchy/document scan is added. The probe changes execute only when the explicitly armed diagnostic runs; the Home fix is declarative document-start CSS in the existing Home stylesheet.
