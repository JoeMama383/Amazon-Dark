from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7415-location-text-good-bad-diff.json').read_text())
assert 'Version: 7.415~location-text-finalize-fix' in C
assert '#define AD_VERSION "v7.415-location-text-finalize-fix"' in S
# The two captures are the same renderer/geometry/text hashes; only the neutral foreground differs.
assert F['same_renderer']
assert F['header']['hash']=='f1c585fa' and F['header']['bad_fg'][0]<0.1 and F['header']['good_fg'][0]>0.9
assert F['description']['hash']=='25a87f27' and F['description']['bad_fg'][0]<0.4 and F['description']['good_fg'][0]>0.9
assert F['card_name']['hash']=='d80f7ca5' and F['card_name']['good_fg']==[1.0,1.0,1.0,1.0]
# Authored blue stays identical in good and bad captures; it must not be swept into the neutral repair.
assert F['semantic_blue']['bad_fg']==F['semantic_blue']['good_fg']
# v7.415 closes the real legacy RCTTextView final commit path, not a new timer/scan.
text=S[S.index('%hook RCTTextView'):S.index('%hook UILabel')]
sig='- (void)setTextStorage:(NSTextStorage *)textStorage contentFrame:(CGRect)contentFrame descendantViews:(NSArray *)descendantViews'
assert sig in text
method=text[text.index(sig):text.index('- (void)setTextStorage:(NSTextStorage *)textStorage {')]
assert 'ADLocationNileTryMark7414(v)' in method
assert 'ADLocationNileLightStorage7414(textStorage)' in method
assert '%orig(textStorage,contentFrame,descendantViews);' in method
assert 'ADLocationNileOwnText7414(v)' in method
# Match the known-good card state deterministically: neutral Nile text -> white only.
helper=S[S.index('static NSAttributedString *ADLocationNileLightString7414'):S.index('static BOOL ADLocationNileHasAncestorClass7414')]
assert 'UIColor *white=[UIColor whiteColor]' in helper
assert 'ADLocationNileNeutral7414(c)' in helper
assert 'NSForegroundColorAttributeName value:white' in helper
# No new recurring work.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in method,bad
# Probe identities regenerated.
assert 'VER=7.415' in UI
assert 'AD_PROBE_VERSION=7.415' in SK and 'AD_PROBE_NAME=AmazonDark-v7.415' in SK
assert 'AMAZONDARK v7.415 UNIVERSAL' in INC and 'AmazonDark-v7.415-ui-viewport.arm' in INC
assert "version:'7.415'" in JS
print('PASS: v7.415 closes RCTTextView final-commit race and deterministically matches the good location text render while preserving semantic blue')
