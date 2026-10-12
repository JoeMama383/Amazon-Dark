# AmazonDark v7.636

The user confirms stock Amazon is responsive and the delay disappears with AmazonDark disabled. The v7.635 capture confirms 2,997 ms input-arrival delay, 3,188 ms input-to-RAF delay and 3,832 ms event-loop stalls. Focus remains AmazonDark's web styling/injection work.

Remove 54 redundant ancestor relational selectors from five payloads: New Menus (24), Menu Followup (15), Lists Registry (8), Returns (5), Review Business (2).

Example: `body:has(#dp) #dp` becomes `body:is(*,#dp) #dp`. Matching the descendant #dp already proves body contains #dp. The universal :is branch is always true and preserves the original ID specificity. The browser no longer needs that redundant relational check. Class-based witnesses use the same identity.

No route gates, coverage deletions, declarations, geometry, dynamic colors, media filters, observers or runtime scanners changed. All five decoded payloads round-trip to v7.635 by reversing the substitutions and release identifier. The v7.635 recorder is retained.

296 regression scripts pass, including match-set/specificity equivalence across empty, populated and nested subtrees. Three historical tests were updated only for equivalent selector spelling; their paint and geometry checks remain intact. Real iOS SDK syntax validation passes.

This is a targeted reduction in redundant stylesheet work, not a measured claim that all stalls are eliminated. The exact CSS rule or script responsible for the largest stall is not yet attributed. Reproduce the same interactions and collect PERFORMANCE alone to measure the effect. Do not repeat the stock-app comparison; the user's result is accepted.
