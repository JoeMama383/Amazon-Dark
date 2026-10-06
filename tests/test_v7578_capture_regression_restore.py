from pathlib import Path
from payload_source import block
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); M=(R/'src/ADNewMenus7482.js.inc').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.579~prime-refinement-paint-only' in C
assert '#define AD_VERSION "v7.579-prime-refinement-paint-only"' in T
assert 'AmazonDark-v7.579-prime-refinement-paint-only-source.zip' in CMD
assert (R/'tests/test_v7574_capture_ui_completion.py').is_file()
assert '/* v7.574: probe-confirmed capture UI completion' in M
for token in ('button.dpx-reviews-pill','background-color:rgba(0,0,0,.9)','events-pcpo-placeholder-widget'):
 assert token in M,token
frag=block(T,'ADCapturedMediaJS7574')
for token in ('ad7574-captured-media','_single-video-ads-card_style_productImage__','#ad7380-price-history','_p13n-mobile-sims-fbt_','_pcpo-offer_style_imageclass__','_hve-rankable-banner_style_bannerImage__'):
 assert token in frag,token
assert 'MutationObserver' not in frag and 'setInterval' not in frag and 'requestAnimationFrame' not in frag
assert 'base=[base stringByAppendingString:ADCapturedMediaJS7574()];' in T
assert T.count('querySelectorAll(')==1
print('PASS: current build preserves the v7.578 capture-completion regression and production media/CSS contract without reopening recurring-work or performance regressions')
