# REVIEW v7.526

Problem: v7.525 restored the Returns thumbnail lane and image, but the exact 48x52 Returns thumbnail was still not accepting Tame White Backgrounds.

Root cause: `ADPersonFinalizePersonImage7235` correctly classifies the Returns thumbnail as kind 11 and routes it to `ADApplyNativeTWBCached7183`, but the generic native media blocker still rejected it because its width is below the default 52pt threshold. `ADNativeMediaBlockedCached7146` already has a `personForced` exception list for exact Person product/media leaves; the Returns thumbnail leaf was simply missing from that list.

Fix: add `ADPersonReturnsThumbnailLeaf7524(iv)` to the exact `personForced` list in `ADNativeMediaBlockedCached7146`. This keeps the current border/shell/geometry work unchanged and only ensures the normal TWB overlay path is allowed for the real Returns thumbnail media leaf.
