from pathlib import Path
import json, hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text(); V=(R/'scripts/validate.sh').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.508~orders-prime-bgimage-filter-floor-fix' in C
assert '#define AD_VERSION "v7.508-orders-prime-bgimage-filter-floor-fix"' in T
assert 'tests/test_v7506_orders_filter_prime_image_restore.py' in V
assert not (R/'tests/test_v7506_orders_filter_prime_image_restore.py').exists()
assert 'AmazonDark-v7.508-orders-prime-bgimage-filter-floor-fix-source.zip' in CMD

def func(name):
    st=T.index(f'static NSString *{name}'); b=T.index('{',st); d=0
    for i in range(b,len(T)):
        if T[i]=='{': d+=1
        elif T[i]=='}':
            d-=1
            if d==0: return T[st:i+1]
    raise AssertionError(name)
core=func('ADCoreWebJS7271').replace('] stringByAppendingString:ADNewMenusJS7482()',']').replace('=[[NSString','= [NSString').replace('()]];','()];').replace('= [NSString','=[NSString').replace('@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"','@"%@%@%@%@"').replace(',ADProductShareThemeJS7403(),\n        ADProductShareTWBJS7403(),ADShareProbeSuppressJS7403(),ADProductScrollPolishJS7404(),\n        ADProductScrollVideoBorderJS7405(),ADPDPGridCarouselFix7454(),ADPDPCompletionJS7405(),ADPDPSafeFrameJS7432(),ADPDPCompletionTWBJS7405(),ADPDPUICompletionJS7439(),ADPDPMainResidualJS7440(),ADPDPProbeBackedFixesJS7458(),ADFrameOwnerTriggerJS7440(),ADAddressManagementJS7412()','')
assert hashlib.sha256(core.encode()).hexdigest() == '41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"]{' in J
assert 'box-shadow:inset 0 0 0 9999px rgba(0,0,0,.58)!important;' in J
imgsel=root+' [class*="_timely-reminders-information-tile_style_imageContainer"]{'
pos=J.index(imgsel); body=J[pos:J.index('}',pos)+1]
assert 'filter:brightness(.42)!important' in body
assert 'background-color:transparent!important' in body
assert 'background:transparent!important' not in body
assert 'background:#11161c!important' not in J
assert 'legend.option-group__heading{' in J
assert '.order-filter-view__button-container--bottom{' in J
assert 'background:#000!important;background-color:#000!important;color:#fff!important' in J
assert 'order-filter-view__button-container--bottom{\n  background:#000!important;background-color:#000!important' in J
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.508 preserves CSS background artwork, evenly tames Prime surfaces, and seals the three remaining Orders filter white floors')
