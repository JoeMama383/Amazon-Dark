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
assert 'Version: 7.505~prime-card-visible-tame' in C
assert '#define AD_VERSION "v7.505-prime-card-visible-tame"' in T
assert 'VER=7.505' in UI
assert 'AD_PROBE_VERSION=7.505' in SK
assert 'tests/test_v7504_v7500_ui_followup.py' in V
assert not (R/'tests/test_v7504_v7500_ui_followup.py').exists()
assert 'AmazonDark-v7.505-prime-card-visible-tame-source.zip' in CMD
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD

# Probe implementation remains on the successful v7.500 line; current probe identity is checked above.
# The hash contract below uses the long-standing exact core normalization from v7.504.
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
assert 'box-shadow:inset 0 0 0 9999px rgba(0,0,0,.58)!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"]::before{' in J
assert 'content:none!important;display:none!important;background:none!important;box-shadow:none!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_imageContainer"]{' in J
assert 'filter:brightness(.42)!important;-webkit-filter:brightness(.42)!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_tileContainer"] img{' in J
assert 'filter:none!important;-webkit-filter:none!important;box-shadow:none!important;mix-blend-mode:normal!important;opacity:1!important;' in J
assert root+' [class*="_timely-reminders-information-tile_style_tileContent"]{' in J
assert 'z-index:2!important' not in J
# v7.504's image-killing overlay must not survive.
assert 'background:rgba(0,0,0,.58)!important;border-radius:inherit!important;z-index:1!important;' not in J

# Keep the requested Filter and PDP thematic-image fixes from the v7.500-based branch.
assert '.search-bar__open-filter-link.a-box-focus' in J
assert '#dp#dp [class*="_sp-mobile-thematic-bundle_thematicBundle-mobile_thumbnail-background__"]{' in J
assert 'background:#000!important;background-color:#000!important;border-color:#494d4d!important;' in J
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in J, bad
print('PASS: v7.505 preserves Prime images, applies one even visual tame without overlay stacking, and retains v7.500-based Filter/PDP fixes')
