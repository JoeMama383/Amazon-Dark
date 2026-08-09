#!/usr/bin/env python3
"""Hard regression gate for user-confirmed-good v5.393 surfaces.

Alexa, Hamburger, and Shopping Cart were explicitly confirmed good on-device at
v5.393.  These hashes are the exact v5.393 source blocks.  Do not update them
just to make a later build pass: a deliberate surface change requires reopening
that surface with new device evidence.
"""
from pathlib import Path
import hashlib, re, sys

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "src/Tweak.xm")
src = SRC.read_text()

EXPECTED = {'ADInTabBarChain': 'e2d7c32dfb1d326d0f95fc96a24cb7e8b787bb554e5abdd4a49ef87800e748c9', 'ADViewIsSelectedInBar': 'f278b2fa765e4dd5230976a7167d26dc0d057b75b0bdd8f6964959516cc90483', 'ADTintBarIcon': '0a780232e861f864d9356b790fcbceff71df3a20043a573ca94d48fd4973478b', 'ADMenuRoot382': '446620008b2fbfb5c1460951afd71c840ef55afcf8adba5d4cbf9c54ab615926', 'ADHamburgerScreenActive384': 'e4a16c7bdaea2c5e32977cd4672bca639da6e119e072714ba1ae6d16f65c03b3', 'ADMenuRole382': 'c857750b6fab58c86a2c0d3fce76bcce5b5464bb76ce06c11352600375ee85aa', 'ADIsHamburgerSurface380': 'ca773407fdd3a70b32965de2ad095cc4801fe9f40adfd634b46fdf68c530c91e', 'ADIsCategoryArtwork379': '169f817f64692a54f71b1e83ea88ee81da19581ce910524d6a78cfe808ebe0ec', 'ADRestoreCategoryArtwork379': '36b98bb888a5c758f519935830fd75c372c43e12994495e1d75ff13c05c043f0', 'ADInvertRNSVG': '96e465da0f838d56a25c391e1c39217358bab0836430b72d657717427302a67c', 'ADInvertRNSVGApply': '6156fd8770a02dcee9c70e3c8c226934457b3e03834f33c2907137dee0e07bc4', 'ADWTLocalSection365': 'a672b911237022ce15d41ab06a6439ba1429015670f27d02201561ea57614a33', 'ADWTCarouselSection384': '3cbf4ef20a2bea3f96d0e74099e940e05b1ad0a865c0cb20e576288258265610', 'ADWTProductPeers388': 'bb0f4f1e8be49de98907c7a23108beb224ff80bdcc0f9a46c67c29dacfa8573a', 'ADWTNativeContext': 'f6698e48714e080df541a10d59c160473d02587b02b359c20fd5deaf84e42fbe', 'ADApplyNativeWhiteTameView': '774f9eb053b4eb323227627d5c9f49d0a5ec5e83bf8375a143ba4e525f0ce47e', 'ADPrimeNativeWhiteTame363': '24f48855a2993024f9b5d2bafdc858c8ad84a0c04726e521054dce7cdbd7565f', 'RNSVGSvgView_hook': '173e758c09313fac2aa46b4261d853e1de7353e582cf32f2221f07ad409da423', 'RCTUIImageViewAnimated_layout': '297be4d952733561e5f40126b9f27f983c5e63102a8a645b3ebecd6f9c6c810e', 'function cartChrome379(){': '96b2fb5ec541165fffd65edf139b91748a406c6f72ba2076a09c8c58a64619f0', 'function cartChrome382(){': 'e6f6c8d03eb62bae3faaded467e047458cfc534b2e206886f84a8fb7fe467b73', 'cart_css_lines': '6cd55355c442d60de8d7066911af5c95292acd7f7d1f46ad1ab9513eb6ecf56a'}

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
    'ADApplyNativeWhiteTameView','ADPrimeNativeWhiteTame363']:
    items[name]=brace_block(r'^static[^\n]*\b'+re.escape(name)+r'\s*\([^\n]*\)\s*\{',name)
items['RNSVGSvgView_hook']=hook_block('RNSVGSvgView')
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

if bad:
    print('ERROR: a user-confirmed-good frozen surface changed.')
    print('Do not update expected hashes merely to bypass this gate.')
    sys.exit(1)
print('PASS: Alexa, Hamburger, Cart, and Home video frozen surfaces are unchanged.')
