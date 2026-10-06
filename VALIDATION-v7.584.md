# AmazonDark v7.584 — One Medical / Health AI

Baseline: origin/main c83852ee (v7.583). All earlier fixes, including the authored Prime refinement dividers, are retained.

Evidence reviewed: three v7.582 FULL archives (183829, 183933, 184307), the 184525 VIEWPORT archive, and IMG_7592–IMG_7596.

Changes:
- One Medical LEGO landing/treatment floors, neutral headings and descriptions, FAQ text, condition tabs, input shells, CTAs and dividers use the AmazonDark palette.
- Health AI header, sidebar, message text, suggestions, sign-in controls, microphone/close/new-chat glyphs, composer and its bright fade are covered under warblerApplicationRoot.
- The exact native One Medical navy color joins the existing three-controller Pharmacy/Grocery chrome policy; logos and control geometry are untouched.
- Product/hero/carousel images and videos use the existing White Tame strength on media leaves. Sparkles and logos remain untamed; links, semantic accents and the New Chat teal badge are preserved.
- Shared One Medical PUI text, buttons, dividers and chevron rules cover the profile/menu family. IMG_7596 is screenshot-only: none of the supplied archives captures that profile picker. Its avatar and exact text owners cannot be verified from these probes; capture that screen after installing for any remaining owner-specific repair.

Validation:
- AD_STRICT_VALIDATE=1 sh scripts/validate.sh: PASS, 237 Python regressions plus Logos lint and payload/syntax preflights.
- New cascade fixture checks actual emitted CSS against probe-shaped medical/chat elements, including semantic exclusions, OLED surfaces and neutral glyphs.
- New media checks parse emitted JavaScript at disabled/0/45/100 preference values and prove that only artwork leaves match.
- Objective-C++/C++98 syntax and existing payload checks run through the strict suite using Zig 0.13 Clang on this Linux host.
- git diff --check.

No iOS SDK/Theos build or on-device visual verification was available here. This is a validated source release for the existing phone push / CI build workflow, not a compiled .deb. No private captures or screenshots are bundled. No probe runtime behavior, stock geometry, navigation, medical content or network behavior was changed.
