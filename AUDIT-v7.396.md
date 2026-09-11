# AmazonDark v7.396 audit — checkout address transition floor

## Base

- Direct parent: `7.395~ui-coverage-audit-fix`.
- All v7.395 theming and latent-state coverage is preserved.
- Evidence source: `AmazonDark-v7.395-skeleton-1789084312743-75987-transition.jsonl` from the user-supplied transition export.

## Probe finding

The transition probe captured the exact bright owner while **Change your delivery address** was navigating from checkout to the address-selection page.

At uptime ~`164834.9646` the incoming hierarchy contains:

- class: plain `UIView`
- controller: `AMIWebViewController`
- rect: `(0, 97.7, 430, 834.3)`
- model background: `(1,1,1,1)`
- presentation background: `(1,1,1,1)`
- parent at first capture: `_UIParallaxDimmingView`
- surrounding checkout controller: `AMSModalLayoutFullScreenViewController`

The outgoing `AMIWebViewController` root is already OLED black while translating left. At ~`164835.4761` the same incoming root is still opaque white after landing under `UIViewControllerWrapperView`. At ~`164835.4927` Amazon finally repaints it black. This leaves roughly half a second in which UIKit exposes the native white root despite the Web content and surrounding checkout surfaces already being dark.

## Fix

`ADCheckoutAMIWebRoot7396()` claims only the probe-proven family:

1. AmazonDark enabled.
2. A live `AMSModalLayoutFullScreenViewController` exists.
3. Exact runtime class is plain `UIView`.
4. The view's direct responder is `AMIWebViewController`, proving it is that controller's root view rather than a descendant WebKit/DOM surface.
5. Candidate paint is bright neutral.
6. If mounted, it is in the same checkout/AppCX window.
7. If geometry is already available, it must be effectively full content width and tall enough to be a page root.

Once claimed, the exact root remains OLED through later Amazon background assignments. The owner runs through the existing `UIView` mount and `setBackgroundColor:` hooks, so no timer or traversal is required.

## Non-interference

The fix does **not** alter:

- navigation transforms or animation duration,
- alpha/hidden state,
- `UINavigationController` push behavior,
- WebKit DOM/CSS content,
- normal `AMIWebViewController` roots outside a live checkout modal,
- the existing v7.375 checkout tan-plane owner,
- the v7.389 checkout app-switcher shield fix.

## Probe/handoff

All current probe identities are bumped to v7.396. The handoff regression now explicitly verifies that a direct-parent v7.395 startup receipt can locate Amazon when `plutil` is unavailable.

## Architecture

No MutationObserver, interval, RAF, Web scroll listener, polling loop, recurring hierarchy scan, new WKUserScript, generic transition overlay, or SpringBoard snapshot replacement is added.
