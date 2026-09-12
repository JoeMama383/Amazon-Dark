from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text(); C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text(); SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
F=json.loads((ROOT/'tests/fixtures/v7414-location-navigation-renderer.json').read_text())

assert 'Version: 7.415~location-text-finalize-fix' in C
assert '#define AD_VERSION "v7.415-location-text-finalize-fix"' in S

# Current probes prove the real Nile location root is an AppCX bottom-sheet root only
# ~81.9% of screen height. The v7.414 owner must not inherit the old >=85% rejection.
block=S[S.index('// v7.414: current AppCX/Nile location navigation ownership.'):S.index('static int ADReactSurface7226', S.index('// v7.414: current AppCX/Nile location navigation ownership.'))]
for token in ('AppCXBottomSheetContentView','AppCXBottomSheet','navigation-root','WrappedNileFeatureContainer','kADLocationNileRoot7414'):
    assert token in block, token
assert 'size.height>=sb.size.height*0.85' not in block
assert F['bottom_sheet_root']['rect'][3] == 763.0

# ZIP: exact 394x44 input gets gray control fill/gray React border; exact 394x45
# RNCEKV button gets OLED/gray and neutral text is lightened.
for token in ('ADLocationNileInput7414','ADLocationNileApply7414','ADMenuButtonFill7255()','ADMenuButtonBorder7255()',
              'ADLocationNileOwnField7414','ADLocationNileLightStorage7414'):
    assert token in block, token
assert F['zip']['input_background'] == [1.0,1.0,1.0,1.0]
assert F['zip']['apply_background'][:3] == [0.941,0.757,0.294]
assert F['zip']['apply_text_foreground'][0] < 0.1

# Address cards: probe says UIView/model background can already be black while the
# RCT border raster still has layer.contents. The fix therefore must recommit the
# React background and explicitly invalidate both UIView and CALayer display.
assert 'ADLocationNileCard7414' in block
commit=block[block.index('static void ADLocationNileCommitBackground7414'):block.index('static void ADLocationNileSetReactBorder7414')]
assert 'setBackgroundColor:' in commit
assert '[v setNeedsDisplay]' in commit and '[v.layer setNeedsDisplay]' in commit
assert 'removeAnimationForKey:@"backgroundColor"' in commit
assert all(c['model_background']==[0.0,0.0,0.0,1.0] and c['layer_contents'] for c in F['location_cards'])

# Country rows/list surfaces: bright neutral React surfaces and wide 380-402pt rows
# inside only this marked root are OLED. Thin separators use our standard gray.
assert 'ADLocationNileWideRow7414' in block and 'ADLocationNileThinDivider7414' in block
assert 'ADBrightNeutralColor708(bg)||ADBrightNeutralColor708(lbg)' in block
assert 'ADLocationNileCommitBackground7414(v,ADMenuButtonBorder7255())' in block

# Preserve semantic color. Neutral border setters become gray, while saturated
# orange/blue border writes pass through unchanged; no image/SVG filter is added.
rct=S[S.index('%hook RCTView'):S.index('%hook RNSVGSvgView')]
assert 'ADLocationNileNeutralBorder7414(value)' in rct
assert ':value' in rct[rct.index('ADLocationNileNeutralBorder7414(value)')-180:rct.index('ADLocationNileNeutralBorder7414(value)')+220]
for forbidden in ('brightness(0) invert(1)','setTintColor:','colorInvert','hueRotate'):
    assert forbidden not in block, forbidden

# Final-paint text ownership exists in both React text renderers, including drawRect.
paragraph=S[S.index('%hook RCTParagraphComponentView'):S.index('%hook RCTTextView')]
text=S[S.index('%hook RCTTextView'):S.index('%hook UILabel')]
assert 'ADInLocationNile7414' in paragraph and 'ADLocationNileLightString7414' in paragraph
assert 'ADInLocationNile7414' in text and 'ADLocationNileLightStorage7414' in text

# Architecture remains event-driven. One bounded prime is permitted only at exact root mark.
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in block,bad
assert 'seen<640' in block

# All diagnostic identities are current and workflows remain universal.
assert 'VER=7.415' in UI
assert 'AD_PROBE_VERSION=7.415' in SK and 'AD_PROBE_NAME=AmazonDark-v7.415' in SK
assert 'AMAZONDARK v7.415 UNIVERSAL' in INC and 'AmazonDark-v7.415-ui-viewport.arm' in INC
assert "version:'7.415'" in JS
print('PASS: v7.414 owns the current Nile bottom-sheet renderer early, repaints stale card rasters, fixes ZIP/country surfaces/text, preserves semantic colors, and keeps universal probes')
