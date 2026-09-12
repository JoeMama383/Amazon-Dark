from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
F=json.loads((ROOT/'tests/fixtures/v7412-location-aux-zip.json').read_text())
assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S
# Historical ZIP evidence remains the geometry contract.
assert F['aux_scroll']['rect']==[18.0,752.7,394.0,179.3]
assert F['input']['class']=='RCTSinglelineTextInputView' and F['input']['background']==[1,1,1,1]
assert F['apply']['background']==[0.941,0.757,0.294,1.0]
# Your Addresses Web/AUI theme remains intact.
web=S[S.index('static NSString *ADAddressManagementJS7412(void){'):S.index('// One immutable document-start program',S.index('static NSString *ADAddressManagementJS7412(void){'))]
for tok in ('#ya-myab-address-add-link','[id^=ya-myab-display-address-block-]','background:#303335!important','background:#000!important','border:1px solid #747a7c!important'):
    assert tok in web,tok
assert ':is(img,svg,.amazon-logo,[class*=sprite],.a-icon){filter:none!important' in web
# Native ZIP/Ship-outside work is now one canonical ancestry owner, not the deleted Aux scanner.
assert 'ADLocationCanonicalScroll7416' in S and 'ADInLocationCanonical7416' in S
assert 'ADLocationAuxTryMark7412' not in S and 'kADLocationAuxScroll7412' not in S
print('PASS: v7.412 visual contracts are retained through the v7.416 canonical location owner')
