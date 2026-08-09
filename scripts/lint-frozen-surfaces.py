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
for key in ['function cartChrome379(){','function cartChrome382(){']:
    lines=[ln for ln in src.splitlines() if key in ln]
    if len(lines)!=1: raise RuntimeError(f"{key}: expected one source line, got {len(lines)}")
    items[key]=lines[0]
items['cart_css_lines']='\n'.join(ln for ln in src.splitlines() if 'data-ad-cart' in ln)

bad=False
for key, expected in EXPECTED.items():
    actual=sha(items[key])
    ok=actual==expected
    print(('PASS' if ok else 'FAIL')+f': frozen {key} {actual}')
    bad |= not ok

# Home carousel video playback was separately user-confirmed working in v5.391.
video=[ln for ln in src.splitlines() if '_adHomeVideo391' in ln]
vsha=sha('\n'.join(video))
vexp='7f6f56ed65addf48812d33e75cc7eae5b6e2eec268be6a4f7062334713e632cd'
vok=len(video)==5 and vsha==vexp
print(('PASS' if vok else 'FAIL')+f': frozen Home video lines={len(video)} sha={vsha}')
bad |= not vok

# v5.395 HOME FIXES — USER-CONFIRMED GOOD. These are stronger than a function
# hash alone: exact runtime definition/call lines are frozen, exact repair-marker
# populations are frozen, and no additional direct media/standalone selectors may
# be introduced outside the new v5.396 bleed-only first-paint guard/probe.
def agg_lines(pattern, exclude=None):
    rx=re.compile(pattern)
    ex=re.compile(exclude) if exclude else None
    lines=[ln for ln in src.splitlines() if rx.search(ln) and not (ex and ex.search(ln))]
    return lines, sha('\n'.join(lines))

HOME395 = {
    '_adHomeMedia395 exact definition/calls': (r'_adHomeMedia395', None, 4, '3e444e384aec697faa7de97f191f5614e2dda0683c8758a43e71b95e9b8846e2'),
    'Home media marker population': (r'data-ad-homemedia395|homeMedia395', None, 2, 'f7026a7152b61130636e321a3c2de4e21089e0ea866ef1d2041ebbdac3c5e1ae'),
    '_adStandaloneSweep395 exact definition/calls': (r'_adStandaloneSweep395', None, 4, '1e931418220ed80b4fd966a2280ed2231dd067c98541e7bbb54e78c5718d8681'),
    'Standalone repair marker population': (r'data-ad-homeauto395|data-ad-standparent395|data-ad-standbefore395|data-ad-standafter395', None, 4, '6d508367ffaf47dbc86910ebaa13cd2ff75d47825911d2d008715d2958e285d2'),
    'Standalone iframe selector population': (r'iframe\[data-ad-frame-mode362', None, 4, '2835e55cd74e8a785c76257a97e69d6dfc3e40c4da80eac18cd711609b0278cb'),
    # Exclude only the v5.396 first-paint guard/probe. All older direct references
    # to the confirmed Home media classes must remain exactly the v5.395 set.
    'Home media direct-selector population': (r'single-creative-card|single-video-card|video\.vjs-tech|data-ad-homemedia395', r'data-ad-main396|P59BLEED396', 4, 'f1976ee3a8b48cb6e9278243e8af2064b01160fb8abd62731ccc90d59753b301'),
}
for label,(pattern,exclude,count,expected) in HOME395.items():
    lines,actual=agg_lines(pattern,exclude)
    ok=(len(lines)==count and actual==expected)
    print(('PASS' if ok else 'FAIL')+f': frozen {label} lines={len(lines)} sha={actual}')
    bad |= not ok

# Explicitly reject the known-bad standalone blend path and obvious attempts to
# remove/clear the v5.395 ownership markers. This catches surrounding-code attacks
# that would not modify the frozen function definitions themselves.
for forbidden in [
    '__AD_STANDBLEND384__',
    "removeAttribute('data-ad-homemedia395')",
    'removeAttribute("data-ad-homemedia395")',
    "removeAttribute('data-ad-homeauto395')",
    'removeAttribute("data-ad-homeauto395")',
    "removeAttribute('data-ad-standparent395')",
    'removeAttribute("data-ad-standparent395")',
]:
    ok=forbidden not in src
    print(('PASS' if ok else 'FAIL')+f': forbidden competing writer absent: {forbidden}')
    bad |= not ok

if bad:
    print('ERROR: a user-confirmed-good frozen surface changed.')
    print('Do not update expected hashes merely to bypass this gate.')
    sys.exit(1)
