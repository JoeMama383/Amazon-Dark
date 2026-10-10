"""Regression: plus-menu black 17pt titles cannot survive final React paint."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text()
control=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.624~alexa-plus-text-finalpaint' in control
assert '#define AD_VERSION "v7.624-alexa-plus-text-finalpaint"' in t
for line in [
 'static BOOL ADAlexaRepaintMountedText7624(UIView *v)',
 'if(!gP.enabled||!v||!v.window||!ADClassNameIs7183(v,"RCTTextView"))return NO;',
 'if(!ADAlexaSheetKind7622(v))return NO;',
 'if(ADAlexaRootAid7622(v,@"mode-button-new-badge"))return YES;',
 'ADMenuLightStorage7255(ts);',
 'if(ADAlexaRepaintMountedText7624(v))return;',
 'ADAlexaRepaintMountedText7624(v);',
 'if(ADAlexaRepaintMountedText7624((UIView *)self)){',
 'if(ADAlexaSheetKind7622(v)){',
]:assert line in t,line
assert t.count('ADAlexaRepaintMountedText7624(')>=4
# The renderer must be recolored at display time, not just while setting storage.
rct=t[t.index('%hook RCTTextView'):t.index('%hook UILabel',t.index('%hook RCTTextView'))]
assert rct.index('if(ADAlexaRepaintMountedText7624((UIView *)self)){') > rct.index('- (void)drawRect:(CGRect)rect {')
assert rct.index('ADAlexaRepaintMountedText7624(v);') > rct.index('%orig(textStorage,contentFrame,descendantViews);')
paragraph=t[t.index('%hook RCTParagraphComponentView'):t.index('%hook RCTTextView')]
assert 'if(ADAlexaSheetKind7622(v)){' in paragraph
assert paragraph.count('ADMenuLightStorage7255(ts);')>=2
# Real r4 probe's neutral black (rgb(15,17,17)) must convert, authored badge
# rgb(12,88,209) must remain blue; secondary rgb(86,89,89) is legible but
# may also be whitened under the existing ADMenuLightStorage conversion.
fixture=json.loads((ROOT/'tests/fixtures/v7624_alexa_plus_text_probe.json').read_text())
assert fixture['root']=='plus-menu-modal-container'
assert fixture['primary']['owner']=='automations-mode-button'
assert fixture['primary']['rgb']==[15,17,17]
assert fixture['badge']['owner']=='mode-button-new-badge'
assert fixture['badge']['rgb']==[12,88,209]
def dark_neutral(c):
 r,g,b=[x/255. for x in c];return max(r,g,b)-min(r,g,b)<=.16 and max(r,g,b)<.50
assert dark_neutral(fixture['primary']['rgb'])
assert not dark_neutral(fixture['badge']['rgb'])
# Do not turn this into an app-global text override or color a source raster.
assert 'THEMING-CONTRACT.md' in [p.name for p in ROOT.iterdir()]
contract=(ROOT/'THEMING-CONTRACT.md').read_text()
assert 'black or near-black text' in contract
for token in ['MutationObserver','setInterval(','object-fit: cover','background-size: cover']:
 assert token not in t[t.index('// v7.624: Run the probe-owned'):t.index('static void ADAlexaOwnVector7622')],token
print('PASS v7.624: actual r4 black React titles repaint white on mount and draw; blue New badge retained')
