# v7.339 scope and evidence

The user changed the requested UI baseline during this work to the exact commit
`1bd6d82bdff18ebba012794ef70e7c288a21336e` (v7.309: exact dog, Cart, footer, and XL
brand fixes). This supersedes the initial v7.338-UI staging copy, which was never
delivered. v7.309 supplies the complete UI. v7.338 supplies the successful launch
source and the removal of the obsolete readiness/purge mechanism. The new optional
probe is Amazon-process-local; it makes no new skeleton color changes.

The desired final treatment is OLED black (`#000`) for loading backgrounds and
the Cart strip. The screenshot alone cannot distinguish DOM, pseudo-element,
gradient, image, child-frame or native paint ownership. A diagnostic candidate is
never used as a theming selector in this build.

## Reconciled earlier evidence

| Source | Actual captured evidence | Consequence |
| --- | --- | --- |
| v7.293 commit `7df73ae` | Added black p13n carousel slots and gray direct children for non-empty/pre-`.p13n-uf` slots. | Covers a known family, not proof of every earlier skeleton stage. |
| `AmazonDark-v7.301-cart-ui-probe-20260903-101525-981-r1(1).txt` | Candidate/target lines 11/14 say `ready=loading`; first detailed `DOM_BEGIN`, line 312, says `ready=complete`. | Selection timing and paint-capture timing differ. |
| `AmazonDark-v7.307-cart-ui-probe-20260903-154759-416-r1(1).txt` | Target line 15 says `ready=loading`; first `DOM_BEGIN`, line 908, says `ready=complete`. At line 1121, `#sc-saved-cart` is 430×26 with 13px black top/bottom borders and black background. | This locates the strip's later owner; it does not capture that owner painting white. |
| Same v7.307 probe, line 1069 | `.a-loading-static` is 120×120, background `rgb(48,51,53)`, 1px gray border. | This later placeholder differs from the three tall white cards in the new screenshot. |
| v7.302 `c317795`, v7.308 `33418d1`, v7.309 `1bd6d82` | Expanded/restored rules under `#sc-page-container`, `#sc-saved-cart`, and `#p13n-uf-anchor`; v7.309 contains the earlier Cart correction already. | Reapplying those same rules would not establish a new fix. The user reported continued failure afterward. |
| New `IMG_6374.jpeg` / `IMG_6373.png` | Home: large white hero with gradient skeleton blocks. Cart: light full-width strip and three tall white placeholder cards. | Need current early paint identity, especially for the unprobed Home hero. |

The prior audits' description “ready=loading capture” referred to candidate
selection, not the detailed paint rows. It must not be treated as proof that the
white transient's CSS was captured. Historical assistant claims of a “proven
earliest-paint fix” were stronger than these raw rows establish.

## Capture mechanism

A file explicitly arms one fresh Amazon process. No valid arm file means no new
WebKit script/handler, observer, display link or file. The startup check is a small
file read. The successful SpringBoard constructor/source is unchanged.

For an armed run, a read-only script is installed in an isolated WebKit content
world, at document start, in all frames. It records mutation-time changes as well
as frame observations, rather than waiting for screenshot handling and a scrolling
scan. Newly navigated documents and child frames receive it before content loading.
This follows Apple's [document-start injection contract](https://developer.apple.com/documentation/webkit/wkuserscriptinjectiontime/atdocumentstart).
The native message channel stays within the probe's named content world; see the
[WKUserContentController API](https://developer.apple.com/documentation/webkit/wkusercontentcontroller).
Mutation delivery is tied to the document's microtask processing, per the
[DOM standard](https://dom.spec.whatwg.org/#mutation-observers).

Records include technical node IDs/classes, ancestry, geometry, backgrounds,
borders, gradients, pseudo-elements, image dimensions/loading state, readable
matched CSS declarations, stylesheet availability, document timing and child-frame
correlation keys. Frame correlation hashes omit query strings. Text/input/URL
values and pixels are excluded. Readable CSS declarations are not labeled as
cascade winners; inaccessible cross-origin sheets are counted.

Native samples capture visible UIKit owners and relevant layer/model/presentation
colors, gradients, geometry and image metadata. WebKit internal view trees are
skipped because their page pixels are described by the DOM channel. No native
setter, scene, process, gesture or window hook is added.

Capture ends after 120 seconds or the earlier arm expiry. A frame has a 6MiB output
limit; a process log has a 20MiB limit. Traversal/candidate/rule limits and maximum
observed scan time are logged explicitly. CSS-only shimmer motion is deduplicated;
color changes are kept. Pagehide ends capture, with pause/resume support for a
persisted back-forward page. Expired scripts return before installing any work.
The app's own animations, navigation, timing and scroll offsets are not modified.

## Interpretation and remaining limits

The first record must identify the new package; WebKit coverage additionally needs
`UCC_ATTACHED` and `FRAME_START`. `NODE` records retain white-to-dark transitions,
while `RULES` and `STYLES` help identify the source and whether the existing theme
was present. Native frames provide a second ownership path. `FRAME_LIMIT`,
`WEB_MESSAGE_LIMIT`, `NATIVE_FILE_LIMIT`, exceptions or nonzero clipping are evidence limits, not success.

This is a structural/paint-state probe, not a pixel recording. A mutation can be
observed before it is actually displayed. Closed shadow roots, raster-internal
colors, inaccessible stylesheet contents and renderer-only compositor states may
still require a narrower follow-up. Frames inside an offscreen WebView may log;
the native WebView geometry/window/visibility context must be reconciled before
calling one the visible culprit. Only a device run can establish the actual
Amazon owner and whether a one-frame transient was covered without clipping.

## Preservation and validation

`SOURCE-BASELINE.json` identifies the v7.309 commit, original hashes, v7.338 donor,
reviewed app transformation and delivered files. `test_cold_launch_policy.py`
exercises the actual production C selector (79 cases), verifies the entire v7.309
app outside the exact known transition removals and diagnostic entry points, and
requires the unchanged v7.338 SpringBoard hash. `test_startup_safety.py` retains the
constructor regression guard. Makefile, Actions, preferences, filters and installer
are byte-identical to the selected UI baseline.

`test_skeleton_probe.cjs` executes the shipped JavaScript against transient border,
gradient, one-frame placeholder, open-shadow and cross-origin-frame fixtures. It
checks unchanged page rendering/scrolling, omitted private strings, expiry and
navigation cleanup. A desktop browser test does not execute Apple's iOS 17
WKUserScript delivery or prove Amazon device rendering.

Validation in this workspace passed: all 79 production selection cases, full
v7.309 source preservation outside the explicit transition/probe edits, unchanged
v7.338 SB hash, constructor negative controls, Logos lint and both architecture
builds. The shipped JS passed browser fixtures in Chromium 151 (including nested
`:is()` selector lists). Linux WebKit could not run because this environment lacks
its shared-library dependencies; no iOS/WebKit device result is claimed.
Page teardown can drop a final asynchronous bridge message, so a missing end
marker alone is not a failed paint capture; use earlier node events and the next
document's independent `FRAME_START`. Expiry and the registered pagehide/pageshow
cleanup handlers were verified separately in the live fixture.

The local Linux toolchain can compile/link arm64 and arm64e, but warns about its
arm64e ABI. The handoff contains source only; the normal macOS Actions build
produces the installable package. The older `LAUNCH-AUDIT.md` is retained unchanged
as the v7.338 donor audit; the UI baseline for this new delivery is v7.309.
