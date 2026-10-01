# v7.547 review

Baseline: b0850071, v7.546. The user confirms the keyboard repair works. Keyboard helper code and hook bodies are unchanged.

Evidence: AmazonDark-v7.546-ui-viewport-probe-20261001-131133-978-r1.tar and IMG_7402.png. This capture has zero WebViews and a foreground RCTModalHostViewController containing sheet-view and sheet-inset-view. The title is an RCTTextView (12 characters, hash 06bf1a69); the close X is a one-character ZapfDingbatsITC RCTTextView. All seven text leaves have dark neutral foreground. A 430x1 RCTView owns borderBottomWidth=1. The white sheet spans the bottom safe area, and its sibling contains a full-screen navy backdrop.

Extend existing native savings/profile sheet classification using the exact App Settings heading. No new global sheet rule. A finite, 96-node-bounded initialization handles already-mounted owners once the heading is available. Existing lifecycle/layout/text-commit/final-paint hooks retain ownership through React updates. The backdrop is identified only by the captured sibling/child topology under this identified sheet. Divider color remains gray through subsequent border setter commits. The grabber is gray. No bounds, frames, transforms, border widths, corner radii, font metrics or input changes.

No extra recurring scan, observer or timer is introduced. The viewport captured the requested defects. Device visual verification of this new menu paint remains outstanding.
