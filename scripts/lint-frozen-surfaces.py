#!/usr/bin/env python3
"""Hard regression gate for user-confirmed-good Amazon Dark surfaces.

Alexa, Hamburger, and Shopping Cart were confirmed good and frozen before
v5.394.  The complete current Person-tab implementation, including the
Subscribe & Save overlay repair, was explicitly confirmed good on-device in
v5.394 and is frozen here from the exact v5.394 source.  Home video playback is
separately frozen from v5.391.  In v5.395 the user also explicitly confirmed that
Home carousel media WBT is complete and standalone Sponsored ads no longer have
a black structural rectangle; those exact repair paths and their selector/marker
population are frozen here as well.  Do not update expected hashes merely to make
a later build pass: changing a frozen surface requires explicit new device evidence.
"""
from pathlib import Path
import hashlib, re, sys

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "src/Tweak.xm")
src = SRC.read_text()

# Keep every user-facing build identifier on the same release. A stale runtime
# version makes a fresh device probe indistinguishable from an older install.
_control = Path("layout/DEBIAN/control").read_text()
_workflow = Path(".github/workflows/build.yml").read_text()
_version_ok = ('#define AD_VERSION "v5.465.0"' in src
               and "Version: 5.465.0" in _control
               and "AmazonDark-v5.465-drfetch-probe-rootless-deb" in _workflow)
print(("PASS" if _version_ok else "FAIL") + ": v5.465 runtime/package/artifact identifiers agree")
if not _version_ok:
    sys.exit(1)

EXPECTED = {'ADInTabBarChain': 'e2d7c32dfb1d326d0f95fc96a24cb7e8b787bb554e5abdd4a49ef87800e748c9', 'ADViewIsSelectedInBar': 'f278b2fa765e4dd5230976a7167d26dc0d057b75b0bdd8f6964959516cc90483', 'ADTintBarIcon': '0a780232e861f864d9356b790fcbceff71df3a20043a573ca94d48fd4973478b', 'ADMenuRoot382': '446620008b2fbfb5c1460951afd71c840ef55afcf8adba5d4cbf9c54ab615926', 'ADHamburgerScreenActive384': 'e4a16c7bdaea2c5e32977cd4672bca639da6e119e072714ba1ae6d16f65c03b3', 'ADMenuRole382': 'c857750b6fab58c86a2c0d3fce76bcce5b5464bb76ce06c11352600375ee85aa', 'ADIsHamburgerSurface380': 'ca773407fdd3a70b32965de2ad095cc4801fe9f40adfd634b46fdf68c530c91e', 'ADIsCategoryArtwork379': '169f817f64692a54f71b1e83ea88ee81da19581ce910524d6a78cfe808ebe0ec', 'ADRestoreCategoryArtwork379': '36b98bb888a5c758f519935830fd75c372c43e12994495e1d75ff13c05c043f0', 'ADInvertRNSVG': '96e465da0f838d56a25c391e1c39217358bab0836430b72d657717427302a67c', 'ADInvertRNSVGApply': '6156fd8770a02dcee9c70e3c8c226934457b3e03834f33c2907137dee0e07bc4', 'ADWTLocalSection365': 'a672b911237022ce15d41ab06a6439ba1429015670f27d02201561ea57614a33', 'ADWTCarouselSection384': '3cbf4ef20a2bea3f96d0e74099e940e05b1ad0a865c0cb20e576288258265610', 'ADWTProductPeers388': 'bb0f4f1e8be49de98907c7a23108beb224ff80bdcc0f9a46c67c29dacfa8573a', 'ADWTNativeContext': 'f6698e48714e080df541a10d59c160473d02587b02b359c20fd5deaf84e42fbe', 'ADApplyNativeWhiteTameView': '774f9eb053b4eb323227627d5c9f49d0a5ec5e83bf8375a143ba4e525f0ce47e', 'ADPrimeNativeWhiteTame363': '24f48855a2993024f9b5d2bafdc858c8ad84a0c04726e521054dce7cdbd7565f', 'RNSVGSvgView_hook': '173e758c09313fac2aa46b4261d853e1de7353e582cf32f2221f07ad409da423', 'RCTUIImageViewAnimated_layout': '297be4d952733561e5f40126b9f27f983c5e63102a8a645b3ebecd6f9c6c810e', 'function cartChrome379(){': '96b2fb5ec541165fffd65edf139b91748a406c6f72ba2076a09c8c58a64619f0', 'function cartChrome382(){': 'e6f6c8d03eb62bae3faaded467e047458cfc534b2e206886f84a8fb7fe467b73', 'cart_css_lines': '6cd55355c442d60de8d7066911af5c95292acd7f7d1f46ad1ab9513eb6ecf56a', 'ADWTStableContext365': '38d32592e93860a82bc287cae33c6fbe6854602d0679711750e7aa559207e403', 'ADWTInHighlightsCarousel368': '98ffff6fd3c813b378567658a22683bb0d043f0c24c1730a9a9c2ac13c90ecca', 'ADWTExploreTile363': 'ae23ebb9ac3c262a354b11369cd27c5ef3540acfb383a0c433108360cc559baf', 'ADInSubscribeSave394': '73f3b4085fdaadf05e13454af7d4de9ed1d52c426a6ee4ab0da8085c317cb69e', 'ADSubscribeOverlay394': '1286055dc3c45de0aadd4f576e071396d5e176d0789d291b7d6bc2592ed5993e', 'RCTUIImageViewAnimated_hook': 'bd7309e47a32637c51991282f350cc9d3c7ef36f7200c4153de859e4ec031297', 'ADWTImageLight363': 'aa16a9e2cb847d71ee0ab22cffe55c2fdc0f5f8fae2cfa6f4cb30283479156ce', 'ADWTViewText362': 'b79c303f183e9bc883aef0e1ffb5a806f482d22457c1de98b32c1e3bc5565112', 'ADWTBandWalk362': '99b3da87362da4519ff3aaa65c55ed60690989859f818549020bc6c448174e28', 'ADWTBandsForWindow362': '76e4e905ac0f282d7868d886b9374bd7f8f346b0b9b6e820b641dabd45e602df', 'ADWTRawImageLike364': '79b546199e323671b8eeccc332bc4145f234b4037ea1c0120d3aaec0320bd156', 'ADWTNoTameGlyph367': '9ab0438cb94030bf0bcb7b5ff9efaf4165e2429dbeb973ca5270761bf4a4e01d', 'ADWTInWatchedCarousel380': '550f84059b709e4b5e43c167ea40c9cb32d344008d70e4931c11da361b1f8b65'}

def sha(x): return hashlib.sha256(x.encode()).hexdigest()

def brace_block(start_pat, label):
    m = re.search(start_pat, src, re.M)
    if not m: raise RuntimeError(f"missing frozen block: {label}")
    start=m.start(); brace=src.find('{',m.end()-1)
    if brace < 0: raise RuntimeError(f"missing opening brace: {label}")
    d=0; i=brace; ins=None; esc=False; lc=False; bc=False
    while i < len(src):
        c=src[i]; n=src[i+1] if i+1<len(src) else ''
        if lc:
            if c=='\n': lc=False
        elif bc:
            if c=='*' and n=='/': bc=False; i+=1
        elif ins:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==ins: ins=None
        else:
            if c=='/' and n=='/': lc=True; i+=1
            elif c=='/' and n=='*': bc=True; i+=1
            elif c in ('"', "'"): ins=c
            elif c=='{': d+=1
            elif c=='}':
                d-=1
                if d==0: return src[start:i+1]
        i+=1
    raise RuntimeError(f"unclosed frozen block: {label}")

def hook_block(name):
    st=src.index('%hook '+name)
    en=src.index('%end',st)+len('%end')
    return src[st:en]

def method_in_hook(hookname, sig):
    hb=hook_block(hookname)
    m=re.search(re.escape(sig)+r'\s*\{',hb)
    if not m: raise RuntimeError(f"missing {hookname} {sig}")
    st=m.start(); br=hb.find('{',m.start()); d=0; i=br; ins=None; esc=False; lc=False; bc=False
    while i<len(hb):
        c=hb[i]; n=hb[i+1] if i+1<len(hb) else ''
        if lc:
            if c=='\n': lc=False
        elif bc:
            if c=='*' and n=='/': bc=False; i+=1
        elif ins:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==ins: ins=None
        else:
            if c=='/' and n=='/': lc=True; i+=1
            elif c=='/' and n=='*': bc=True; i+=1
            elif c in ('"', "'"): ins=c
            elif c=='{': d+=1
            elif c=='}':
                d-=1
                if d==0: return hb[st:i+1]
        i+=1
    raise RuntimeError(f"unclosed {hookname} {sig}")

items={}
for name in [
    'ADInTabBarChain','ADViewIsSelectedInBar','ADTintBarIcon',
    'ADMenuRoot382','ADHamburgerScreenActive384','ADMenuRole382',
    'ADIsHamburgerSurface380','ADIsCategoryArtwork379','ADRestoreCategoryArtwork379',
    'ADInvertRNSVG','ADInvertRNSVGApply',
    'ADWTLocalSection365','ADWTCarouselSection384','ADWTProductPeers388','ADWTNativeContext',
    'ADApplyNativeWhiteTameView','ADPrimeNativeWhiteTame363',
    'ADWTStableContext365','ADWTInHighlightsCarousel368','ADWTExploreTile363',
    'ADInSubscribeSave394','ADSubscribeOverlay394',
    'ADWTImageLight363','ADWTViewText362','ADWTBandWalk362','ADWTBandsForWindow362',
    'ADWTRawImageLike364','ADWTNoTameGlyph367','ADWTInWatchedCarousel380']:
    items[name]=brace_block(r'^static[^\n]*\b'+re.escape(name)+r'\s*\([^\n]*\)\s*\{',name)
items['RNSVGSvgView_hook']=hook_block('RNSVGSvgView')
items['RCTUIImageViewAnimated_hook']=hook_block('RCTUIImageViewAnimated')
items['RCTUIImageViewAnimated_layout']=method_in_hook('RCTUIImageViewAnimated','- (void)layoutSubviews')
# v5.450 adds only a bounded Compare reschedule side effect to this historically
# frozen WBT hook. Strip that exact clause before hashing so every old byte stays
# protected; the unstripped clauses are separately hash-locked in the v5.450 gate.
_rct_compare450_schedule = (
    "        if (ADRecolorOn() && vv.window &&\n"
    "            vv.bounds.size.width>=8 && vv.bounds.size.width<=30 &&\n"
    "            vv.bounds.size.height>=8 && vv.bounds.size.height<=30)\n"
    "            ADScheduleNativeCompare450();\n"
)
_rct_schedule_count = items['RCTUIImageViewAnimated_hook'].count(_rct_compare450_schedule)
print(('PASS' if _rct_schedule_count == 2 else 'FAIL')+
      f': exact v5.450 RCT Compare-only scheduling clauses count={_rct_schedule_count}')
bad = _rct_schedule_count != 2
items['RCTUIImageViewAnimated_hook'] = items['RCTUIImageViewAnimated_hook'].replace(_rct_compare450_schedule, '')
items['RCTUIImageViewAnimated_layout'] = items['RCTUIImageViewAnimated_layout'].replace(_rct_compare450_schedule, '')
for key in ['function cartChrome379(){','function cartChrome382(){']:
    lines=[ln for ln in src.splitlines() if key in ln]
    if len(lines)!=1: raise RuntimeError(f"{key}: expected one source line, got {len(lines)}")
    items[key]=lines[0]
items['cart_css_lines']='\n'.join(ln for ln in src.splitlines() if 'data-ad-cart' in ln)

for key, expected in EXPECTED.items():
    actual=sha(items[key])
    ok=actual==expected
    print(('PASS' if ok else 'FAIL')+f': frozen {key} {actual}')
    bad |= not ok

# Home carousel video playback was separately user-confirmed working in v5.391.
# v5.452 invokes no video writer. Its owner was inserted at the string-literal
# seam immediately after badgeFix, so normalize that one split seam before
# hashing while retaining every byte of the actual video definition/call clauses.
video=[]
for ln in src.splitlines():
    if '_adHomeVideo391' not in ln:
        continue
    if ln.lstrip().startswith('"homeAmbient386();'):
        ln=ln.replace('"homeAmbient386();', '"}catch(e){}}""homeAmbient386();', 1)
    video.append(ln)
vsha=sha('\n'.join(video))
vexp='7f6f56ed65addf48812d33e75cc7eae5b6e2eec268be6a4f7062334713e632cd'
vok=len(video)==5 and vsha==vexp
print(('PASS' if vok else 'FAIL')+f': frozen Home video lines={len(video)} sha={vsha}')
bad |= not vok

