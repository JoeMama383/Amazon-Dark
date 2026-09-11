from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
W=(ROOT/'.github/workflows/build.yml').read_text()
V=(ROOT/'scripts/validate.sh').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.399~add-address-form-completion' in C
assert '#define AD_VERSION "v7.399-add-address-form-completion"' in S

def block(name,next_name):
    return S[S.index(f'static NSString *{name}'):S.index(f'static NSString *{next_name}')]

def spec_args(text):
    specs=re.findall(r'%\.\d+f',text)
    tail=text[text.rfind(')();",'):text.rfind('];')+2]
    args=re.findall(r'\b(?:factor|shade)\b',tail)
    return specs,args

stand=block('ADStandalonePaintJS7104','ADTWBJS')
specs,args=spec_args(stand)
assert specs == ['%.4f','%.4f','%.3f','%.4f','%.4f','%.4f','%.4f','%.4f','%.4f','%.4f','%.4f','%.3f'], specs
assert args == ['factor','factor','shade','factor','factor','factor','factor','factor','factor','factor','factor','shade'], args
matches=list(re.finditer(r'%\.\d+f',stand))
for i,m in enumerate(matches):
    ctx=stand[max(0,m.start()-140):m.start()]
    if 'rgba(0,0,0,' in ctx[-80:]:
        assert args[i]=='shade',(i+1,args[i],ctx[-100:])
    else:
        assert args[i]=='factor',(i+1,args[i],ctx[-100:])

twb=block('ADTWBJS','ADCheckoutFloorJS7369')
specs,args=spec_args(twb)
assert specs == ['%.3f']*14
assert args == ['factor','factor','factor','factor','factor','shade','shade','shade','factor','factor','factor','shade','factor','factor'], args
for token in ['#search .sbv-video-overlay','._c2Itd_videoOverlay_1H_Jm','FEATURED_ASINS_VIDEO_LIST']:
    assert token in twb,token

assert 'actions/setup-python@v5' in W
assert 'AD_STRICT_VALIDATE=1 sh scripts/validate.sh' in W
assert 'bash scripts/lint-logos.sh' in V
assert 'for f in tests/test_*.py' in V
assert 'python3 "$f"' in V
assert 'AD_STRICT_VALIDATE' in V

print('PASS: Claude audit locked — ADStandalone %.4f/%.3f mapping clean, ADTWB overlays use shade, CI enforces lint + Python regressions')
