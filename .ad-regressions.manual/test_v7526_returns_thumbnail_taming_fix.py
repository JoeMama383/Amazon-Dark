from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.526~returns-thumbnail-taming-fix' in C
assert '#define AD_VERSION "v7.526-returns-thumbnail-taming-fix"' in S
# The Returns thumbnail is a real 48x52 person media leaf; it must bypass the
# generic 52px native-block threshold so the normal TWB path can apply.
block=S[S.index('static BOOL ADNativeMediaBlockedCached7146'):S.index('static void ADEnsureNativeTWBOverlay7270')]
assert 'ADPersonReturnsThumbnailLeaf7524(iv)' in block
assert 'ADPersonPreviouslyWatchedImage7235(iv)||ADPersonReturnsThumbnailLeaf7524(iv));' in block
# Handoff contract stays frozen.
assert 'export full' in CMD and 'export viewport' in CMD and 'skeleton-probe.sh export' in CMD
for bad in ['ui-probe.sh full','viewport-arm','viewport-export','git init','git push -uf','rm -rf .git']:
    assert bad not in CMD
print('PASS: v7.526 treats the Returns thumbnail as forced Person media so TWB applies while keeping the frozen handoff contract')
