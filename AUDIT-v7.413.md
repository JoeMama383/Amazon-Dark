AmazonDark v7.413 validation / compile-fix audit
================================================

Release
-------
Version:       7.413~address-location-compile-fix
Runtime:       v7.413-address-location-compile-fix
Direct parent: 7.412~address-location-aux-theme

Exact build failure corrected
-----------------------------
The v7.412 RCTScrollContentView setBackgroundColor hook cast self to UIView *v but then
accessed self.layer. RCTScrollContentView is intentionally only forward-declared in Tweak.xm,
so Clang could not resolve the layer property on that static type. v7.413 changes only that
CALayer access to v.layer.backgroundColor, using the existing known UIView base pointer.

Compiler warning cleanup
------------------------
The permission classifier still declared/assigned micButton after v7.410 stopped using it for
classification. v7.413 removes that dead local/assignment. Camera/microphone behavior is unchanged.

Preserved UI/runtime behavior
-----------------------------
- Your Addresses Web/AUI theming from v7.412 retained.
- Ship outside the US native React theming from v7.412 retained.
- Enter a US zip code native React theming from v7.412 retained.
- v7.411 permission text and Choose-location first-paint ownership retained.
- v7.408 inactive switcher protection retained.
- v7.407 PDP skeleton treatment retained.
- No new runtime owner, selector, observer, timer, RAF, polling loop, Web scroll listener, recurring scan or WKUserScript family.

Probe refresh
-------------
- universal FULL helper/output: v7.413
- universal VIEWPORT helper/arm/output: v7.413
- transition/lifecycle helper/receipt/output: v7.413
- runtime ADSkeletonProbe arm/status/skeleton paths: v7.413
- direct-parent v7.412 receipt handoff: PASS

Validation performed
--------------------
- 84/84 bounded Python regression files excluding exhaustive handoff: PASS
- tests/test_probe_handoff.py exhaustive handoff suite: PASS
- tests/test_v7412_address_location_aux_theme.py: PASS
- tests/test_v7413_address_location_compile_fix.py: PASS
- tests/test_v7413_skeleton_direct_parent_handoff.py: PASS
- tests/test_probe_embedding.py: PASS
- bash scripts/lint-logos.sh: PASS
- sh -n scripts/ui-probe.sh: PASS
- sh -n scripts/skeleton-probe.sh: PASS
- sh -n layout/DEBIAN/postinst: PASS
- layout/DEBIAN/postinst mode: 755

Environment limitation
----------------------
Theos/iOS SDK is not installed in this execution environment, so a local arm64/rootless compile
is not claimed here. The exact source-level Clang error is removed; the phone/GitHub Actions build
remains authoritative for final compilation/package validation.