# v5.395 HOME FIXES — USER-CONFIRMED GOOD. These are stronger than a function
# hash alone: exact runtime definition/call lines are frozen, exact repair-marker
# populations are frozen, and no additional direct media/standalone selectors may
# be introduced outside the new v5.396 bleed-only first-paint guard/probe.
def agg_lines(pattern, exclude=None, haystack=None):
    rx=re.compile(pattern)
    ex=re.compile(exclude) if exclude else None
    text=src if haystack is None else haystack
    lines=[ln for ln in text.splitlines() if rx.search(ln) and not (ex and ex.search(ln))]
    return lines, sha('\n'.join(lines))

# v5.449's broad full-card image exception was disproved on-device: P93 showed
# four creatives with filter=none and the user saw the resulting WBT regression.
# v5.450 restores the byte-for-byte v5.395 writers.  Its separate saturated-
# background repair is excluded from the historical line census below.
_home395_src=src
for _retired in [
    "function homeCreative449", "homeCreative449Native",
    "setAttribute('data-ad-homecreative449','native-image')",
    "__AD_HOMEMEDIA449_WRAP__",
]:
    _ok=_retired not in src
    print(('PASS' if _ok else 'FAIL')+': retired v5.449 Home image exemption absent '+_retired)
    bad |= not _ok

HOME395 = {
    '_adHomeMedia395 exact definition/calls': (r'_adHomeMedia395', r'450', 4, '3e444e384aec697faa7de97f191f5614e2dda0683c8758a43e71b95e9b8846e2'),
    'Home media marker population': (r'data-ad-homemedia395|homeMedia395', r'450', 2, 'f7026a7152b61130636e321a3c2de4e21089e0ea866ef1d2041ebbdac3c5e1ae'),
    '_adStandaloneSweep395 exact definition/calls': (r'_adStandaloneSweep395', None, 4, '1e931418220ed80b4fd966a2280ed2231dd067c98541e7bbb54e78c5718d8681'),
    'Standalone repair marker population': (r'data-ad-homeauto395|data-ad-standparent395|data-ad-standbefore395|data-ad-standafter395', None, 4, '6d508367ffaf47dbc86910ebaa13cd2ff75d47825911d2d008715d2958e285d2'),
    'Standalone iframe selector population': (r'iframe\[data-ad-frame-mode362', None, 4, '2835e55cd74e8a785c76257a97e69d6dfc3e40c4da80eac18cd711609b0278cb'),
    # Exclude the v5.396 bleed guard/probe, v5.447/v5.448 diagnostics, and
    # v5.450's narrow background-only owner/probe, and v5.452's separately
    # locked non-video background capture/overlay.
    # Every older direct reference remains exactly the user-confirmed v5.395 set.
    'Home media direct-selector population': (r'single-creative-card|single-video-card|video\.vjs-tech|data-ad-homemedia395', r'data-ad-main396|P59BLEED396|P66BLEED401|data-ad-homecreative44[789]|homeCreative44[789]|P(?:89THEME447|91HOME448|94HOME450|95HOME452)|v5\.4(?:4[789]|50|52)|I44[89]|_single-creative-card image|direct 299x478|media are untouched|stale450|data-ad-homecolor452|HOMECOLOR452', 4, 'f1976ee3a8b48cb6e9278243e8af2064b01160fb8abd62731ccc90d59753b301'),
}
for label,(pattern,exclude,count,expected) in HOME395.items():
    lines,actual=agg_lines(pattern,exclude,_home395_src)
    ok=(len(lines)==count and actual==expected)
    print(('PASS' if ok else 'FAIL')+f': frozen {label} lines={len(lines)} sha={actual}')
    bad |= not ok

# Explicitly reject the known-bad standalone blend path and obvious attempts to
# remove/clear v5.395 ownership markers.  The v5.450 block may clear a stale
# v5.449 marker before immediately calling the canonical v5.395 retame; exclude
# that exact locked block and apply the historical ban everywhere else.
_h450_start = _home395_src.index('         // v5.450 HOME AUTHORED COLOR.')
_h450_end = _home395_src.index('         "function badgeFix(){try{"', _h450_start)
_legacy_without_h450 = _home395_src[:_h450_start] + _home395_src[_h450_end:]
for forbidden in [
    '__AD_STANDBLEND384__',
    "removeAttribute('data-ad-homemedia395')",
    'removeAttribute("data-ad-homemedia395")',
    "removeAttribute('data-ad-homeauto395')",
    'removeAttribute("data-ad-homeauto395")',
    "removeAttribute('data-ad-standparent395')",
    'removeAttribute("data-ad-standparent395")',
]:
    ok=forbidden not in _legacy_without_h450
    print(('PASS' if ok else 'FAIL')+f': forbidden competing writer absent: {forbidden}')
    bad |= not ok

if bad:
    print('ERROR: a user-confirmed-good frozen surface changed.')
    print('Do not update expected hashes merely to bypass this gate.')
    sys.exit(1)
print('PASS: Alexa, Hamburger, Cart, Person, Home video, v5.395 Home WBT, and v5.395 standalone-ad fixes are frozen unchanged.')

# v5.397 SYMBOL POLICY — v5.333 owns every non-checkbox symbol. v5.434 keeps
# the former Compare painters; this section now locks those functions as no-ops
# while continuing to freeze the surrounding Heart/cards/arrow authorities.
# This is intentionally checked after all older surface gates so a later developer
# cannot "fix" a symbol by reopening a confirmed Person/Home/Menu path.
print('--- v5.397 symbol authority / v5.434 retired-checkbox locks ---')

# v5.413: this lock was re-pointed ON PURPOSE. It previously froze a
# compareStock380 whose selector claimed [class*=mlt-icon-container].
# Device probe (P9SYM/KEBAB) proved mlt-icon-container is the TWO-CARDS
# control -- it holds mlt-image-icon/img.s-image and has no input,
# role=checkbox or a-icon-checkbox. The real Compare checkbox is
# div.a-checkbox > i.a-icon-checkbox. So this gate was freezing the wrong
# element; compare380 no longer selects the cards host.
# The two legacy checkbox state machines must remain exact no-ops.
for key, expected in {
    'function compareStock380(){':'9b4ac3304a8033a0e10fb359cdebb410e7a174f798ad4af3f27f0c99b688e720',
    'function legacyCompare387(){':'2c81ceb4ca1d41c49b5f52267b94dbe6d89009c862db3240e0407a92b566bea9',
}.items():
    lines=[ln for ln in src.splitlines() if key in ln and 'v5.397' not in ln]
    actual=sha(lines[0]) if len(lines)==1 else '-'
    ok=len(lines)==1 and actual==expected
    print(('PASS' if ok else 'FAIL')+f': retired checkbox painter {key} {actual}')
    bad |= not ok

# v5.408 deliberately reopens ONLY the cards branch inside the original v5.396
# product-control function. v5.434 keeps its checkbox branch disabled. Hash
# the complete resulting non-cards body so Heart and arrow cannot drift later.
plines=src.splitlines()
try:
    pst=next(i for i,l in enumerate(plines) if 'window.__AD_PRODUCTCTRL391RUN__=function' in l)
    pen=next(i for i in range(pst,len(plines)) if "window.__AD_PRODUCTCTRL391__='err '" in plines[i])
    praw=plines[pst:pen+1]
    pdisable=[l for l in praw if '__AD_CARDS391_DISABLED408__' in l]
    pkept=[l for l in praw if '__AD_CARDS391_DISABLED408__' not in l]
    pactual=sha('\n'.join(pkept)); pexpected='b10671956ece6028c199ab1262388f4386b64b4d89cf5ef6baf4a3ed6b164efb'
    ok=(pactual==pexpected and len(pdisable)==1 and 'var A=[]' in pdisable[0]
        and 'var C=[],seenC=[]' in '\n'.join(praw)
        and "skin(ch,'checkbox')" not in '\n'.join(praw))
except Exception:
    pactual='missing'; ok=False
print(('PASS' if ok else 'FAIL')+f': product-control Heart/arrow body frozen; cards and checkbox branches disabled {pactual}')
bad |= not ok

# Native symbol engine: these are exact v5.333 functions. ADLiftNativeGlyph has one
# later Menu-ownership preamble, so its body from kNatGlyphKey onward is hashed against
# the exact v5.333 body rather than deleting the confirmed-good Hamburger guard.
V333_FUNCS={
 'ADApplyBarTint':'134e6afa1ade4ee1091e1e127b4ec60246cfff31115b7dae7eca8095bdc4fbf2',
 'ADBarSelectionKnown':'69dc5322387bac6d1f12688457bc8c14523dc50ca1b88a79c0d0f8c99c99c10e',
 'ADImageIsTemplateish':'ee7b9093d12574573612fc977fd86a7aba5c4dcb9b6f05d4cbf010806cd2e9c1',
 'ADIsChromeGlyphContext':'44868bbc52e617190710a6dc1d49051833e18a08eaca80559a703138f4e519e0',
 'ADInvertRNSVG':'96e465da0f838d56a25c391e1c39217358bab0836430b72d657717427302a67c',
 'ADInvertRNSVGApply':'6156fd8770a02dcee9c70e3c8c226934457b3e03834f33c2907137dee0e07bc4',
 'ADScheduleGlyphLift':'6e2f938410ce61b577bd0c6201d2ede0cb7c5a5f3fc6d1931859a27a3f7641dc',
 'ADUntintColourImage':'8743cdcb89c4da4c8fe44e3d5e28e63bf1ef4d3a7b0b7975254c8aff97f7c1b6',
}
for name,expected in V333_FUNCS.items():
    actual=sha(brace_block(r'^static[^\n]*\b'+re.escape(name)+r'\s*\([^\n]*\)\s*\{',name))
    ok=actual==expected
    print(('PASS' if ok else 'FAIL')+f': exact v5.333 native symbol {name} {actual}')
    bad |= not ok
try:
    lift=brace_block(r'^static[^\n]*\bADLiftNativeGlyph\s*\([^\n]*\)\s*\{','ADLiftNativeGlyph')
    tail=lift[lift.index('        static const void *kNatGlyphKey'):]
    actual=sha(tail); expected='844ea8761e455e21d95420dda8e034919028fdb19df61d06f1bf22e4ca5ff30b'
    ok=actual==expected
except Exception:
    actual='missing';ok=False
print(('PASS' if ok else 'FAIL')+f': exact v5.333 ADLiftNativeGlyph body after protected Menu preamble {actual}')
bad |= not ok

# v5.333 web glyph passes remain byte-locked. Device evidence in v5.439 permits
# the one gfix1-window change: artChk now returns before any checkbox subtree;
# the historical writer itself and every non-checkbox path remain unchanged.
V333_WINDOWS={
 'gfix1':'97f183a362e1bfd121398de9b658f4ca5f3a9b573ef800a8a54250038fe9fa64',
 'gfix2':'e8c9531f44bcc1e204d766de29708876373d00c4da77420146497ddb688b470b',
 'logolift':'df95d7ce310b3ee802df7c9c6809e175a3cd1852d0810ff9faa56fd1045ee6e9',
 'tileart':'bdffdbf648176aa1767e18ef60c35f8b8afbaf25991f2ba9ce1a09cfb5390522',
 'fltpanel':'682d959f64db2a136d17f2952fd657fbd32f6ffa24c8171f313f7faafc9d5087',
 "__adBy='aic'":'69185123e83d7b2f10e486bff201bc81f552a2e17ea67d9952fe5ac490cbd42a',
 'gsweep':'0c9c8167510b176a07fcbefd62cde3723b26f0e9a1ab7ebb270ec2df0ac13e0c',
}
# The canonical historical windows themselves are retained verbatim in current source;
# locate a current marker and hash the same +/-250 chars.
for marker,expected in V333_WINDOWS.items():
    i=src.find(marker)
    actual=sha(src[max(0,i-250):i+250]) if i>=0 else 'missing'
    ok=actual==expected
    print(('PASS' if ok else 'FAIL')+f': exact v5.333 web symbol pass {marker} {actual}')
    bad |= not ok

# New final authority blocks. These are the only v5.397 additions allowed to arbitrate
# post-v5.333 symbol writers. Changing them requires explicit new device evidence.
try:
    ca=src.index('// v5.397: SYMBOL THEME AUTHORITY')
    cb=src.index('         "try{window.__AD_EARLY__',ca)
    css397=src[ca:cb]
    actual=sha(css397); expected='090688032a26580b55cd71464d1691740dc79d21827aa4b1d8eb81a7216ec176'
    ok=actual==expected
except Exception:
    actual='missing';ok=False
