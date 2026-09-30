## v7.524 — Returns thumbnail render + geometry revert

The latest FULL r1 confirms the white square is not supposed to be a dead placeholder. The left lane in `yr_item_0` is a real Returns thumbnail slot: the probe shows a 48×52 `RCTUIImageViewAnimated` thumbnail inside the reserved 60×67 lane. So this build does three things only: it keeps the left-corner border fix from v7.523, clears any exact left thumbnail-shell background planes back to transparent/black so a white box cannot survive rehydration, and classifies the Returns thumbnail raster as authored product media so it stays rendered and receives the normal tame path.

Because that left lane is real content, the v7.522 text recenter is now suppressed whenever the thumbnail slot is present, so Amazon's original text geometry is preserved.

The FULL / VIEWPORT / TRANSITION probe workflows are unchanged except for the v7.524 identity bump.
