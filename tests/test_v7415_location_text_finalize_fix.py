from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
F=json.loads((ROOT/'tests/fixtures/v7415-location-text-good-bad-diff.json').read_text())
assert 'Version: 7.416~location-canonical-owner' in C
assert F['same_renderer']
assert F['header']['hash']=='f1c585fa' and F['header']['bad_fg'][0]<0.1 and F['header']['good_fg'][0]>0.9
assert F['semantic_blue']['bad_fg']==F['semantic_blue']['good_fg']
text=S[S.index('%hook RCTTextView'):S.index('%hook UILabel')]
sig='- (void)setTextStorage:(NSTextStorage *)textStorage contentFrame:(CGRect)contentFrame descendantViews:(NSArray *)descendantViews'
assert sig in text
method=text[text.index(sig):text.index('- (void)setTextStorage:(NSTextStorage *)textStorage {')]
assert 'ADInLocationCanonical7416(v)' in method
assert 'ADLocationSheetLightStorage7196(v,textStorage)' in method
assert '%orig(textStorage,contentFrame,descendantViews);' in method
assert 'ADLocationSheetOwnText7196(v)' in method
# Neutral-only policy preserves authored saturated colors.
helper=S[S.index('static BOOL ADLocationNeutralColor7416'):S.index('static UIView *ADLocationSheetRoot7196')]
assert '(hi-lo)<=0.18' in helper
print('PASS: v7.415 final-commit race is retained but now scoped to the actual canonical location renderer')