print(('PASS' if ok else 'FAIL')+f': v5.333 documentStart symbol authority {actual}')
bad |= not ok
try:
    ra=src.index('// v5.397: keep the current checkbox implementation')
    rb=src.index('         "window.__AMZDARK_APPLY__=function',ra)
    run397=src[ra:rb]
    # Cards host paint is now removed from this later authority; all other v5.397
    # reset/Heart/checkbox-exclusion/wrapper behavior must remain byte-identical.
    rlines=run397.splitlines()
    kept397=[l for l in rlines if 'v5.408: cards host paint is owned solely' not in l and 'var ndisc397=0,dskip397=0' not in l]
    actual=sha('\n'.join(kept397)); expected='17a42d6d47c501778b6542378b152485528f729a80361e45e4bec2678071c9d5'
    ok=(actual==expected and 'var DB397=document.querySelectorAll' not in run397 and 'var ndisc397=0,dskip397=0' in run397)
except Exception:
    actual='missing';ok=False
print(('PASS' if ok else 'FAIL')+f': v5.397 non-cards post-modern authority frozen {actual}')
bad |= not ok

# Checkbox exclusion is mandatory in both runtime and probe. No v333 authority write
# is allowed to originate from a Compare/MLT/checkbox node.
required=[
 '[class*=mlt-icon-container],[role=checkbox],input[type=checkbox],[class*=a-icon-checkbox],[data-ad-compare380],[data-ad-comparelegacy387]',
 'if(ischeck397(h397))continue', 'if(ischeck397(q397))continue', '__AD_CARDS391_DISABLED408__',
 'cbTouched=', 'v333397', 'P60SYMBOL397['
]
for token in required:
    ok=token in src
    print(('PASS' if ok else 'FAIL')+f': symbol/checkbox separation token {token[:70]}')
    bad |= not ok

if bad:
    print('ERROR: v5.397 symbol authority, current checkbox, or another frozen surface changed.')
    print('Do not update these hashes to bypass the gate; reopen only with explicit device evidence.')
    sys.exit(1)
# ---------------------------------------------------------------------------
# v5.424 REGRESSION LOCKS (requested after the oval/heart regressions).
# These encode two rules that cost many builds to rediscover:
#   A. NO class-wide CSS may put a round radius on a control class. Such a rule
#      also matches row-sized containers (e.g. puis-mab-container @168x263) and
#      turns a product photo into a giant oval. Discs must come from the
#      size-guarded painter, which can test dimensions; CSS cannot.
#   B. The heart/control size guard must stay intact: 18..52px on both axes AND
#      near-square. Removing it is what produced the oval and the 38x78 blob.
# ---------------------------------------------------------------------------
_CTRL_CLASSES = ('mlt-icon-container', 'puis-mab-chevron',
                 'lists-framework-action-button', 'a-checkbox')
_oval_offenders = []
for _ln in src.splitlines():
    if 'border-radius' not in _ln:
        continue
    if '50%' not in _ln and '50%%' not in _ln:
        continue
    if 'setProperty' in _ln or 'data-ad-' in _ln:
        continue          # painter code / attribute-keyed rules are fine
    if any(('[class*=' + _c) in _ln for _c in _CTRL_CLASSES):
        _oval_offenders.append(_ln.strip()[:110])
print(('PASS' if not _oval_offenders else 'FAIL') +
      ': LOCK A no class-wide round radius on control classes')
if _oval_offenders:
    for _o in _oval_offenders:
        print('   offender: ' + _o)
    print('ERROR: a class-wide radius rule on a control class turns product photos into ovals.')
    sys.exit(1)

_guard_ok = ("drx.width<18||drx.width>52||drx.height<18||drx.height>52" in src
             and "Math.abs(drx.width-drx.height)>10" in src)
print(('PASS' if _guard_ok else 'FAIL') + ': LOCK B control painter size guard intact')
if not _guard_ok:
    print('ERROR: the 18-52px / near-square guard is missing; oversized hosts would be painted.')
    sys.exit(1)

_chev_ok = ("[class*=puis-mab-chevron]" in src and "/glyph/.test(dcx)" in src)
print(('PASS' if _chev_ok else 'FAIL') + ': LOCK C chevron in painter set and glyph-excluded')
if not _chev_ok:
    print('ERROR: chevron dropped from the painter selector set, or the glyph exclusion was removed.')
    sys.exit(1)

# ---- LOCK D (v5.429): CARDS control is solved. Two invariants:
#      (1) the cards glyph whitening rule must exist (colour only), else the
#          two-cards logo renders black (v5.423 regression);
#      (2) an element that merely CONTAINS another control must not be treated
#          as the checkbox, else a bezel is drawn around the cards icon
#          (label.a-checkbox wrapper, v5.424 regression).
_cards_glyph = ("[class*=mlt-icon-container] img[class*=s-image]" in src
                and "brightness(0) invert(1)" in src)
_wrapper_skip = "mlt-icon-'+'container],[class*=lists-framework-action-'+'button]')" in src
print(('PASS' if _cards_glyph else 'FAIL') + ': LOCK D1 cards glyph whitening rule present')
print(('PASS' if _wrapper_skip else 'FAIL') + ': LOCK D2 control-wrapper skip present')
if not (_cards_glyph and _wrapper_skip):
    print('ERROR: cards control regression (black glyph, or bezel drawn around the cards icon).')
    sys.exit(1)

# ---- LOCK E (v5.441): CHECKBOX keeps Amazon's stock sprite/state. Every shared historical control
# painter must skip it. JavaScript may discover/clean the native host and art,
# but checked state must come from live input/ARIA/class CSS -- never a delayed
# JavaScript checked/unchecked marker. This is what prevents the blue sprite
# from being inverted orange between Amazon's update and a repaint timer.
_cb_skips = all(token in src for token in [
    "if(sq){dskip++;continue;}",
    "if(k==='checkbox'){sk++;continue;}",
    "if(sqx){ds++;continue;}",
])
# v5.442: the pinned unchecked-art rule changed 50% -> 4px ON PURPOSE. The
# Compare checkbox now renders as a SQUARE in Shopping and Cart (it shares
# this one rule), matching the slight corner rounding of Amazon's own checked
# blue sprite. Only the radius moved: fill, chrome ring, sizing and the
# checked stock-sprite passthrough are byte-identical.
_cb_native = all(token in src for token in [
    "input[type=checkbox],[role=checkbox],[aria-checked]",
    "function art434(h,seed)",
    # v5.443: marker bumped 441 -> 443 ON PURPOSE. The sheet is only replaced when
    # this value changes; v5.442 edited the CSS but left the marker, so live
    # documents kept the old circular rule and the square never shipped.
    "s434.setAttribute('data-ad-native-state','446')",
    ':has(input[type=checkbox]:checked',
    '[aria-pressed=true]',
    r'[data-ad-checkbox434-art]{filter:none !important;border-radius:4px !important;box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important;transition:none !important;}',
    r'[data-ad-checkbox434-shell=\"cart\"]{background-color:transparent !important;',
    "[class*=copilot-compare],button[aria-label*=ompare]",
    "h.setAttribute('data-ad-checkbox434-host','stock')",
    "aa.setAttribute('data-ad-checkbox434-art','stock')",
    "function queue434(ms434){clearTimeout(window.__AD_CHECKBOX434_T__)",
    "new MutationObserver(function(){queue434(24);}",
    "attributeFilter:['class','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']",
    "function generic434(e)",
    "e.style.removeProperty('filter')",
])
try:
    _fa=src.index('static NSString *ADFixesLiteral')
    _fb=src.index('static NSString *ADThemeLiteral', _fa)
    _fixes=src[_fa:_fb]
except ValueError:
    _fixes=''
_old_css=[
    '[data-ad-comparehost377]{', '[data-ad-comparebox377]{',
    '[data-ad-compare378=', '[data-ad-compare379]{',
    '[data-ad-compare380]{', '[data-ad-comparelegacy387]{',
    '[data-ad-product391=\"checkbox\"]::',
    '[data-ad-sym413=\"checkbox\"]',
]
_cb_old_css = all(token not in _fixes for token in _old_css)
_fixes_split = _fixes.find("\"',invert:")
_fixes_presentation = _fixes[:_fixes_split] if _fixes_split >= 0 else _fixes
_fixes_config = _fixes[_fixes_split:] if _fixes_split >= 0 else ''
_shopping_white_selectors = [
    '[class*=copilot-compare][class*=on-image-button]',
    '[class*=copilot-compare] [class*=on-image-button]',
    '[class*=s-product-image] button[aria-label*=ompare]',
    '[class*=puisg-col] [role=button][aria-label*=ompare]',
    '[class*=s-product-image] [data-csa-c-content-id*=ompare]',
    '[class*=puisg-col] [data-csa-c-content-id*=ompare]',
]
_shopping_white_absent = all(token not in _fixes_presentation for token in _shopping_white_selectors)
_amazon_inline_safe = ('[class*=copilot-compare]' in _fixes_config
                       and "[class*=a-check'+'box]" in _fixes_config
                       and "closest('[class*=a-checkbox],[class*=a-icon-checkbox],input[type=checkbox],[role=checkbox],[class*=copilot-compare],button[aria-label*=ompare],[data-csa-c-content-id*=ompare]')" in src)
_cb_no_emulation = ("setAttribute('data-ad-compare380'" not in src
                    and '__adManual380=' not in src
                    and "on?'checked':'unchecked'" not in src
                    and r'[data-ad-checkbox434-art=\"unchecked\"]' not in src
                    and r'[data-ad-checkbox434-art=\"checked\"]' not in src)
print(('PASS' if _cb_skips else 'FAIL') + ': LOCK E1 all shared painters skip checkbox')
print(('PASS' if _cb_native else 'FAIL') + ': LOCK E2 native-state 32px unchecked chrome / checked stock-blue sprite contract')
print(('PASS' if _cb_old_css else 'FAIL') + ': LOCK E3 retired checkbox CSS absent at documentStart')
print(('PASS' if _cb_no_emulation else 'FAIL') + ': LOCK E4 no timer/manual checkbox-state emulation')
print(('PASS' if _shopping_white_absent else 'FAIL') + ': LOCK E5 no Shopping white-silhouette selector can outrank stock state')
print(('PASS' if _amazon_inline_safe else 'FAIL') + ': LOCK E6 Amazon Compare/checkbox artwork is excluded from broad writers')
if not (_cb_skips and _cb_native and _cb_old_css and _cb_no_emulation
        and _shopping_white_absent and _amazon_inline_safe):
    print('ERROR: stock checkbox isolation regressed.')
    sys.exit(1)

# ---- LOCK F (v5.437): <video> must never receive the image-taming CSS filter.
#      A filter on a <video> pushes WebKit off the accelerated path: the frame
#      renders black/absent while audio keeps playing. Device evidence was
#      "VIDEO._c2Itd_video@422x237|f=brightness(0.5) saturate(1". Every site that
#      applies the taming brightness filter must be guarded by a VIDEO tag test.
import re as _re437
_tame_sites = _re437.findall(r"(\w+)\.style\.setProperty\('filter','brightness\('\+bb\+'\) saturate\(1\.08\)','important'\);", src)
_guarded = src.count("tagName||'').toUpperCase()!=='VIDEO'")
_video_ok = bool(_tame_sites) and _guarded >= len(_tame_sites)
print(('PASS' if _video_ok else 'FAIL') +
      f': LOCK F video exempt from taming filter ({_guarded}/{len(_tame_sites)} sites guarded)')
if not _video_ok:
    print('ERROR: a taming filter site lost its VIDEO guard; video will render black with audio only.')
    sys.exit(1)

print('PASS: v5.333 owns non-checkbox symbols; v5.441 gives Cart and Shopping one native-state stock checkbox owner.')
# v5.403 USER-REOPENED SYMBOL / COLLEGE AUTHORITY. v5.441 keeps only the
# non-checkbox attribution portion; the former stock403 checkbox painter is retired.
print('--- v5.403 v5.333-three attribution + retired stock403 + College authority ---')
required403=[
    'window.__AD_STOCKCAP403__=function',
    'window.__AD_STOCKFIN403__=function',
    'window.__AD_PRODUCTCTRL391_BASE403__',
    "checkbox=retired433",
    'data-ad-v333403',
    'window.__AD_COLLEGEBG403__=function',
    "c403.id='adcollege403'",
    "b401.id='adbleed401'",
    'P69V333403[', 'P70COLLEGE403[', 'P66BLEED401[', 'P67PAGE401['
]
for token in required403:
    ok=token in src
    print(('PASS' if ok else 'FAIL')+f': v5.403 token {token}')
    bad |= not ok
