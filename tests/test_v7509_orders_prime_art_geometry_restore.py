from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
J=''.join(json.loads(line) for line in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
assert 'Version: 7.509~orders-prime-art-geometry-restore' in C
assert '#define AD_VERSION "v7.509-orders-prime-art-geometry-restore"' in T
assert 'AmazonDark-v7.509-orders-prime-art-geometry-restore-source.zip' in CMD
root='section.your-orders-mobile-content-container.aok-relative.js-yo-container'
sel=root+' [class*="_timely-reminders-information-tile_style_imageContainer"]{'
pos=J.index(sel); body=J[pos:J.index('}',pos)+1]
assert 'filter:brightness(.42)!important' in body
assert 'background-color:transparent!important' in body
for bad in ('position:','top:','bottom:','left:','right:','display:','margin:','transform:','height:','width:','overflow:'):
    assert bad not in body, (bad,body)
# Preserve authored background image by never using the resetting background shorthand on this owner.
assert 'background:transparent!important' not in body
# Outer-card tame and filter-sheet corrections remain intact.
assert 'box-shadow:inset 0 0 0 9999px rgba(0,0,0,.58)!important;' in J
assert 'legend.option-group__heading{' in J and '.order-filter-view__button-container--bottom{' in J
# Long-standing core hash contract remains unchanged.
def func(name):
 st=T.index(f'static NSString *{name}'); b=T.index('{',st); d=0
 for i in range(b,len(T)):
  if T[i]=='{': d+=1
  elif T[i]=='}':
   d-=1
   if d==0: return T[st:i+1]
 raise AssertionError(name)
core=func('ADCoreWebJS7271').replace('] stringByAppendingString:ADNewMenusJS7482()',']').replace('=[[NSString','= [NSString').replace('()]];','()];').replace('= [NSString','=[NSString').replace('@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"','@"%@%@%@%@"').replace(',ADProductShareThemeJS7403(),\n        ADProductShareTWBJS7403(),ADShareProbeSuppressJS7403(),ADProductScrollPolishJS7404(),\n        ADProductScrollVideoBorderJS7405(),ADPDPGridCarouselFix7454(),ADPDPCompletionJS7405(),ADPDPSafeFrameJS7432(),ADPDPCompletionTWBJS7405(),ADPDPUICompletionJS7439(),ADPDPMainResidualJS7440(),ADPDPProbeBackedFixesJS7458(),ADFrameOwnerTriggerJS7440(),ADAddressManagementJS7412()','')
assert hashlib.sha256(core.encode()).hexdigest()=='41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
 assert bad not in J
print('PASS: v7.509 restores authored Prime artwork placement while preserving v7.508 taming and filter-sheet fixes')
