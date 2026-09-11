from pathlib import Path
import hashlib,re
ROOT=Path(__file__).resolve().parents[1]
t=(ROOT/'src/Tweak.xm').read_text(); ui=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text(); sb=(ROOT/'src/AmazonDarkSB.xm').read_text(); sh=(ROOT/'scripts/skeleton-probe.sh').read_text(); ctl=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.404~product-scroll-video-alexa-polish' in ctl
assert '#define AD_VERSION "v7.404-product-scroll-video-alexa-polish"' in t

def static_block(src,name):
    m=re.search(r'^static[^\n;{}]*\b'+re.escape(name)+r'\([^;{}]*\)\s*\{',src,re.M);assert m,name
    st=m.end()-1;d=0;ins=False;esc=False
    for i in range(st,len(src)):
        c=src[i]
        if ins:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c=='"':ins=False
        else:
            if c=='"':ins=True
            elif c=='{':d+=1
            elif c=='}':
                d-=1
                if d==0:return src[m.start():i+1]
    raise AssertionError(name)
# Critical visual payloads remain byte-identical to accepted v7.350 except the exact Cart text restoration below.
expected={
 'ADStandalonePaintJS7104':'fb6a4cf9057c2f5262d4f2cd2d9d161f5b82661229671be0040bdd4f2dedc3db',
 'ADNativeSplashLogo7350':'27f26ded352c76f6bb39c68bda07c086004ff950c0dfa667ad14166966e16448',
 'ADLayoutNativeSplashSeal7350':'24fa17d2501f723c9037d57269c6ca95200e206c4ca4b5ce31acbc90d0765d05',
}
for name,digest in expected.items(): assert hashlib.sha256(static_block(t,name).encode()).hexdigest()==digest,name

# ADFloorJS/ADTWBJS intentionally change in v7.352 for exact Search/product UI owners.
# The v7.351 active-Cart restoration remains present and broad swipe recoloring remains absent.
active_rule='#sc-page-container form#activeCartViewForm .sc-list-item .swipe-button.swipe-right-button,#sc-page-container form#activeCartViewForm .sc-list-item .swipe-button.swipe-right-button>div{color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;}'
assert t.count(active_rule)==1
assert '.swipe-button{color:#e8e6e3' not in t

# Accepted Cart and splash owners remain.
for token in ['#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important','ADBlackenLoadingGradient7348','AmazonDarkCartLoadingBar7345','AmazonDarkSplashSeal7350']:
    assert token in t,token
# Hot-path / simplification wins.
assert 'kADCNMRootGetter7351' in t and 'objc_getAssociatedObject(w,kADCNMRootGetter7351)' in t
cnm=static_block(t,'ADInCNMErrorView7301'); assert 'for(int d=0;n&&d<18' not in cnm and 'if(!root||root.window!=w' in cnm
u=t[t.index('%hook UIView'):t.index('%end',t.index('%hook UIView'))]
assert '||react||ADExactBackgroundOwner7226' in u
assert 'ADMenuLifecycleTrace7280' not in t and 'gADMenuLifecycleRing7280' not in t
assert 'ADThemeReactAttributedText7271' not in t and 'ADPersonOfflineFallbackButtonString7299' not in t and 'ADAlexaSuggestionPillLightString7288' not in t
assert 'ADProbePath7351' not in t and 'ADProbeAppend7351' not in t
assert ui.count('static NSString *ADUIProbePath7362')==1 and ui.count('static void ADUIAppend7362')==1
assert 'if(!ADLaunchProbeArmed7351())return;' in sb
assert 'AmazonDark-launch-probe.arm' in sh
assert 'prefs/Resources/icon@3x.png' in ctl
assert not (ROOT/'prefs/icon@3x.png').exists()
print('PASS: v7.354 retains v7.351 optimization architecture and unchanged critical non-Search payload hashes')
print('PASS: CNM hot path, UIView classification reuse, universal probe writer/path consolidation, dead Menu ring removal, probe-only SB logging present')
