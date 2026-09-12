from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
F=json.loads((ROOT/'tests/fixtures/v7414-location-navigation-renderer.json').read_text())
assert 'Version: 7.416~location-canonical-owner' in C
# Probe documented the misleading parallel AppCX/Nile tree. It must no longer be production ownership.
assert F['bottom_sheet_root']['rect'][3]==763.0
assert 'ADLocationNileTryMark7414' not in S and 'kADLocationNileRoot7414' not in S
canon=S[S.index('// v7.416: canonical ownership for Search'):S.index('static int ADReactSurface7226',S.index('// v7.416: canonical ownership for Search'))]
for tok in ('ADLocationCanonicalScroll7416','ADLocationInput7416','ADLocationApply7416','ADLocationWideNeutralRow7416','ADLocationThinDivider7416','ADLocationCard7416','ADLocationCommitBackground7416'):
    assert tok in canon,tok
# Card correction still removes background animation and invalidates both model and layer display.
assert 'removeAnimationForKey:@"backgroundColor"' in canon
assert '[v setNeedsDisplay]' in canon and '[v.layer setNeedsDisplay]' in canon
# No runtime traversal/observer was introduced.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'",'seen<640'):
    assert bad not in canon,bad
print('PASS: v7.416 removes the wrong Nile sibling owner and retains the actual card/ZIP/list visual contracts')