for retired in ['__AD_STOCKCAP402__','__AD_STOCKFIN402__','data-ad-stock402','adstock402','P68STOCK402[',
                '__AD_STOCKCTRL399__','__AD_BLEED399__',"id='adcontrol398'","id='adbleed398'",
                '__AD_STOCKCAP401__','__AD_STOCKFIN401__','data-ad-stock401','adstock401']:
    ok=retired not in src
    print(('PASS' if ok else 'FAIL')+f': retired competing layer absent {retired}')
    bad |= not ok
# Heart/cards/arrow may be passively labelled for diagnostics. Checkbox must not
# enter stock403 at all; stockCheckbox434 is its only owner.
for tok in ["t==='heart'", "t==='cards'", "t==='arrow'", "else continue;h.setAttribute('data-ad-v333403',k)"]:
    ok=tok in src
    print(('PASS' if ok else 'FAIL')+f': v5.333-three / checkbox-isolation token {tok}')
    bad |= not ok
for forbidden in ["data-ad-stock403','h'", "data-ad-stock403','d'", "data-ad-stock403','a'", 'data-ad-stock403=h', 'data-ad-stock403=d', 'data-ad-stock403=a']:
    ok=forbidden not in src
    print(('PASS' if ok else 'FAIL')+f': non-checkbox stock override absent {forbidden}')
    bad |= not ok
for forbidden in ["h.setAttribute('data-ad-stock403'", "s403.id='adstock403'", "document.createElement('style');s403"]:
    ok=forbidden not in src
    print(('PASS' if ok else 'FAIL')+f': retired checkbox stock painter absent {forbidden}')
    bad |= not ok
# College normalization is allowed to change only background-color on the already-located
# College section and geometry-qualified full-size structural backdrop(s).
try:
    ca=src.index('// v5.403: College pane backdrop normalization')
    cb=src.index('         "try{if(window.__AD_PRODUCTCTRL391RUN__)',ca)
    college403=src[ca:cb]
except ValueError:
    college403=''
for tok in ["[data-ad-college-section=\\\"1\\\"]", "setProperty('background-color',bg,'important')", "r.width<sr.width*.88", "r.height<sr.height*.42"]:
    ok=tok in college403
    print(('PASS' if ok else 'FAIL')+f': College scoped backdrop token {tok}')
    bad |= not ok
for forbidden in ['filter','mix-blend-mode','opacity','color\'','-webkit-text-fill-color','width\'','height\'','position\'','transform']:
    # function comments can mention filter; enforce against actual style writes instead.
    if forbidden=='filter':
        ok="setProperty('filter'" not in college403
    elif forbidden=='mix-blend-mode':
        ok="setProperty('mix-blend-mode'" not in college403
    elif forbidden=='opacity':
        ok="setProperty('opacity'" not in college403
    elif forbidden=="color\\'":
        ok="setProperty('color'" not in college403
    elif forbidden=='-webkit-text-fill-color':
        ok="setProperty('-webkit-text-fill-color'" not in college403
    elif forbidden=="width\\'":
        ok="setProperty('width'" not in college403
    elif forbidden=="height\\'":
        ok="setProperty('height'" not in college403
    elif forbidden=="position\\'":
        ok="setProperty('position'" not in college403
    else:
        ok="setProperty('transform'" not in college403
    print(('PASS' if ok else 'FAIL')+f': College does not write {forbidden}')
    bad |= not ok
try:
    a=src.index('// v5.401 Home bleed experiment')
    b=src.index('// v5.403: College pane backdrop normalization',a)
    bleed401=src[a:b]
except ValueError:
    bleed401=''
for bad401 in ['contain:paint','overflow:hidden','isolation:isolate','MutationObserver','background:#181a1b','background-color:#181a1b','mix-blend-mode']:
    ok=bad401 not in bleed401
    print(('PASS' if ok else 'FAIL')+f': narrow bleed avoids {bad401}')
    bad |= not ok
if bad:
    print('ERROR: v5.403 reopened surface contract failed.')
    sys.exit(1)
print('PASS: Heart/cards/arrow remain under exact v5.333 authority; stock403 is retired; College backdrop matches app background.')


# v5.408 USER-CONFIRMED CONTROL LOCKS + LITERAL HISTORICAL CARDS RESTORE
print('--- v5.408 frozen Heart/down-arrow; literal historical cards restore ---')
# Heart and down-arrow remain byte-locked to the exact v5.404 source the user confirmed.
try:
    _f=src.index('window.__AD_V333FIX404__=function()')
    _h1=src.index("var HR=document.querySelectorAll('[class*=puis-heart-position]')",_f)
    _h2=src.index("var E=document.querySelectorAll('[class*=a-icon-dropdown]",_h1)
    _heart=src[_h1:_h2]
    _a1=_h2
    _a2=src.index('window.__AD_V333FIX404_STATE__=',_a1)
    _arrow=src[_a1:_a2]
    _css=next(ln for ln in src.splitlines() if "s404.id='adv333404'" in ln)
except Exception:
    _heart=_arrow=_css=''
for _label,_body,_exp in [
    ('Heart v5.404 visual owner',_heart,'77234f4f4225d8c258912fdfc2d8fdc51bed42bdbd6aa534142e888e749dca2a'),
    ('Down-arrow v5.404 visual owner',_arrow,'e9fcfaa77c5d89efd57e50e8deae2cfe948e6bf8b09524e047a63ed745e276e8'),
    ('Shared v5.404 Heart/arrow paint CSS',_css,'78746c344543fcf869e3a58f6d174f17f05817c7776f525228fead5e601e058e'),
]:
    _act=sha(_body); _ok=(_act==_exp)
    print(('PASS' if _ok else 'FAIL')+f': frozen {_label} {_act}')
    if not _ok: sys.exit(1)

# This is no longer an emulation. The exact historical ACTION-BUTTON DISC source
# block is copied byte-for-byte from the archived good source into clr().
try:
    _aa=src.index('                      // ACTION-BUTTON DISC.')
    _ab=src.index('                      // DARK ART ON A DARK TILE.',_aa)
    _action=src[_aa:_ab]
except Exception:
    _action=''
_action_sha=sha(_action)
_ok=_action_sha=='5392ba801d65073e24b86c0e31d84b709cd649eb004263e42c43c0fc2ab222ca'
print(('PASS' if _ok else 'FAIL')+f': literal historical ACTION-BUTTON DISC block {_action_sha}')
if not _ok: sys.exit(1)

# Historical stock-glyph CSS stays exact.
_css_glyph=next((ln for ln in src.splitlines() if '[class*=lists-framework-action-button] img,[class*=lists-framework-action-button] i,[class*=lists-framework-action-button] svg,[class*=lists-framework-unfill]' in ln), '')
_css_ink=next((ln for ln in src.splitlines() if '[class*=lists-framework-action-button],[class*=lists-framework-action-button] *{color:#ffffff' in ln), '')
for _label,_body,_exp in [
    ('v5.333 stock cards raster inversion CSS',_css_glyph,'80acde30621c482c93dc9178f81b73d2addc947a3e9962c3d3a4fa9da7c2910c'),
    ('v5.333 stock cards vector/ink CSS',_css_ink,'75f65ce172f9bce431debcf4eaa7070ac0a43559c4c6e0308f17ec4c6f042618'),
]:
    _act=sha(_body); _ok=(_act==_exp)
    print(('PASS' if _ok else 'FAIL')+f': {_label} {_act}')
    if not _ok: sys.exit(1)

# The unsafe v5.391 cards picker stays disabled. v5.410 is the sole current-DOM
# cards owner. It may create ONLY a backdrop span behind the stock Amazon glyph;
# it must never synthesize/redraw the cards glyph itself.
for _need in ['__AD_CARDS391_DISABLED408__=1;var A=[]','window.__AD_CARDS410__=function()','data-ad-cards410-disc','data-ad-cards410-glyph','P79CARDS410[','Version: 5.465.0']:
    _hay=src if not _need.startswith('Version:') else Path('layout/DEBIAN/control').read_text()
    _ok=_need in _hay
    print(('PASS' if _ok else 'FAIL')+f': v5.410 token {_need}')
    if not _ok: sys.exit(1)

for _forbid in [
    '__AD_CARDS406__','adcards406','data-ad-cards406','P75CARDS406[','P76CARDS407[','P77CARDS408[',
    "if(own(dbe,'d'))", "setAttribute('data-ad-v333404','d')",
    "setAttribute('data-ad-cards405'", "setAttribute('data-ad-cards406'",
    'data-ad-stockdisc388','data-ad-stockdisc384',
]:
    if _forbid in ('data-ad-stockdisc388','data-ad-stockdisc384'):
        _a=src.index('window.__AD_CARDS410__=function()')
        _b=src.index('window.__AD_CARDS410_STATE__=',_a)
        _ok=_forbid not in src[_a:_b]
    else:
        _ok=_forbid not in src
    print(('PASS' if _ok else 'FAIL')+f': failed cards owner absent {_forbid}')
    if not _ok: sys.exit(1)

_a=src.index('window.__AD_CARDS410__=function()')
_b=src.index('window.__AD_CARDS410_STATE__=',_a)
_cards410=src[_a:_b]
for _need in [
    '[class*=lists-framework-action-button]',
    '[class*=mlt-icon-container]',
    '[role=checkbox]',
    'input[type=checkbox]',
    "d.setAttribute('data-ad-cards410-disc','1')",
    "g.setAttribute('data-ad-cards410-glyph','1')",
    "h.setAttribute('data-ad-cards410-host','1')",
    "h.style.setProperty('background-color','#181a1b','important')",
    "h.style.setProperty('border','1.5px solid rgba(255,255,255,.65)','important')",
    'if(ovxy(gx,gy)||ovr(best))',
    'if(bs>=80){suppress(best);hidden++;}',
    'function squareHost(root,g){var p=g&&g.parentElement',
    "g.style.setProperty('filter','brightness(0) invert(1)','important')",
    "g.style.setProperty('fill','#fff','important')",
    "g.style.setProperty('background-color','#fff','important')",
    "querySelectorAll('[data-ad-cards410-disc],[data-ad-cards410-host],[data-ad-cards410-glyph]')",
]:
    _ok=_need in _cards410
    print(('PASS' if _ok else 'FAIL')+f': v5.410 cards contract {_need}')
    if not _ok: sys.exit(1)

# v5.410 on-device repair: the glyph leaf must never become its own backdrop
# host, raster/vector/mask paint must be forced inline-important, and the 36px
# fallback disc must render above merchandise media but below the stock glyph.
for _need in [
    "function squareHost(root,g){var p=g&&g.parentElement",
    "g.style.setProperty('filter','brightness(0) invert(1)','important')",
    "g.style.setProperty('color','#fff','important')",
    "g.style.setProperty('fill','#fff','important')",
    "g.style.setProperty('stroke','#fff','important')",
    'pointer-events:none !important;z-index:1 !important;',
]:
    _ok=_need in src
    print(('PASS' if _ok else 'FAIL')+f': v5.410 visible cards repair {_need}')
    if not _ok: sys.exit(1)
_ok='function squareHost(root,g){var p=g,b=null' not in src
print(('PASS' if _ok else 'FAIL')+': v5.410 glyph leaf cannot be circular host')
if not _ok: sys.exit(1)

# Backdrop-only synthesis is allowed, glyph synthesis is not. There must be one
# createElement('span') and no SVG/path/canvas/image generation or innerHTML.
_ok=_cards410.count("document.createElement('span')")==1
print(('PASS' if _ok else 'FAIL')+f': v5.410 exactly one backdrop span factory')
if not _ok: sys.exit(1)
for _bad in ["createElement('svg')","createElementNS(","createElement('path')","createElement('img')",'innerHTML=', 'outerHTML=', "setProperty('transform'", "setProperty('width'", "setProperty('height'"]:
    _ok=_bad not in _cards410
    print(('PASS' if _ok else 'FAIL')+f': v5.410 no glyph/layout synthesis {_bad}')
    if not _ok: sys.exit(1)

print("PASS: Heart and down-arrow are frozen; v5.410 keeps Amazon's stock cards glyph/geometry, forces it white, and cannot enter Compare.")

# v5.440 CONTROL ISOLATION LOCKS
# The historical cards410 and Heart owners remain byte-exact. Device captures
# reopened only sym413 and repaint425: sym413 now preserves Amazon visibility and
# owns live MLT paint, while repaint425 is forbidden from touching MLT at all.
print('--- v5.440 cards/checkbox mutual exclusion and frozen Heart controls ---')

def exact_between(a, b, label):
    try:
        x=src.index(a); y=src.index(b,x)
        return src[x:y]
    except ValueError:
        print('FAIL: missing exact block '+label)
        sys.exit(1)

