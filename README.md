# v7.536 — Interests keyboard trait rewrite guard

Direct parent: v7.535. The supplied transition capture shows the Amazon-side keyboard host and remote placeholder remain OLED black through the later keyboard recreation, so the remaining failure is remote keycap appearance rather than keyboard-floor paint. v7.536 keeps all v7.535 modal paint/geometry unchanged and guards the exact concrete WebKit text-input-traits class discovered from `WKContentView`, clamping later `setKeyboardAppearance:` rewrites to dark. No polling, recurring traversal, or geometry changes.