print('PASS: Alexa, Hamburger, Cart, Person, Home video, v5.395 Home WBT, and v5.395 standalone-ad fixes are frozen unchanged.')

# v5.397 SYMBOL POLICY — v5.333 owns every non-checkbox symbol. The current
# Compare checkbox is explicitly exempt and is frozen byte-for-byte from v5.396.
# This is intentionally checked after all older surface gates so a later developer
# cannot "fix" a symbol by reopening a confirmed Person/Home/Menu path.
print('--- v5.397 v5.333 symbol authority / current-checkbox lock ---')

# The two current checkbox state machines are exact source-line locks.
for key, expected in {
    'function compareStock380(){':'f97dc076a9ab899cfc8cbf591465fc8f3af95a6beaa76afe034f9a3e234afc06',
    'function legacyCompare387(){':'e350a9b5fbd0c1a673089c3e5a6ac343ca1c09de7c1b809ae4230fddf5347d24',
}.items():
    lines=[ln for ln in src.splitlines() if key in ln and 'v5.397' not in ln]
    actual=sha(lines[0]) if len(lines)==1 else '-'
    ok=len(lines)==1 and actual==expected
    print(('PASS' if ok else 'FAIL')+f': current checkbox {key} {actual}')
    bad |= not ok

# Freeze the complete ORIGINAL v5.396 product-control function. v5.397 wraps it
# after definition; it does not edit one byte of the current checkbox implementation.
plines=src.splitlines()
try:
    pst=next(i for i,l in enumerate(plines) if 'window.__AD_PRODUCTCTRL391RUN__=function' in l)
    pen=next(i for i in range(pst,len(plines)) if "window.__AD_PRODUCTCTRL391__='err '" in plines[i])
    pblock='\n'.join(plines[pst:pen+1])
    pactual=sha(pblock); pexpected='ce65d88388dcf4036f91a719e6a45dcd01bd317f496d3fb2e324ede86480b650'
    ok=pactual==pexpected
except Exception:
    pactual='missing'; ok=False
print(('PASS' if ok else 'FAIL')+f': current checkbox/product-control original block {pactual}')
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

# v5.333 web glyph passes must still be present byte-identically. Each hash is a
# 500-character source window centered on the historical writer marker.
V333_WINDOWS={
 'gfix1':'c7cea9187726e0dc741280f80771c5e31a578ef3e1528ebe7c68b5d328b63af8',
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
    actual=sha(run397); expected='8a8c755a1fa83b83e49db441570bccf4468472591d2d28c6b5bd1f453d39591b'
    ok=actual==expected
except Exception:
    actual='missing';ok=False
print(('PASS' if ok else 'FAIL')+f': v5.333 post-modern symbol authority {actual}')
bad |= not ok

# Checkbox exclusion is mandatory in both runtime and probe. No v333 authority write
# is allowed to originate from a Compare/MLT/checkbox node.
required=[
 '[class*=mlt-icon-container],[role=checkbox],input[type=checkbox],[class*=a-icon-checkbox],[data-ad-compare380],[data-ad-comparelegacy387]',
 'if(ischeck397(h397))continue', 'if(ischeck397(q397))continue', 'if(ischeck397(de397))continue',
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
print('PASS: v5.333 owns non-checkbox symbols; current checkbox and all previously frozen surfaces remain exact.')

# Final checkbox CSS/selector aggregate lock. Exclude only the v5.397 authority lines;
# everything pre-existing that can recognize or paint the checkbox must stay v5.396 exact.
checkbox_lines=[]
for ln in src.splitlines():
    if '397' in ln: continue
    if re.search(r'mlt-icon-container|data-ad-compare380|data-ad-comparelegacy387|data-ad-product391=\\?"checkbox',ln):
        checkbox_lines.append(ln)
cbsha=sha('\n'.join(checkbox_lines))
cbexp='66b7b2ba23523e295bf013b6d2c089f5c579e3573cc5396c721825f2e4d84019'
ok=len(checkbox_lines)==28 and cbsha==cbexp
print(('PASS' if ok else 'FAIL')+f': entire pre-v5.397 checkbox selector/CSS/runtime population lines={len(checkbox_lines)} sha={cbsha}')
if not ok:
    print('ERROR: current checkbox population changed; v5.333 symbol authority may not touch it.')
    sys.exit(1)
print('PASS: current checkbox remains fully locked outside the v5.333 symbol authority.')
