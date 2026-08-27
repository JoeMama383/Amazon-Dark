## v7.141 search-results specificity/location fix probe

Built directly on v7.140. This revision fixes the probe-proven CSS specificity regression that left the Prime and ReviewStar compositor parents plus Add-to-cart under the generic white-glyph filter, explicitly excludes the 7x7 Sources chevron from broad Rufus floor ownership, and adds an exact GlowIngressView CALayer backing owner because v7.140 proved the native view/layer background were already black while a separate internal painter remained yellow. The screenshot probe now also dumps the exact GlowIngressView layer tree.
