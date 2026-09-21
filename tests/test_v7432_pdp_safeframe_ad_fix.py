from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.440~pdp-frame-ownership' in C
assert '#define AD_VERSION "v7.440-pdp-frame-ownership"' in S

# r2 proves two distinct PDP APE placements. All three known PDP APE frames now get a black main-frame backing.
pdp=S[S.index('static NSString *ADPDPCompletionJS7405'):S.index('static NSString *ADPDPCompletionTWBJS7405')]
for tok in [
    '#ape_detail_mobile-app-detail-ilm_mshop_iframe',
    '#ape_detail_mobile-hero-quick-promo_mshop_iframe',
    '#ape_detail_btf2_mshop_iframe',
]: assert tok in pdp,tok

# Root cause: the nested SafeFrame child must NOT require document.referrer to equal a PDP route.
sf=S[S.index('static NSString *ADPDPSafeFrameJS7432'):S.index('// v7.412 FULL r1',S.index('static NSString *ADPDPSafeFrameJS7432'))]
assert 'd.referrer' not in sf
assert 'window.top===window' in sf
assert "ad7432-pdp-safeframe" in sf

# Inert-by-default: activate only after the child DOM proves an Amazon ad renderer.
for tok in [
    'html[data-ad7-child-frame]:is(:has(#ad)',
    ':has([data-testid=renderer-factory-ad-container])',
    ':has([data-testid=ad-background-container])',
    ':has([data-ad-feedback-label-id])',
    ':has([id^=ad-feedback-])',
    ':has(.creative-container)',
]: assert tok in sf,tok

# White structural planes and stock dark neutral text are converted inside the proven ad child.
for tok in [
    'background-color: rgb(255, 255, 255)',
    'background:#000!important;background-color:#000!important',
    'color: rgb(15, 17, 17)',
    'color: rgb(0, 0, 0)',
    'color: rgb(0, 0, 17)',
    'color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important',
]: assert tok in sf,tok

# Semantic colors/media remain out of the neutral conversion lane.
for tok in ['.a-color-link','.a-color-price','[class*=prime]','[class*=star]','[class*=rating]','img,video,canvas,picture,svg']:
    assert tok in sf,tok
assert 'filter:brightness(' in sf and 'filter:invert(' not in sf

# No recurring mechanism was introduced.
for bad in ('MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in sf,bad

# It remains part of the single document-start all-frame core program.
core=S[S.index('static NSString *ADCoreWebJS7271'):S.index('static WKUserScript *ADSharedUserScript7387')]
assert 'ADPDPSafeFrameJS7432()' in core
attach=S[S.index('ADSharedUserScript7387(0,ADCoreWebJS7271'):S.index('ADSharedUserScript7387(0,ADCoreWebJS7271')+100]
assert 'NO,YES' in attach

# Validate the JavaScript emitted by the new Objective-C string literal.
lits=re.findall(r'@?"((?:\\.|[^"\\])*)"', sf)
js=''.join(bytes(x,'utf-8').decode('unicode_escape') for x in lits)
with tempfile.NamedTemporaryFile('w',suffix='.js',delete=False) as f:
    f.write(js); path=f.name
r=subprocess.run(['node','--check',path],text=True,capture_output=True)
Path(path).unlink(missing_ok=True)
assert r.returncode==0,r.stderr

# Probe identities are regenerated for this release.
assert 'VER=7.440' in UI
assert 'AD_PROBE_VERSION=7.440' in SK and 'AD_PROBE_NAME=AmazonDark-v7.440' in SK
assert 'AMAZONDARK v7.440 UNIVERSAL' in INC and 'AmazonDark-v7.440-ui-viewport.arm' in INC
assert "version:'7.440'" in JS
print('PASS: v7.437 themes hydrated PDP SafeFrame ad floors/text/media without a referrer dependency or recurring runtime work')
