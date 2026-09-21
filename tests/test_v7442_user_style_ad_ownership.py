from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text()
assert 'Version: 7.443~user-style-ad-ownership-validation-fix' in C
assert '#define AD_VERSION "v7.443-user-style-ad-ownership-validation-fix"' in S
assert 'VER=7.443' in UI
assert 'AD_PROBE_VERSION=7.443' in SK and 'AD_PROBE_NAME=AmazonDark-v7.443' in SK
f=S[S.index('static const void *kADUserStyle7442'):S.index('// v7.388: WKUserScript')]
for tok in ['_WKUserStyleSheet','_addUserStyleSheet:','forWKWebView:forMainFrameOnly:includeMatchPatternStrings:excludeMatchPatternStrings:baseURL:level:contentWorld:','ADPDPAdUserCSS7442','ADUserStyleAttach7442','NO,nil,nil,nil,0,nil','background:#000!important','border-color:#494d4d!important','color:#e8e6e3!important','[class*=prime]','[class*=star]','[class*=rating]','-webkit-text-fill-color:currentColor!important','filter:brightness(%.3f)!important']:
    assert tok in f,tok
for bad in ['MutationObserver','setInterval(','requestAnimationFrame(',"addEventListener('scroll'",'_frames:','_frameTrees:','evaluateJavaScript:inFrame:']:
    assert bad not in f,bad
assert 'ADUserStyleAttach7442(ucc)' in S
assert 'ADFrameOwnerAttach7440(ucc)' not in S
assert 'ADForceChildFrameTheme7440(self)' not in S
print('PASS: v7.443 uses one user-level all-frame stylesheet and retires runtime frame walking')
