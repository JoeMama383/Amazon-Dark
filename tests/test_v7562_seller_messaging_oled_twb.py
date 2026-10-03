"""v7.562: route-gated Seller Messaging Assistant OLED + product-media TWB."""
from pathlib import Path
import codecs, re, shutil, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.562~seller-messaging-oled-twb' in C
assert '#define AD_VERSION "v7.562-seller-messaging-oled-twb"' in T

start=T.index('static NSString *ADSellerMessagingThemeJS7562(void)')
end=T.index('static NSString *ADReturnsThemeJS7480', start)
seg=T[start:end]

# Ownership must remain strict to the known Seller Messaging route/referrer family.
assert 'contact-seller\\\\/contact-seller' in seg
assert "gate.test(p)&&!gate.test(r)" in seg
assert "ad7562-seller-messaging" in seg

# Structural coloring follows the established OLED/neutral-control algorithm.
assert 'html,body,#a-page{background:#000!important;color:#e8e6e3!important;color-scheme:dark!important;}' in seg
assert '[class*=bubble],[class*=Bubble]' in seg and 'background:#303335!important' in seg
assert 'body :is(button,.a-button,.a-button-inner,a[class*=button],a[class*=Button])' in seg
assert 'border-color:#747a7c!important' in seg

# Neutral copy is lightened while authored interactive/dynamic colors keep currentColor.
assert ':not(:where(a *)):not(:where(button *)):not(:where([role=button] *))' in seg
assert 'body :is(a,.a-color-link,.a-link-normal,[role=button]),body :is(a,.a-color-link,.a-link-normal,[role=button]) *{-webkit-text-fill-color:currentColor!important;}' in seg
assert 'a[class*=button],a[class*=Button]) *{-webkit-text-fill-color:currentColor!important;}' in seg

# Product media uses the existing configurable TWB strength, marked by finite image geometry.
assert "d.images||[]" in seg
assert 'Math.min(a.length,120)' in seg
assert 'q.width>=64&&q.height>=64&&q.width<=320&&q.height<=320' in seg
assert "data-ad7562-seller-product-image" in seg
assert 'filter:brightness(%.3f)!important;-webkit-filter:brightness(%.3f)!important' in seg
assert '/(logo|avatar|icon|sprite|smile)/i' in seg

# Route-local finite event work only: no production DOM walker or recurring machinery.
for bad in ('MutationObserver','setInterval(','setTimeout(','requestAnimationFrame(','querySelectorAll(\'*\')',"addEventListener('scroll'",'dispatch_after'):
    assert bad not in seg, bad
assert "window.addEventListener('load',mark,{once:true})" in seg

# Core golden concatenation stays frozen; the new route program is appended inside the existing
# ADNewMenus expansion point instead of changing ADCoreWebJS7271's historical hash contract.
assert 'return [base stringByAppendingString:ADSellerMessagingThemeJS7562()];' in T
assert 'ADAddressManagementJS7412()] stringByAppendingString:ADNewMenusJS7482()' in T
assert '.cs-help-v4 .cs-help-content article.help-content .cs-help-note{background:#000!important;}' in T
assert 'section#pop.layout__background:has(.item-view__qty-large)' in T
assert '.a-box.a-alert.a-alert-success' in (ROOT/'src/ADReturnsTheme7480.js.inc').read_text()

# Compile the exact new Objective-C++ helper independently so a handoff cannot pass Python-only
# assertions while failing Theos on literal/message syntax.
clangxx=shutil.which('clang++')
assert clangxx, 'clang++ is required for v7.562 Objective-C++ syntax preflight'
prelude=r'''
#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))
typedef double CGFloat;
@interface NSString
+ (id)stringWithFormat:(id)format, ...;
@end
struct ADPrefs { int whiteTame; int whiteTameStrength; };
static ADPrefs gP;
'''
with tempfile.TemporaryDirectory() as td:
    mm=Path(td)/'seller_messaging_7562.mm'
    mm.write_text(prelude+seg+'\n')
    subprocess.run([clangxx,'-x','objective-c++','-std=gnu++98','-fsyntax-only',str(mm)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)

# Reconstruct the emitted JavaScript at a representative TWB strength and require Node syntax.
fmt=seg[seg.index('return [NSString stringWithFormat:'):seg.rindex(',f,f,gP.whiteTame?1:0]')]
parts=re.findall(r'@?"((?:\\.|[^"\\])*)"',fmt)
js=''.join(codecs.decode(part,'unicode_escape') for part in parts)
js=js.replace('%.3f','0.684',2).replace('%d','1',1)
assert not re.search(r'%[0-9.]*[dfs]',js)
node=shutil.which('node')
assert node, 'node is required for v7.562 emitted-JS syntax preflight'
with tempfile.TemporaryDirectory() as td:
    fp=Path(td)/'seller-messaging-7562.js'
    fp.write_text(js)
    subprocess.run([node,'--check',str(fp)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)

print('PASS: v7.562 route-gated Seller Messaging OLED/gray controls, dynamic-color preservation, bounded product-media TWB, ObjC++ syntax, and emitted JS parse')