def exact_line(token, label):
    lines=[ln for ln in src.splitlines() if token in ln]
    if len(lines)!=1:
        print(f'FAIL: {label} expected one source line, found {len(lines)}')
        sys.exit(1)
    return lines[0]

_exact434_controls={
    'solved two-cards engine': (
        exact_between('window.__AD_CARDS410__=function()',
                      'window.__AD_CARDS410_STATE__=', 'cards410'),
        '9f37d09281bdadd06335cf47215037775c67cf9ca5ccec947b6bf60edb57878f'),
    'bootstrap control painter with checkbox skip': (
        exact_between('                      "function disc419(){try{',
                      '           "try{var _pv419=', 'disc419'),
        'dd20f14bb46efaaf74a74708023dc58921966223597d1e1e3b20cfc294ef710e'),
    'visibility-aware cards/checkbox control painter': (
        exact_between('         "function sym413(){try{',
                      '         "try{window.__AD_SYM413_PRE__=', 'sym413'),
        '45528bb6943319a89c3c30b7fc30223bfddd1307b23255b1530d9738a9df47e4'),
# v5.443: re-pointed DELIBERATELY. Only additions are read-only probe fields
# (r=/tag=/sheet=) inside the painter's capture block, so a future report can
# show whether the checkbox rule actually reached the element. No painting
# behaviour changed; LOCK E1-E6 still pass.
# v5.444: re-pointed DELIBERATELY -- the probe payload is now version-stamped so a
# stale localStorage entry cannot masquerade as fresh data. Read-only change; no
# painting behaviour altered (LOCK E1-E6 still pass).
# v5.446: re-pointed DELIBERATELY -- only the read-only payload stamp advances,
# preventing v5.444/v5.445 cached captures from being reported as v5.446 data.
# v5.447: re-pointed DELIBERATELY -- only the read-only payload stamp advances
# again, so this release cannot export a cached capture labeled as v5.446.
    'persistent non-MLT control painter': (
        exact_between('       "function repaint425(){',
                      '       "try{repaint425();', 'repaint425'),
        '96ef96efa28b731ab01e26693fcca6810def1a97af97df2e9b26cd766b53b2fb'),
    'Heart shell engine': (
        exact_between('         // v5.427 HEART SHELL:',
                      '         // v5.401 Home bleed experiment:', 'heart427'),
        '839a289b242dd33365b532e21c900708c2903b494c7594dfcd29080fd15d353b'),
    'Heart shell finalizer': (
        exact_between('         "try{window.__AD_PRODUCTCTRL391_PRE427__=',
                      '         // v5.407 historical note:', 'heart427-finalizer'),
        '4dd412a76cebb129ff9d554bbe1b8ad2d6c424eee9331f60720e941c800e6139'),
    'Heart shell device probe': (
        exact_between('       // P82HEART427:',
                      '       // P85CHECKBOX441:', 'P82HEART427'),
        'faa67839353326f4a21788c5a26ec17f2f99cfbd51118312f6aba4f4f7b3e246'),
}
for _label,(_body,_expected) in _exact434_controls.items():
    _actual=sha(_body); _ok=_actual==_expected
    print(('PASS' if _ok else 'FAIL')+f': exact {_label} {_actual}')
    if not _ok:
        print('ERROR: a solved icon owner, Heart owner, or checkbox exclusion changed.')
        sys.exit(1)

_sym440=_exact434_controls['visibility-aware cards/checkbox control painter'][0]
_repaint440=_exact434_controls['persistent non-MLT control painter'][0]
try:
    _cards440=_sym440[_sym440.index('"function cards(e){'):
                      _sym440.index('"var Q=document.querySelectorAll', _sym440.index('"function cards(e){'))]
except ValueError:
    _cards440=''
_cards440_required=all(token in _sym440 for token in [
    'function checkboxAt(e)', 'function shown(e,stop)', 'function clearCards(e)',
    'function glyph440(g)', 'data-ad-cards440-host', 'data-ad-cards440-glyph',
    'data-ad-cards440-suppressed', "if(!glyph440(g)||!shown(g,e))continue",
    "if(checkboxAt(e)){clearCards(e)",
    "if(k==='cards'){if(cards(e))n++;else sk++;continue;}",
])
_cards440_visibility=(_cards440 and "setProperty('visibility','visible'" not in _cards440
                      and "setProperty('opacity','1'" not in _cards440
                      and "setProperty('visibility','hidden','important')" in _cards440
                      and "setProperty('opacity','0','important')" in _cards440)
_cards440_single_owner=('mlt-icon-container' not in _repaint440)
print(('PASS' if _cards440_required else 'FAIL')+': v5.440 cards owner detects live checkbox collisions')
print(('PASS' if _cards440_visibility else 'FAIL')+': v5.440 cards owner never forces hidden artwork visible')
print(('PASS' if _cards440_single_owner else 'FAIL')+': v5.440 persistent painter cannot repaint MLT cards')
if not (_cards440_required and _cards440_visibility and _cards440_single_owner):
    print('ERROR: cards can again spill into the checkbox or acquire a second painter.')
    sys.exit(1)

for _required in [
    "if(hs&&!rc&&!/mlt-icon-container/.test(dc))",
    "if(hs&&!rc&&k!=='cards')",
    "if(hsx&&!rcx&&!/mlt-icon/.test(dcx))",
    "if(sq){dskip++;continue;}",
    "if(k==='checkbox'){sk++;continue;}",
    "if(sqx){ds++;continue;}",
]:
    _ok=_required in src
    print(('PASS' if _ok else 'FAIL')+f': shared painter isolation {_required}')
    if not _ok: sys.exit(1)

_heart427=_exact434_controls['Heart shell engine'][0]
for _forbidden in ["setProperty('width'","setProperty('height'","setProperty('position'",
                   "setProperty('transform'"]:
    _ok=_forbidden not in _heart427
    print(('PASS' if _ok else 'FAIL')+f': Heart shell cannot mutate layout {_forbidden}')
    if not _ok: sys.exit(1)
for _required in [
    "function real427(e){return !!(e&&e.querySelector&&e.querySelector('input[type=checkbox],[class*=a-icon-checkbox]'));}",
    "function card427(e){var c=String(e&&e.className||'');return /mlt-icon-container/.test(c)||e.getAttribute('data-ad-sym413')==='cards';}",
    "function inner427(e){return !!(e&&(e.hasAttribute('data-ad-cards410-host')||e.hasAttribute('data-ad-cards410-root')||e.hasAttribute('data-ad-cards410-disc')));}",
    "if(real427(p)||card427(p))break;if(inner427(p)){p=p.parentElement;continue;}",
    "document.querySelectorAll('[class*=lists-framework-action-button],[class*=puis-heart-position]')",
    "e.setAttribute('data-ad-heart-shell427','1')",
    "e.style.setProperty('background-color','transparent','important')",
    "e.style.setProperty('border','0','important')",
]:
    _ok=_required in _heart427
    print(('PASS' if _ok else 'FAIL')+f': Heart shell scope/neutralization {_required[:72]}')
    if not _ok: sys.exit(1)

# The legacy expanded-control chevron rules are the only broad `.a-icon`
# authority that could otherwise overlap an Amazon checkbox when its input is a
# sibling rather than an ancestor.  Freeze both narrow exclusions byte-for-byte:
# every non-checkbox chevron keeps the existing behavior, while a-checkbox art
# can reach only stockCheckbox434 below.
for _label,_token,_expected in [
    ('document-start expanded-icon checkbox exclusion',
     "__acs.textContent=__acs.textContent.replace('[aria-expanded] .a-icon{'",
     '4e1b2d40492e69c2d94208d856927dfc45db4e0841f11bbb05877d951c4f30df'),
    ('runtime chevron checkbox exclusion',
     'function chevronFix383(){',
     '7fbc8d4216bd5f57c2d1365ea2c4e65708c7d25f0694613bf26e2cb7c7132628'),
]:
    _line=exact_line(_token,_label); _actual=sha(_line)
    _ok=_actual==_expected
    print(('PASS' if _ok else 'FAIL')+f': exact {_label} {_actual}')
    if not _ok: sys.exit(1)
for _required in [
    "__acs.textContent.replace('[aria-expanded] .a-icon{','[aria-expanded] .a-icon:not(.a-icon-checkbox){')",
    "input[type=checkbox],[class*=a-icon-checkbox]'));}function mark(e)",
]:
    _ok=_required in src
    print(('PASS' if _ok else 'FAIL')+f': broad icon painter cannot enter checkbox {_required[:76]}')
    if not _ok: sys.exit(1)

print('PASS: cards and checkbox are mutually exclusive; Heart stays exact; shared painters skip real checkboxes.')
# v5.441 DEVICE-CAPTURED STOCK CHECKBOX CONTRACT
# Amazon owns state, geometry, the hit target, and the selected blue/checkmark
# sprite. The tweak identifies one stock art node, gives its unchecked 23px
# sprite a paint-only 32px dark/chrome silhouette, and clears every bounded Cart
# wrapper without changing layout, the sprite image, or its background position.
print('--- v5.441 device-captured 32px checkbox chrome / Cart + recycled Shopping contract ---')

_checkbox434=exact_between('         // v5.441 DEVICE-CAPTURED STOCK CHECKBOX + SHARED 32PX CHROME.',
                           '         // v5.347 PDP HEART.', 'stockCheckbox434 layer')
_checkbox434_painter=exact_between(
    '         // v5.441 DEVICE-CAPTURED STOCK CHECKBOX + SHARED 32PX CHROME.',
    '         "try{window.__AD_CHECKBOX434__=stockCheckbox434;',
    'stockCheckbox434 paint body')
_checkbox434_scheduler=exact_between(
    '         "try{window.__AD_CHECKBOX434__=stockCheckbox434;',
    '         // v5.347 PDP HEART.',
    'stockCheckbox434 scheduler')
_probe434=exact_between('       // P85CHECKBOX441:',
                        '       // P89THEME447:', 'P85CHECKBOX434')
for _label,_body,_expected in [
# v5.442: re-pointed DELIBERATELY -- radius only (50% -> 4px) so the Compare
# checkbox is a square in both Shopping and Cart. No change to fill, chrome,
# sizing, hit target, or the checked stock-blue sprite passthrough.
# v5.443: re-pointed DELIBERATELY -- stylesheet version marker 441 -> 443 so the
# square rule actually replaces the stale circular sheet in live documents.
# v5.444: re-pointed DELIBERATELY -- the checkbox stylesheet is now evicted
# UNCONDITIONALLY. Previously it was replaced only when the marker changed, so an
# edited rule (v5.442's square) silently kept the old sheet in live documents.
# v5.445: re-pointed DELIBERATELY. Stylesheet eviction is
# marker-gated again (v5.444's unconditional eviction fed the MutationObserver
# and stalled the app), the marker is bumped to 445 so new CSS lands once, and
# tag/style writes are idempotent, closing the observer feedback loop that kept
# Home from settling since v5.441.
# v5.446: re-pointed DELIBERATELY. The high-specificity document-start rule now
# uses the same 4px square as the runtime sheet, and the read-only probe rejects
# any computed circular radius. Fill, chrome, sizing, and stock blue stay fixed.
# v5.447: re-pointed DELIBERATELY. P89 is appended between the frozen P88 and P81
# anchors, so the extracted read-only probe span grows; P85/P88 paint checks are
# unchanged, and the new P89 gate is itself frozen below.
# v5.448: the checkbox/ownership span now ends at P89. This freezes P85/P88
# independently, so new diagnostic probes cannot silently re-point their hash.
    # v5.454 deliberately changes only the trigger scheduler. The complete
    # stockCheckbox434 painter remains byte-identical to v5.452 and gets its own
    # tighter hash so a timing fix cannot silently re-point solved artwork.
    ('stock checkbox paint body', _checkbox434_painter,
     'c255f1d269c09616544e7125c459bb7bd4f8bb7d41e77438cca09701425c36aa'),
    ('stock checkbox and ownership device probes', _probe434,
     'ed1cf7425d25c2aaa3da8f1883b482c9d84848c47251dc3e5b5606b4f09c3567'),
]:
    _actual=sha(_body); _ok=_actual==_expected
    print(('PASS' if _ok else 'FAIL')+f': exact {_label} {_actual}')
    if not _ok:
        print('ERROR: the v5.441 stock checkbox/chrome contract or read-only probe changed.')
        sys.exit(1)

for _required in [
    'function queue434(ms434)', 'queue434(24)', 'queue434(320)',
    "attributeFilter:['class','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']",
]:
    _ok=_required in _checkbox434_scheduler
    print(('PASS' if _ok else 'FAIL')+f': v5.454 checkbox scheduler {_required[:76]}')
    if not _ok: sys.exit(1)
