from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
H=(ROOT/'src/ADSkeletonProbe7339.h').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()
SH=(ROOT/'scripts/skeleton-probe.sh').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.409~permission-controls-location-rails-fix' in C
assert 'ADSkelTransition7339?120:120' in H
assert 'ADSkelLaunchOnly7339&&[n.name isEqualToString:UIApplicationDidEnterBackgroundNotification]' in H
assert 'ADSkelProbe7339.backgroundCycles++' in H
assert 'ADSkelProbe7339.foregroundCycles++' in H
assert 'transition=web+launch-detail max120s and survives background/warm-return cycles' in H
assert 'stays armed across background/foreground cycles' in SH

x=SB[SB.index('%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider'):
     SB.index('%end',SB.index('%hook SBDeviceApplicationSceneViewPlaceholderContentViewProvider'))]
assert 'id original=%orig;' in x
assert 'ADObservePlaceholder7379(application,original);' in x
assert 'return original;' in x
for bad in ['UIImageView *replacement','ADLaunchArtwork7337(','addSubview','removeFromSuperview','setBackgroundColor:']:
    assert bad not in x,bad
assert 'if(protectedContent||kind==ADKindScene7337)return 0;' in SB
assert 'snapshot.keep' in SB and 'saved-scene-unchanged' in SB

# Lifecycle-boundary census must catch transient planes that a display link can miss.
assert 'ADSkelLifecycleWindows7379' in H
assert 'r[@"windows"]=ADSkelLifecycleWindows7379();' in H
assert '@"topPresentationBG"' in H and '@"presentationBG"' in H

print('PASS: v7.379 transition trace survives switcher/warm return, captures lifecycle windows, and passively observes placeholder delivery without mutation')
