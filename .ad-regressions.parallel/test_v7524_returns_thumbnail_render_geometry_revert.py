from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=(R/'src/ADPersonReturns7514.inc').read_text()
t=(R/'src/Tweak.xm').read_text()
for s in ['ADPersonReturnsThumbnailShellGeometry7524','ADPersonReturnsThumbnailShell7524','ADPersonOwnReturnsThumbnailShell7524','ADPersonReturnsThumbnailLeaf7524','ADPersonReturnsCardHasThumbnail7524']:
    assert s in p, s
# The left lane is now treated as real thumbnail content, so the centering repair remains
# shipped but no-ops whenever the probe-backed thumbnail lane is present.
center=p[p.index('static void ADPersonCenterReturnsText7522'):]
assert 'if(ADPersonReturnsCardHasThumbnail7524(card))return;' in center
assert 'usedRectForTextContainer:tc' in center and 'CGFloat dx=' in center
# Exact thumbnail shells are cleared both in ordinary ownership and direct background writes.
owner=t[t.index('static void ADPersonOwnView7206'):t.index('static BOOL ADPersonPrimaryFont7206')]
assert 'ADPersonReturnsThumbnailShell7524(v)' in owner
assert 'ADPersonOwnReturnsThumbnailShell7524(v);' in owner
assert 'BOOL returnsThumbShell=surface==ADReactSurfacePerson7226&&ADPersonReturnsThumbnailShell7524(v);' in t
assert 'else if(returnsThumbShell)ADPersonOwnReturnsThumbnailShell7524(v);' in t
# The React thumbnail raster is now a first-class product media leaf.
assert 'else if(ADPersonReturnsThumbnailLeaf7524(iv))kind=11;' in t
final=t[t.index('static void ADPersonFinalizePersonImage7235'):t.index('// v7.285 Alexa suggestion-card media split', t.index('static void ADPersonFinalizePersonImage7235'))]
assert 'ADApplyNativeTWBCached7183(iv,NO);' in final
print('PASS: v7.524 keeps the Returns thumbnail lane real/tamed and suppresses the v7.522 text recenter when the thumbnail slot is present')
