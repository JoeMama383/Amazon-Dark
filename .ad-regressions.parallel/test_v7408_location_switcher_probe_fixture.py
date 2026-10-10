from pathlib import Path
import json, re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
f=json.loads((ROOT/'tests/fixtures/v7408-location-switcher-shield.json').read_text())
assert f['applicationState'] != 0
assert f['windowClass']=='AppCXWindow'
assert f['effectClass']=='UIVisualEffectView'
_,_,ww,wh=f['windowRect']; _,_,ew,eh=f['effectRect']
r,g,b,a=f['tintRGBA']; hi=max(r,g,b); lo=min(r,g,b)
# Mirror only the published v7.408 invariant against the exact probe witness.
assert ew >= ww*.94 and eh >= wh*.78
assert a >= .18 and (hi-lo) <= .065 and lo >= .45
# Crucially, the fix cannot require the route/controller that happened to expose the bug.
geo=re.search(r'static BOOL ADInactiveSnapshotGeometry7408\(UIVisualEffectView \*effect\)\{(.*?)\n\}',S,re.S).group(1)
for forbidden in ['SNPViewController','AMIWebViewController','gADCheckoutLiveModal7375','ADPaymentSheetLive7402','bottom-sheet']:
    assert forbidden not in geo, forbidden
assert 'AppCXWindow' in geo and 'UIApplicationStateActive' in geo
assert 'ew<ww*0.94||eh<wh*0.78' in geo
assert '(hi-lo)<=0.065&&lo>=0.45' in S and 'a>=0.18' in S
print('PASS: exact location-switcher probe witness satisfies the generalized inactive AppCX neutral-shield invariant without a route/payment prerequisite')
