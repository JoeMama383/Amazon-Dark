# v7.534 review

Diffed the earlier v7.529 modal capture against the new v7.533 VIEWPORT capture. The modal root geometry itself remained Amazon-authored, but the v7.530 paint patch was too broad: it recolored every AUI button, the inner clear control, sheet/tab wrappers and border colors. That produced the altered clear-X geometry, top close white box and visible separator lines.

v7.534 removes that broad ownership. The modal patch now changes only the two white sheet floor owners to OLED, the `#textareaLabel` header to white, and the existing top close icon raster to white. It does not target the inner text-box clear control and contains no geometry declarations. The already-correct Update button remains owned by the inherited generic AUI dark-button path.

For the intermittent first-focus light keyboard, `ADPrepareSearchKeyboard7120` now mutates WebKit's cached `textInputTraitsForWebView` object before `WKContentView` becomes first responder, rather than waiting for a later trait query/refocus.