_ok="'style'" not in _checkbox434_scheduler
print(('PASS' if _ok else 'FAIL')+': v5.454 checkbox observer cannot watch its own style writes')
if not _ok: sys.exit(1)

# Freeze the exact device-derived Cart hierarchy inside the expanded v5.441 test.
# are paint-neutralized, native click/pane behavior survives, and :checked
# releases the blue sprite without calling the JavaScript discovery pass.
_test434 = Path('scripts/test-compare-native-428.py').read_text()
try:
    _cart_fixture_start = _test434.index('// Cart: Amazon owns the input and sprite.')
    _cart_fixture_end_token = 'document.body.removeChild(cartItem);document.body.removeChild(cartForeignToggle);'
    _cart_fixture_end = _test434.index(_cart_fixture_end_token, _cart_fixture_start) + len(_cart_fixture_end_token)
    _cart_fixture = _test434[_cart_fixture_start:_cart_fixture_end]
    _cart_fixture_sha = sha(_cart_fixture)
except ValueError:
    _cart_fixture_sha = 'missing'
_cart_fixture_ok = _cart_fixture_sha == 'c0d496e63169decbad364c70ce85dd5108e8ed3440fa0f78be9a4cfbf3feaa15'
print(('PASS' if _cart_fixture_ok else 'FAIL')+f': exact v5.441 Cart 398x0/35x44/23x23 hierarchy fixture {_cart_fixture_sha}')
if not _cart_fixture_ok:
    print('ERROR: the Cart click/blue-sprite/no-orange/gray-shell fixture changed.')
    sys.exit(1)

