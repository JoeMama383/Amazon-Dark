from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S
canon=S[S.index('// v7.416: canonical ownership for Search'):S.index('static int ADReactSurface7226',S.index('// v7.416: canonical ownership for Search'))]
# Exact visible tree contract: full-screen root + lower 394pt scroll, no route strings or sibling Nile tree.
for tok in ('ADLocationSheetRoot7196(v)','RCTScrollView','r.size.width>=388.0','r.size.width<=402.0','CGRectGetMinX(r)>=12.0','r.size.height>=100.0','r.size.height<=560.0'):
    assert tok in canon,tok
for old in ('ADLocationNile','ADLocationAux'):
    assert old not in S,old
for old in ('WrappedNileFeatureContainer','navigation-root'):
    assert old not in canon,old
# Four-menu palette ownership.
for tok in ('ADLocationCard7416','ADLocationInput7416','ADLocationApply7416','ADLocationWideNeutralRow7416','ADLocationThinDivider7416','ADMenuButtonFill7255()','ADMenuButtonBorder7255()','ADOLED()'):
    assert tok in canon,tok
# Direct card setter path can run before window classification and invalidates cached raster.
rct=S[S.index('%hook RCTView'):S.index('%hook RNSVGSvgView')]
assert 'BOOL locationCard=gP.enabled&&ADLocationCard7416(v);' in rct
assert 'removeAnimationForKey:@"backgroundColor"' in rct
assert '[v setNeedsDisplay]' in rct and '[v.layer setNeedsDisplay]' in rct
# Borders: only neutral borders become gray; selected orange stays authored.
assert 'ADLocationNeutralColor7416(value)' in rct
# Text: every React commit/final draw path uses canonical ancestry and neutral-only recolor.
para=S[S.index('%hook RCTParagraphComponentView'):S.index('%hook RCTTextView')]
text=S[S.index('%hook RCTTextView'):S.index('%hook UILabel')]
assert 'ADInLocationCanonical7416(v)' in para
assert 'ADInLocationCanonical7416(v)' in text and 'ADLocationSheetLightStorage7196' in text
# ZIP native input field is owned in both wrapper and RCTUITextField paths.
single=S[S.index('%hook RCTSinglelineTextInputView'):S.index('%hook RCTUITextField')]
field=S[S.index('%hook RCTUITextField'):S.index('%hook UIButton')]
assert 'ADLocationInput7416(v)' in single and 'ADLocationOwnInput7416(v)' in single
assert 'ADInLocationCanonical7416(v)' in field and 'setAttributedPlaceholder:' in field
# No recurring location mechanism and old competing systems are gone.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in canon,bad
assert 'VER=7.416' in UI
assert 'AD_PROBE_VERSION=7.416' in SK and 'AD_PROBE_NAME=AmazonDark-v7.416' in SK
assert 'AMAZONDARK v7.416 UNIVERSAL' in INC and 'AmazonDark-v7.416-ui-viewport.arm' in INC
assert "version:'7.416'" in JS
print('PASS: v7.416 uses one event-driven full-screen location owner for main/ZIP/country/current-location screens')
