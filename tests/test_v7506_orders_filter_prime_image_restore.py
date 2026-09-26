from pathlib import Path
import json, hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
C=(R/'layout/DEBIAN/control').read_text()
V=(R/'scripts/validate.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.506~orders-filter-prime-image-restore' in C
assert '#define AD_VERSION "v7.506-orders-filter-prime-image-restore"' in T
assert 'VER=7.506' in UI
assert 'AD_PROBE_VERSION=7.506' in SK
assert 'tests/test_v7505_prime_card_visible_tame.py' in V
assert not (R/'tests/test_v7505_prime_card_visible_tame.py').exists()
assert 'AmazonDark-v7.506-orders-filter-prime-image-restore-source.zip' in CMD
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD

def func(name):
    st=T.index(f'static NSString *{name}')
    b=T.index('{',st); d=0
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
assert 'background:#11161c!important;background-color:#11161c!important;border:0!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_imageContainer"] :is(img,picture,source,svg,canvas){' in J
assert 'visibility:visible!important;opacity:1!important;display:block!important;filter:brightness(.92) saturate(.88)!important;' in J
assert root+' #past-purchases-section-id .past-purchase-tile__asin-thumbnail :is(img,picture,source,svg,canvas){' in J
assert 'filter:brightness(.88)!important;-webkit-filter:brightness(.88)!important;' in J
assert '#a-popover-1.a-popover.a-popover-secondary.a-declarative' in J
assert '.order-filter-view.js-order-filter-view :is(.option-group,.a-box-group.a-form-control-group,.option-group__radio-container,.option-group__radio-container>.a-box-inner){background:#000!important;' in J
assert '.order-filter-view.js-order-filter-view .js-apply-filter-button{' in J
assert '.search-bar__open-filter-link.a-box-focus' in J
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.506 restores Orders art visibility, themes the filter sheet to OLED, and keeps the v7.500-based non-scanning architecture')