for _required in [
    "function stockCheckbox434()",
    "input[type=checkbox],[role=checkbox],[aria-checked]",
    "Cart mode changes shell paint only, never page-wide checkbox scope",
    "function group434(e)",
    "if(!exact&&!legit)return null",
    "function art434(h,seed)",
    "function visual434(e)",
    "function light434(c)",
    "function generic434(e)",
    "/^(?:gfix1|gfix2|aic|gsweep|fltpanel)$/",
    "e.style.removeProperty('filter')",
    "backgroundImage||'none'",
    "maskImage||c.webkitMaskImage||'none'",
    "getComputedStyle(e,'::before')",
    "getComputedStyle(e,'::after')",
    "preserve Amazon background-image/mask sprite",
    "function foreign434(e)",
    "[class*=mlt-icon-container],[class*=lists-framework-action-button]",
    "[data-ad-cards410-root],[data-ad-cards410-host],[data-ad-cards410-disc],[data-ad-cards410-glyph]",
    "[data-ad-heart-shell427],[class*=puis-heart-position]",
    "[class*=lists-treatment-hear]",
    "[class*=puis-mab-chevron]",
    "[class*=copilot-compare],button[aria-label*=ompare]",
    "h.setAttribute('data-ad-checkbox434-host','stock')",
    "aa.setAttribute('data-ad-checkbox434-art','stock')",
    "p.setAttribute('data-ad-checkbox434-shell','cart')",
    "body434.indexOf('proceed to checkout')",
    "s434.setAttribute('data-ad-native-state','446')",
    ':has(input[type=checkbox]:checked',
    '[aria-pressed=true]',
    r'[data-ad-checkbox434-art]{filter:none !important;border-radius:4px !important;box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important;transition:none !important;}',
    r'[data-ad-checkbox434-shell=\"cart\"]{background-color:transparent !important;',
    "window.__AD_PRODUCTCTRL391_PRE434__=window.__AD_PRODUCTCTRL391RUN__",
    "new MutationObserver(function(){queue434(24);}",
    "addEventListener('scroll',function(){queue434(320);}",
    "attributeFilter:['class','aria-checked','aria-pressed','aria-selected','data-checked','data-selected','data-state','checked','src','data-src']",
    "P85CHECKBOX441[",
    "P88ICON440[",
    "timer='+timer85",
]:
    _ok=_required in _checkbox434 or _required in _probe434
    print(('PASS' if _ok else 'FAIL')+f': stock checkbox contract {_required[:78]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    '.click(', 'dispatchEvent', 'preventDefault(', 'stopPropagation(',
    'stopImmediatePropagation(', "createElement('input')", "createElement('span')",
    "createElement('svg')", 'createElementNS(', 'innerHTML=', 'outerHTML=',
    '.checked=', "setAttribute('aria-checked'", "setAttribute('data-checked'",
    "setAttribute('data-selected'", "h.setAttribute('data-ad-checkbox434-art'",
    "on?'checked':'unchecked'", r'[data-ad-checkbox434-art=\"unchecked\"]',
    r'[data-ad-checkbox434-art=\"checked\"]',
    "document.addEventListener('click'", "document.addEventListener('change'",
    "style.setProperty(",
    "setAttribute('data-ad-cards410", "setAttribute('data-ad-heart-shell427",
]:
    _ok=_forbidden not in _checkbox434
    print(('PASS' if _ok else 'FAIL')+f': no checkbox paint/emulation/scope leak {_forbidden}')
    if not _ok: sys.exit(1)

# The documentStart guard is the no-white-first-frame lane. It may target only
# Amazon's exact a-icon-checkbox painter / Cart label and must never alter the
# sprite sheet, coupon inputs, geometry, or hit target.
_firstpaint_required=[
    '.a-checkbox:not(:has(input[type=checkbox]:checked)) i.a-icon-checkbox',
    'filter:none !important;border-radius:4px !important;',
    'box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,',
    '0 0 0 4.5px rgba(255,255,255,.65) !important;',
    '.a-checkbox:has(input[type=checkbox]:checked) i.a-icon-checkbox',
    'filter:none !important;border-radius:0 !important;box-shadow:none !important;',
    '.sc-item-checkbox .a-checkbox>label',
]
_firstpaint_forbidden=['.s-coupon-checkbox','background-position:','background-image:url(',
                       'width:32px','height:32px']
_ok=all(token in _fixes_presentation for token in _firstpaint_required) and all(
    token not in _fixes_presentation for token in _firstpaint_forbidden)
print(('PASS' if _ok else 'FAIL')+': documentStart blocks white Cart/Shopping frames without touching sprite/coupons/layout')
if not _ok: sys.exit(1)

_ok=_checkbox434.count("document.createElement('style')")==1
print(('PASS' if _ok else 'FAIL')+': checkbox creates only its stock-art/Cart-shell stylesheet')
if not _ok: sys.exit(1)

try:
    _css_start=_checkbox434.index('s434.textContent=')
    _css_end=_checkbox434.index('(document.head||document.documentElement)', _css_start)
    _css_source=_checkbox434[_css_start:_css_end]
    _css434=''.join(re.findall(r"'([^']*)'", _css_source))
except ValueError:
    _css434=''
_rules=re.findall(r'([^{}]+)\{([^}]*)\}', _css434)
_art_rules=[body for selector,body in _rules if 'data-ad-checkbox434-art' in selector]
_host_rules=[body for selector,body in _rules
             if 'data-ad-checkbox434-host' in selector and 'data-ad-checkbox434-art' not in selector]
_shell_rules=[body for selector,body in _rules if 'data-ad-checkbox434-shell' in selector]
def css_properties(body):
    return [decl.split(':',1)[0].strip() for decl in body.split(';') if ':' in decl]
_shell_allowed={'background-color','background-image','border','box-shadow','outline','filter'}
_art_allowed={'filter','border-radius','box-shadow','transition'}
_geometry={'width','height','min-width','min-height','max-width','max-height','position',
           'inset','top','right','bottom','left','transform','margin','padding',
           'display','pointer-events'}
_sprite_props={'background','background-color','background-image','background-position',
               'background-size','mask','mask-image','-webkit-mask-image','content'}
_ok=(len(_art_rules)==2 and all(set(css_properties(body))<=_art_allowed for body in _art_rules)
     and len(_host_rules)==0
     and len(_shell_rules)==2
     and all(set(css_properties(body))==_shell_allowed for body in _shell_rules)
     and not any(prop in _geometry for _,body in _rules for prop in css_properties(body))
     and not any(prop in _sprite_props for body in _art_rules for prop in css_properties(body))
     and ':has(input[type=checkbox]:checked' in _css434
     and '[aria-pressed=true]' in _css434
     and 'filter:none !important' in _css434
     # v5.442: SQUARE checkbox. The unchecked art radius is 4px (was 50%), which
     # matches the corner rounding of Amazon's own checked blue sprite so both
     # states share a silhouette. The checked passthrough still resets to 0.
     and 'border-radius:4px !important' in _css434
     and 'box-shadow:inset 0 0 0 64px #181a1b,0 0 0 3px #181a1b,0 0 0 4.5px rgba(255,255,255,.65) !important' in _css434
     and 'border-radius:0 !important' in _css434
     and 'box-shadow:none !important' in _css434
     and 'brightness(0)' not in _css434
     and 'invert(1)' not in _css434
     and 'data-ad-checkbox434-art=\\"unchecked\\"' not in _css434
     and 'data-ad-checkbox434-art=\\"checked\\"' not in _css434)
print(('PASS' if _ok else 'FAIL')+f': native state owns paint/chrome; sprite, filter, and geometry untouched; Cart shell paint-neutralized rules={[(s,css_properties(b)) for s,b in _rules]}')
if not _ok: sys.exit(1)

# Runtime cleanup may remove inline writes left by retired or broad glyph writers. It may add
# one host, one art, and one Cart-shell marker, but no paint, state, or geometry.
_ok=("style.setProperty(" not in _checkbox434
     and _checkbox434.count("setAttribute('data-ad-checkbox434-host'")==1
     and _checkbox434.count("setAttribute('data-ad-checkbox434-art'")==1
     and _checkbox434.count("setAttribute('data-ad-checkbox434-shell'")==1)
print(('PASS' if _ok else 'FAIL')+': runtime writes no paint/state/geometry and marks native hosts/art plus Cart shells')
if not _ok: sys.exit(1)

for _retired in [
    r"function compareStock379(){window.__AD_COMPARE379__=\'retired433\';return 0;}",
    r"function compareStock380(){window.__AD_COMPARE380__=\'retired433\';return 0;}",
    r"function legacyCompare387(){window.__AD_COMPARELEGACY387__=\'retired433\';return 0;}",
    "var C=[],seenC=[];/* checkbox is owned only by stockCheckbox434 */",
    "window.__AD_STOCKFIN403__=function(){window.__AD_STOCKFIN403_STATE__='checkbox=retired433';return 0;};",
]:
    _ok=_retired in src
    print(('PASS' if _ok else 'FAIL')+f': retired checkbox painter {_retired[:76]}')
    if not _ok: sys.exit(1)

for _required in [
    'retired Shopping white-silhouette CSS',
    'Amazon inline artwork is no longer protected',
    'Cart classic checkbox was not discovered',
    'Cart 35x44 gray label was not neutralized',
    'Cart gray rectangle survived computed shell cleanup',
    'Cart unchecked sprite regressed from the canonical square 32px dark/chrome treatment',
    'Cart blue checked sprite waited for JavaScript or was inverted orange',
    'Shopping role-button checkbox was not discovered',
    'Shopping stale broad-writer filter survived cleanup',
    'Shopping unchecked white sprite was not covered with #181a1b',
    'Shopping checked stock sprite did not render',
    'Shopping blue sprite waited for repaint or flashed orange',
    'newly recycled Shopping row was not discovered',
    'Shopping aria-pressed Compare control was not discovered',
    'ARIA checked blue sprite was altered or delayed',
    'solid-white Shopping checkbox was not discovered',
    'solid-white Shopping filter landed on hidden sprite',
    'solid-white Shopping box did not render #181a1b',
    'solid-white Shopping checked sprite was altered or delayed',
    'wrapper-pseudo stock artwork was not discovered',
    'wrapper-pseudo blue sprite was altered or timer-delayed',
    'visible two-cards host was not painted',
    'two-cards backdrop regressed from black',
    'two-cards artwork regressed from white',
    'cards owner forced Amazon visibility',
    'hidden cards artwork was forced active',
    'cards were not suppressed at a live checkbox collision',
    'colliding cards subtree can still spill over checkbox',
    'collision checkbox did not retain #181a1b stock-art covering',
    'checkbox acquired cards ownership',
    'recycled cards node stayed suppressed after checkbox disappeared',
    'cards were not re-suppressed when checkbox returned',
    'JavaScript timer-state selectors survived',
    'filter leaked into another icon family',
    'product coupon checkbox was mistaken for Compare',
]:
    _ok=_required in _test434
    print(('PASS' if _ok else 'FAIL')+f': DOM fixture assertion {_required}')
    if not _ok: sys.exit(1)

print('PASS: v5.441 freezes cards/checkbox ownership, paints one 32px dark/chrome unchecked icon, removes every bounded Cart shell, preserves the stock sprite, and releases Amazon blue/checkmark state synchronously.')

# v5.448 NATIVE COMPARE-MINUS / SIBLING HOME-CREATIVE LOCK
# The v5.447 device probe disproved both ownership assumptions: P89 stayed at
# pane/host/glyph=0 because the Compare tray is native React/UIKit, and P59 found
# five background leaves while the descendant creative selector found zero. Freeze
# the corrected boundaries: native semantic+geometry acquisition may paint only a
# nested minus leaf, and rectangle overlap may release only a non-video creative
# background sibling back to Amazon's own color.
print('--- v5.448 native Compare-minus / sibling Home creative paint boundary ---')
_native448 = exact_between('// ── v5.448 NATIVE COMPARE-TRAY MINUS',
                           'static void ADTextClassWalk', 'native Compare 448')
_home448 = exact_between('         // v5.448 HOME CREATIVE.',
                         '         "function homeAmbient386(){', 'Home creative 448')
_probe91 = exact_between('       // P91HOME448:',
                         '       // P81CTRL (v5.417):', 'P91HOME448')
_firstpaint448 = exact_line("__acs.textContent=__acs.textContent.replace('[class*=npack-asin-card]",
                            'v5.448 first-paint sibling release')
_scheduler448 = exact_line('try{homeCreative448();setTimeout(homeCreative448,40)',
                           'v5.448 Home scheduler')
_fixture448 = Path('scripts/test-theme-surfaces-448.py').read_text()

# Assignment-time pins are frozen independently from acquisition. This prevents
# a later Fabric commit from restoring the dark 10x14 raster after it was found.
_view_solid448 = exact_between(
    '    // v5.448 Compare tray: only a positively-owned thin minus bar is pinned',
    '    if (!ADRecolorOn() || !color || ADIsOwnColor(color) || ADIsWebKitOwned(self))',
    'UIView Compare solid pin')
_view_tint448 = exact_between(
    '    // Amazon reassigns the tiny Compare-minus tint during Fabric commits.',
    '    // Tab bar FIRST, before the generic guard below.',
    'UIView Compare image-tint pin')
_label_text448 = exact_between(
    '%hook UILabel\n- (void)setTextColor:(UIColor *)color {\n'
    '    if (ADRecolorOn() && objc_getAssociatedObject(self, kADCompareText448Key))',
    '    if (!ADRecolorOn() || !color || ADIsOwnColor(color))',
    'UILabel Compare text pin')
_layer_solid448 = exact_between(
    '        if (objc_getAssociatedObject(self, kADIndicatorKey) ||',
    '        CGColorRef m = ADModifyCGColor(color, ADColorRoleBackground);',
    'CALayer Compare solid pin')
_layer_filter448 = method_in_hook('CALayer', '- (void)setFilters:(NSArray *)filters')
_image_assign448 = exact_between(
    "    // v5.448: the Compare tray's native 10x14 minus is replaced during React",
    '    if (!image || ADIsWebKitOwned(self) || !ADRecolorOn() || gADSettingImage)',
    'UIImageView Compare assignment pin')
_rct_paragraph448 = hook_block('RCTParagraphComponentView')
_rct_text448 = hook_block('RCTTextView')
_rct_view448 = hook_block('RCTViewComponentView')

for _label, _body, _expected in [
    ('native semantic/geometry/leaf owner', _native448,
     '22e4875e52527261c45c50f753df0379e5bc5c8f82ea7e5bbeddd87f6176a8da'),
    ('sibling Home creative owner', _home448,
     '1fb09933b1950ee3a1b3317de3610c7920c8ab79c8e5989312fe966c2d4fd875'),
    ('P91 Home device contract', _probe91,
     '60ed2f4f9cf23961bf0ee746a83a5c50a8ab817e169bcb0857be0fd0b05980f5'),
    ('documentStart sibling release', _firstpaint448,
     'f6c7587a7a83c45d044e6aa3c4721e10f82b30a70b1afe8a7b4342749b1d3aee'),
    ('Home creative persistent scheduler', _scheduler448,
     '7ccc952deaae7c70eed2938661e0271b1218359019adc3496925b6fb6ff41109'),
    ('native/Home regression fixture', _fixture448,
     'a2c79e44fa0aca92837bcef51ec760e52ca0731c863cc663201ee3cdb0b11be2'),
    ('UIView solid-minus assignment pin', _view_solid448,
     '229e589b4203dc46c99f04054e695d3647a773273b9a05cd5350aec314a62817'),
    ('UIView image-tint assignment pin', _view_tint448,
     '6dae30e57e7f8264cc9827ef8d51c377ea412b948b8b37422a18121ed81c4998'),
    ('UILabel text-minus assignment pin', _label_text448,
     '1be1a8786682bef6ed6f1a9cb69b77739e9ac6c4f4b6d4abb910bd2913e313b9'),
    ('CALayer solid-minus assignment pin', _layer_solid448,
     'ab8f71acb365be1b97ae275bd00f667b64f59a591b35601c78cf6e864a7ed202'),
    ('CALayer raster/vector filter pin', _layer_filter448,
     '97e271c984cb720d864adaf4d1f768761021603b291207ffd49161a0535044e4'),
    ('UIImageView raster assignment pin', _image_assign448,
     '08cb55f30d9f949c81114348adbe8e0d21dc8314c14e39e004076fa7fa9ec054'),
    ('Fabric paragraph semantic trigger', _rct_paragraph448,
     '8b4ab8a5497743b898a673c1b3bb8027610e91eec2cd923c6ca74f37a34ad357'),
    ('Paper text semantic trigger', _rct_text448,
     'ccb8e712227ce94018169c12e481b100fcab871bc10856bc497f65d4b822fd44'),
    ('Fabric view persistent rescheduler', _rct_view448,
     '25fcabec6b8d53252e690601808e9d5ff991bc41288a71fc6a5cbe5f91c89c94'),
]:
    _actual = sha(_body); _ok = _actual == _expected
    print(('PASS' if _ok else 'FAIL')+f': exact v5.448 {_label} {_actual}')
    if not _ok:
        print('ERROR: the v5.448 native glyph leaf or Home sibling boundary changed.')
        sys.exit(1)

for _required in [
    'kADCompareHost448Key', 'kADCompareImage448Key', 'kADCompareSolid448Key',
    'kADCompareText448Key', 'kADCompareLayer448Key',
    '@"Compare with similar"', '@"keep selecting"',
    'if (ADIsWebKitOwned(v)) return nil;',
    'f.size.height>=54 && f.size.height<=210',
    'w>=24 && w<=96 && h>=24 && h<=96',
    'w<18 || w>52 || h<18 || h>52',
    'ADCompareViewCandidate448(v,v,0)',
    'ADComparePinWalk448(host,host,0,&images,&solids,&texts,&layers)',
    'P90COMPARE448[text=1', 'hostStable=%d',
    'if (gADCompare448Armed) ADFixNativeCompare448();',
]:
    _ok = _required in src
    print(('PASS' if _ok else 'FAIL')+f': v5.448 native Compare contract {_required[:76]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    'host.backgroundColor=', 'host.layer.backgroundColor=',
    'host.layer.cornerRadius=', '[host setFrame:', '[host setBounds:',
    'objc_setAssociatedObject(host,kADCompareImage448Key',
    'objc_setAssociatedObject(host,kADCompareSolid448Key',
    'objc_setAssociatedObject(host,kADCompareText448Key',
    'objc_setAssociatedObject(host,kADCompareLayer448Key',
    '.click(', 'dispatchEvent', 'preventDefault(', 'stopPropagation(',
    "createElement('svg')", 'innerHTML=', 'outerHTML=',
]:
    _ok = _forbidden not in _native448
    print(('PASS' if _ok else 'FAIL')+f': v5.448 native host/state/artwork immutable {_forbidden}')
    if not _ok: sys.exit(1)

for _required in [
    "document.querySelectorAll('[class*=theming-card-background]')",
    'img[class*=\\"_single-creative-card\\"]',
    'img[class*=\\"_single-video-card\\"]',
    'ia448/ma448>.72', 'if(vi448)continue',
    "setAttribute('data-ad-homecreative448','native')",
    "removeProperty('box-shadow')", "removeAttribute('data-ad-homebg395')",
    'P91HOME448[released=', 'forcedBlack=', 'videoReleased=', 'stale395=',
]:
    _ok = _required in _home448 or _required in _probe91
    print(('PASS' if _ok else 'FAIL')+f': v5.448 Home sibling contract {_required[:76]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    "setProperty('background-color'", "setProperty('background'", '.click(',
    'dispatchEvent', 'preventDefault(', 'stopPropagation(', "createElement('svg')",
    'innerHTML=', 'outerHTML=',
]:
    _ok = _forbidden not in _home448
    print(('PASS' if _ok else 'FAIL')+f': v5.448 Home release invents no paint/state {_forbidden}')
    if not _ok: sys.exit(1)

_ok = ("[class*=theming-card-background]:not([data-ad-homecreative448])" in _firstpaint448
       and "replace(/data-ad-homecreative447/g,'data-ad-homecreative448')" in _firstpaint448
       and "[class*=single-video-card] [class*=theming-card-background]" in src
       and 'comparePane447' not in _scheduler448
       and 'homeCreative447' not in _scheduler448)
print(('PASS' if _ok else 'FAIL')+': v5.448 releases the sibling creative while retaining video/failed-path guards')
if not _ok: sys.exit(1)

for _required in [
    "borderRadius:checkboxArt?(selected?'0px':'4px')",
    "getComputedStyle(cartArt).borderRadius==='4px'",
    "getComputedStyle(shopping.art).borderRadius==='4px'",
]:
    _ok = _required in _test434
    print(('PASS' if _ok else 'FAIL')+f': v5.448 frozen square-checkbox fixture {_required}')
    if not _ok: sys.exit(1)

print('PASS: v5.448 locks every recently edited symbol, pins only the native minus leaf, keeps its host dark, restores Amazon creative color, and retains the video guard.')

# v5.450 DEVICE-EVIDENCE LOCK
# P92 proved the UIWindow bottom-band coordinate was false for all three native
# candidates. P93 proved v5.449's broad image exemption removed WBT from four
# Home creatives, while P73 exposed one saturated authored background under the
# v5.395 compositor. Freeze the corrected boundaries exactly.
print('--- v5.450 local Compare paint / authored Home color + WBT lock ---')
_native450 = exact_between('// ── v5.450 LOCAL-STRUCTURE COMPARE CONTROL',
                           '// ── P19 VOICE-PERMISSION', 'native Compare 450')
_home450 = exact_between('         // v5.450 HOME AUTHORED COLOR.',
                         '         "function badgeFix(){try{"', 'Home color 450')
_probe94 = exact_between('       // P94HOME450:',
                         '       // P69V333403:', 'P94HOME450')
_layer_pin450 = exact_between(
    '        if (objc_getAssociatedObject(self, kADCompareCircle450Key)) {',
    '        if (ADLayerIsWebKitOwned(self)) {', 'CALayer Compare paint pins')
_image_assign450 = exact_between(
    '    // A Compare tray may reuse an already-mounted RN image view',
    '    // v5.448: the Compare tray', 'UIImageView Compare local trigger')
_fixture450 = Path('scripts/test-theme-surfaces-450.py').read_text()

for _label, _body, _expected in [
    ('local native owner', _native450, 'a57433afcac631c026840f2e22356cf49b3898f4fa3c5125cff38da5d994c99b'),
    ('authored Home color owner', _home450, 'eb51677b2d9b326351603a2dd4aa02263b8783b5320fe79d5cf56a9a80508fae'),
    ('P94 Home device contract', _probe94, 'ee390e478ccb2b588f6982831ea69764033d22d15b1633c617db696d00ca460f'),
    ('CALayer light/dark assignment pins', _layer_pin450, 'da5da1443110711c4971b861babf853b2e922f6858f3208ef21178d7a05ac6ef'),
    ('UIImageView local acquisition trigger', _image_assign450, '96da1d3834e818bf892cfe50bff558a1cc849bf3140626a5aa4d1dcb376d4724'),
    ('local/native/Home regression fixture', _fixture450, '8b8285f8b8f58587318c73fe7470d123546b0f9f825ebbb9652debfa02747a51'),
]:
    _actual = sha(_body); _ok = _actual == _expected
    print(('PASS' if _ok else 'FAIL')+f': exact v5.450 {_label} {_actual}')
    if not _ok:
        print('ERROR: the v5.450 Compare paint or Home color/WBT boundary changed.')
        sys.exit(1)

for _required in [
    'w<8 || w>30 || h<8 || h>30 || fabs(w-h)>8',
    'w>=240 && w<=900 && h>=44 && h<=260 && w/h>=1.8',
    'w>=38 && w<=104 && h>=30 && h<=96',
    'ADCompareThumbWalk450(p,p,leaf,0,&localThumb,&localScore)',
    'ADCompareDarkRaster450', 'dx>=-16 && dx<=64 && dy<=42',
    'kADCompareCircle450Key', 'kADCompareMinus450Key',
    'circle.backgroundColor=[UIColor whiteColor].CGColor',
    'minus.backgroundColor=ADColorFromHex(gP.bgHex).CGColor',
    'P94COMPARE450[nodes=', 'geometryStable=%d',
]:
    _ok = _required in _native450
    print(('PASS' if _ok else 'FAIL')+f': v5.450 local native contract {_required[:76]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    'CGRectGetMidY(lf)<', 'win.bounds', 'host.backgroundColor=',
    'host.layer.backgroundColor=', 'host.layer.cornerRadius=',
    'host.frame=', 'host.bounds=', '[host setFrame:', '[host setBounds:',
    '[iv setImage:', 'ADNativeComparePhrase448',
]:
    _ok = _forbidden not in _native450
    print(('PASS' if _ok else 'FAIL')+f': v5.450 native geometry/artwork immutable {_forbidden}')
    if not _ok: sys.exit(1)

for _required in [
    "querySelectorAll('[class*=theming-card-background]')",
    "setAttribute('data-ad-homecolor450','authored')",
    "Math.max(q450[0],q450[1],q450[2])-Math.min(q450[0],q450[1],q450[2])<24",
    "removeProperty('box-shadow')", "removeProperty('background-blend-mode')",
    "removeAttribute('data-ad-homebg395')", "_adHomeMedia395()",
    'P94HOME450[colored=', 'creativeFull=', 'untamed=', 'stale449=',
]:
    _ok = _required in _home450 or _required in _probe94
    print(('PASS' if _ok else 'FAIL')+f': v5.450 Home color/WBT contract {_required[:76]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    "setProperty('filter','none','important')",
    "setAttribute('data-ad-homecreative449'", 'homeCreative449Native',
    '.click(', 'dispatchEvent', "createElement('svg')", 'innerHTML=', 'outerHTML=',
]:
    _ok = _forbidden not in _home450
    print(('PASS' if _ok else 'FAIL')+f': v5.450 Home owner cannot disable image WBT/invent state {_forbidden}')
    if not _ok: sys.exit(1)

for _required in [
    '        ADFixNativeCompare450();',
    '                ADScheduleNativeCompare450();',
    '            ADScheduleNativeCompare450();',
    'const double delay450[]={0.01,0.08,0.25,0.70,1.50,3.00}',
]:
    _ok = _required in src
    print(('PASS' if _ok else 'FAIL')+f': v5.450 structural acquisition stays armed {_required.strip()}')
    if not _ok: sys.exit(1)

for _retired in [
    'ADFixNativeCompare449(void)', 'ADScheduleNativeCompare449(void)',
    'function homeCreative449', '__AD_HOMEMEDIA449_WRAP__',
]:
    _ok = _retired not in src
    print(('PASS' if _ok else 'FAIL')+f': failed v5.449 path retired {_retired}')
    if not _ok: sys.exit(1)

print('PASS: v5.450 permanently gates the local Compare control as a white circle/dark minus, restores only saturated authored Home backings, and keeps every full-card creative on v5.395 WBT.')

# v5.452 HOME CAROUSEL LOCK
# This release is deliberately v5.450 plus one Home-only boundary: capture the
# authored non-video backing before our painters, restore it, and place the
# standard preference-scaled darkness in a separate gradient. The exact v5.450
# hashes above prove that Compare, checkbox, and all other owners stayed frozen.
print('--- v5.452 authored Home carousel color + uniform overlay lock ---')
_homecap452 = exact_between('         // v5.452 HOME AUTHOR-PAINT CAPTURE.',
                            '         "try{if(document&&!document.getElementById(\'adcardfix\')){"',
                            'Home author capture 452')
_homeowner452 = exact_between('         // v5.452 HOME CAROUSEL COLOR + UNIFORM TAME.',
                              '         // v5.454 HOME BLEED CLIP.',
                              'Home overlay owner 452')
_probe95 = exact_between('       // P95HOME452:',
                         '       // P98BLEED454:', 'P95HOME452')
_fixture452 = Path('scripts/test-home-carousel-452.py').read_text()

for _label, _body, _expected in [
    ('documentStart author capture', _homecap452, '40660e8a8a28a1fb6ad40b6bf29a721dd1d1eaad916f79d1f329d35ddeb55e8b'),
    ('uniform color overlay owner', _homeowner452, 'd264b865b40ce2a769bdf83cbd7425fe4af3ab98b485c1b2a518d71582bf724a'),
    ('P95 Home carousel contract', _probe95, 'fadd18c0947cd9757309d0515d6e169fe65b5f41cd8c5f658c1b0953acf29f7f'),
    ('Home carousel regression fixture', _fixture452, 'ab973c4803d82b8da67c95e036f5bbdbb3bf57427454f137a6c57f1254c6e89e'),
]:
    _actual = sha(_body); _ok = _actual == _expected
    print(('PASS' if _ok else 'FAIL')+f': exact v5.452 {_label} {_actual}')
    if not _ok:
        print('ERROR: the v5.452 authored-color capture or uniform overlay changed.')
        sys.exit(1)

for _required in [
    'function homeDoc452()', 'function oneHome452(e452)',
    "c452.indexOf('theming-card-background')<0",
    'single-video-card|video-card|video-js|vjs-|sbv-video',
    '__adHomeAuth452={background:', "data-ad-homecolor452",
    "{childList:true,subtree:true}",
    ':not([data-ad-homecreative448]):not([data-ad-homecolor452])',
]:
    _ok = _required in _homecap452 or _required in src
    print(('PASS' if _ok else 'FAIL')+f': v5.452 early capture contract {_required[:78]}')
    if not _ok: sys.exit(1)

for _required in [
    'function _adHomeApply452(e452)', 'window.__AD_HOMEBG395_PRE452__',
    "return _adHomeApply452(e452)", "put452('background-color'",
    "put452('background-image'", "overlay452='linear-gradient('",
    '0.50*(S452/100)', "setAttribute('data-ad-homeoverlay452',aa452)",
    "__adBy='homeColorOverlay452'", "removeAttribute('data-ad-homebg395')",
    "querySelectorAll('[data-ad-homecolor452=",
    "captured='+E452.length+' tamed='+n452+' missing='+miss452",
    "P95HOME452[captured=", 'missingOverlay=', 'creativeUntamed=',
]:
    _ok = _required in _homeowner452 or _required in _probe95
    print(('PASS' if _ok else 'FAIL')+f': v5.452 uniform-overlay contract {_required[:78]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    'if(r452.width', 'if(r452.height', 'Math.max(q452',
    '.click(', 'dispatchEvent', 'preventDefault(', 'stopPropagation(',
    "createElement('svg')", 'innerHTML=', 'outerHTML=',
    'ADCompareScreenRect451', 'ADFixNativeCompare451', 'P95COMPARE451',
    'queueRuntime451', '__AD_RUNTIME451_DONE__',
]:
    _scope = src if '451' in _forbidden else _homeowner452
    _ok = _forbidden not in _scope
    print(('PASS' if _ok else 'FAIL')+f': v5.452 remains Home-only / all-card {_forbidden}')
    if not _ok: sys.exit(1)

print('PASS: v5.452 is the frozen v5.450 build plus authored Home carousel color restoration and one uniform tame overlay on every captured non-video card background.')

# v5.454 EXPERIMENTAL PERFORMANCE + HOME BLEED LOCK
# v5.452 remains the visual baseline above. These additions may move trigger
# timing and add one rounded host clip, but they may not rewrite any solved
# painter, media property, control state, geometry, or playback path.
print('--- v5.454 visual-neutral performance scheduling + rounded Home clip lock ---')
_bleed454 = exact_between('         // v5.454 HOME BLEED CLIP.',
                          '         "homeAmbient386();badgeFix()',
                          'Home bleed clip 454')
_probe98 = exact_between('       // P98BLEED454:',
                         '       // P94HOME450:', 'P98BLEED454')
_runtime454 = exact_between('static NSString *ADRuntimeWebJS454(void){',
                            '// Lightweight, idempotent production runtime installation',
                            'runtime-only extractor 454')
_focused454 = exact_between('static void ADFocusedProbe363(void){',
                            '// ── NATIVE HAIRLINE / BORDER SWEEP',
                            'automatic runtime installer 454')
_scroll454 = exact_between('@interface ADScrollSettle454 : NSObject',
                           '// ════════════════════════════════════════════════════════════════════════════════\n// SURFACE 4',
                           'true trailing native scroll 454')
_observer454 = exact_between('         // v5.454: retain every v5.452 painter and its order',
                             '         "try{new MutationObserver(function(){try{cartChrome382();}',
                             'shared runtime observer 454')
_fixture454 = Path('scripts/test-performance-bleed-454.py').read_text()

for _label, _body, _expected in [
    ('rounded Home card-host clip', _bleed454, '6f92c803943b93c6a0efe31766d5d54037e6c07b24f825fd8e578822ee620184'),
    ('P98 bleed device contract', _probe98, 'c7a7ce76ccfa5d1f9fc3621b35e8f96c3ec6a3333e3d2644701cc72582887825'),
    ('runtime-only extractor', _runtime454, 'ca404ddec1f0fc36d71e399c8cf4d2eb0f0b57f0874110dfb38cbe4a0c9d0aa3'),
    ('automatic runtime installer', _focused454, '691aeb69fc2f604430d5ea6ab696f91ea777df05e74b97535e39612f1c57ecd6'),
    ('true trailing native scroll guard', _scroll454, '50b982b0ffb56782b6dfec9667ab441d1b411ffe3e7b6597373c4ae6719296f4'),
    ('shared idle mutation scheduler', _observer454, '3e9000d75ca56c85ebdc7bf0464784c6847e3dfb917bae8cdc44e84db679bae7'),
    ('performance/bleed regression fixture', _fixture454, '69f123be967d2f2d5c8c6450db7c311a66e13a4a48303e1f67c82b91128c885b'),
]:
    _actual=sha(_body); _ok=_actual==_expected
    print(('PASS' if _ok else 'FAIL')+f': exact v5.454 {_label} {_actual}')
    if not _ok:
        print('ERROR: the v5.454 performance/bleed contract changed.')
        sys.exit(1)

for _required in [
    'data-ad-homeclip454', '--ad-homeclip454-radius',
    'overflow:hidden !important', 'clip-path:inset(.5px round var(',
    'window.__AD_HOMECOLOR452_PRE454__', 'P98BLEED454[hosts=',
]:
    _ok=_required in _bleed454 or _required in _probe98
    print(('PASS' if _ok else 'FAIL')+f': v5.454 rounded-host clip contract {_required[:78]}')
    if not _ok: sys.exit(1)

for _forbidden in [
    'new MutationObserver(', "addEventListener('scroll'", "setProperty('filter'",
    "setProperty('transform'", "setProperty('background'", "setProperty('background-color'",
    "setProperty('background-image'", "setProperty('width'", "setProperty('height'",
    '.play(', '.pause(', '.click(', 'dispatchEvent',
]:
    _ok=_forbidden not in _bleed454
    print(('PASS' if _ok else 'FAIL')+f': v5.454 bleed fix cannot mutate media/state/layout {_forbidden}')
    if not _ok: sys.exit(1)

_ok=('ADRuntimeWebJS454()' in _focused454
     and 'evaluateJavaScript:ADProbeWebJS()' not in _focused454
     and 'rangeOfString:@"/*V5313FIX*/"' in _runtime454
     and 'rangeOfString:@"/*V5395FIX*/"' in _runtime454)
print(('PASS' if _ok else 'FAIL')+': v5.454 normal navigation runs only the production painter installer')
if not _ok: sys.exit(1)

_ok=("'style'" not in _observer454 and "'fill'" not in _observer454
     and "'stroke'" not in _observer454
     and 'data-darkreader-inline-bgcolor' not in _observer454
     and 'requestIdleCallback(run454,{timeout:420})' in _observer454)
print(('PASS' if _ok else 'FAIL')+': v5.454 shared observer cannot feed painter writes back into itself')
if not _ok: sys.exit(1)

print('PASS: v5.454 keeps v5.452 visual owners exact, moves diagnostics off navigation, coalesces self-triggering scans, waits for native scroll quiet, and clips carousel descendants at the rounded card host.')
