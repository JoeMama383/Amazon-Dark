from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
U=(R/'scripts/ui-probe.sh').read_text()
K=(R/'scripts/skeleton-probe.sh').read_text()
CMD=(R/'COMMANDS.md').read_text()

assert 'Version: 7.462~search-cards-scanit-shell' in C
assert '#define AD_VERSION "v7.462-search-cards-scanit-shell"' in S

# FULL probe captured two Amazon class variants for the white description floors.
# Keep ownership inside the known cards carousel and match their shared exact suffix.
sel='.cards_carousel_widget-sug-container-top [class$=widget-sug-text]'
assert S.count(sel) >= 2
for decl in ['background:#000!important','color:#e8e6e3!important','-webkit-text-fill-color:#e8e6e3!important']:
    assert decl in S[S.index(sel):S.index(sel)+260], decl

# The square gray outline belongs to the 430x60 A9VSScanItSearchWidget shell,
# not to the two rounded A9VSScanItIngressButtonRedesign children.
block=S[S.index('static void ADPaintScanItSearchWidget7120'):S.index('%hook ANPSearchBarRightButton')]
assert 'root.layer.borderWidth=0.0;' in block
assert 'root.layer.sublayers' in block and 'frame.size.height<=1.5' in block
hook=block[block.index('%hook A9VSScanItSearchWidget'):]
assert '- (void)layoutSubviews' in hook
assert '((UIView *)self).layer.borderWidth=0.0;' in hook
# Preserve the existing rounded child-button border styling.
assert 'v.layer.borderColor=ADBorderGray706().CGColor;' in block
assert 'if(v.layer.borderWidth<0.5)v.layer.borderWidth=1.0;' in block

# Every build regenerates all probe identities and handoff commands.
assert 'VER=7.462' in U
assert 'AD_PROBE_VERSION=7.462' in K and 'AD_PROBE_NAME=AmazonDark-v7.462' in K
assert 'AmazonDark-v7.462-search-cards-scanit-shell-source.zip' in CMD
for h in ['## FULL — v7.462','## VIEWPORT — v7.462','## TRANSITION — v7.462']:
    assert h in CMD
print('PASS: v7.462 owns both Search description-floor variants, removes only the ScanIt shell border, and regenerates all probes')
