# v7.537 review

The transition probe captured the second keyboard recreation but cannot see the remote process's individual keycap colors. It does prove that `UIInputSetHostView`, `_UIRemoteKeyboardPlaceholderView`, and `AmazonDarkOLEDBacking7130` remain black through the end of the capture.

The v7.536 hypothesis was incomplete. Current WebKit has two input-trait paths. Standard modern WKWebView uses an async/BrowserEngineKit path backed by `WKExtendedTextInputTraits`, and WebKit's own `restoreDefaultValues` method explicitly resets `keyboardAppearance` to `UIKeyboardAppearanceDefault`. Guarding only the legacy cached `UITextInputTraits` object does not prevent that reset.

v7.537 hooks the exact `WKExtendedTextInputTraits` owner: its `setKeyboardAppearance:` is clamped to Dark while AmazonDark is enabled, and `restoreDefaultValues` reapplies Dark after WebKit restores its defaults. The v7.536 runtime class-replacement experiment is removed. All modal paint/geometry remains unchanged from v7.535/v7.536.
