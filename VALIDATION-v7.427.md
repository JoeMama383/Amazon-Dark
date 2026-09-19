# Validation and scope

Input: AmazonDark-v7.426-ui-full-probe-20260919-093424-046-r1.txt and IMG_6964.png. The probe reports webviews=0, completed native sweep (10 steps, edge), restored offset, and END RUN.

105 available Python regression scripts passed; the prior clang-only linkage test remains unavailable. Logos lint and both probe shell syntax checks passed. The added fixture checks all 429 initial screen nodes, generic-root rejection and the compiled neutral-color predicate against black/gray/blue/orange/green/white samples. This is not an iOS rendering test.

The PDP and shared web payloads are byte-for-byte unchanged from v7.426. Native hooks use bounded ancestry and local SVG subtrees; no observers, timers, web rules or normal-use whole-window scans were added.

SVG implementation uses guarded solid-brush UIColor access and initWithColor, matching the public react-native-svg implementation. Unknown brush classes and unsupported initializers are left unchanged. Reference: https://github.com/software-mansion/react-native-svg/blob/main/apple/Brushes/RNSVGSolidColorBrush.mm

Device validation pending: header flat black, search/back contrast, card borders and product images, Add to cart pressed state, Ask anything when typing, colored SVGs and links, and scrolling to additional results. Build/link must run in the normal Theos Actions environment.
