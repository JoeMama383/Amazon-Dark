from pathlib import Path
R=Path(__file__).resolve().parents[1]
C=(R/'layout/DEBIAN/control').read_text(); T=(R/'src/Tweak.xm').read_text(); CSS=(R/'src/ADNewMenus7482.js.inc').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.528~interests-plus-white-fix' in C
assert '#define AD_VERSION "v7.528-interests-plus-white-fix"' in T
for token in (
    '#a-page:has(#interests-ai-sticky-div):has(#product-grid)',
    '#product-grid .lists-framework-unfilled-heart-icon{color:#fff!important;fill:#fff!important;stroke:#fff!important;',
    '#interests-ai-sticky-div :is(img,picture,source){filter:brightness(.78)!important;',
    ':is(.a-button.a-button-primary,.a-button.a-button-primary.a-button-focus,.a-button.a-button-primary.a-button-active,.a-button-stack>.a-button,.a-button-stack>.a-button.a-button-primary){background:#000!important;',
    '#interests-ai-sticky-div :is(.a-button-selected,[aria-pressed=true],[class*=selected]){border-color:#2162a1!important;'
): assert token in CSS, token
for h in ('## FULL — v7.528','## VIEWPORT — v7.528','## TRANSITION — v7.528'): assert h in CMD,h
print('PASS: v7.528 preserves the v7.527 Interests/product-grid OLED family')
