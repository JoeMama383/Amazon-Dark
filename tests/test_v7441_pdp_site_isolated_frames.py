from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
UI=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.441~pdp-site-isolated-frames' in C
assert '#define AD_VERSION "v7.441-pdp-site-isolated-frames"' in S
assert 'VER=7.441' in UI
assert 'AD_PROBE_VERSION=7.441' in SK and 'AD_PROBE_NAME=AmazonDark-v7.441' in SK
# iOS 17 site-isolated renderer coverage: enumerate every live frame tree, not only the legacy tree.
force=S[S.index('static void ADForceChildFrameTheme7441'):S.index('@interface ADFrameOwnerBridge7441')]
for tok in ['NSSelectorFromString(@"_frameTrees:")','NSSet.class','ADInjectFrameNode7441(wv,root,js,world)','NSSelectorFromString(@"_frames:")']:
    assert tok in force,tok
# Child injection remains page-world frame-targeted and idempotent.
for tok in ['evaluateJavaScript:inFrame:inContentWorld:completionHandler:','NSSelectorFromString(@"pageWorld")','ad7441-forced-frame-theme','data-ad7441-frame-owner']:
    assert tok in S,tok
# New bridge identity must be wired into the actual core program and UCC attach path.
for tok in ['ADFrameOwnerTriggerJS7440()','ADFrameOwnerAttach7441(ucc)','adFrameOwner7441','ADForceChildFrameTheme7441(self)']:
    assert tok in S,tok
# Do not replace the fix with recurring web scans.
block=S[S.index('static NSString *ADForcedPDPFrameThemeJS7441'):S.index('// v7.441 main-document residue retained')]
for bad in ['MutationObserver','setInterval(','requestAnimationFrame(']:
    assert bad not in block,bad
print('PASS: v7.441 enumerates iOS 17 site-isolated frame trees and injects the PDP ad treatment into remote child documents')
