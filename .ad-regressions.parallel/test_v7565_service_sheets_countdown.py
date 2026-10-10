from pathlib import Path
import json,subprocess,tempfile,shutil
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
N=(R/'src/ADServiceSheets7565.inc').read_text()
I=(R/'src/ADServiceSheetImages7565.inc').read_text()
clang=shutil.which('clang++')
assert clang,'Clang is required for the native sheet syntax preflight'
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'sheets.mm'
 p.write_text('#include "service_sheet_uikit_stubs.h"\n#include "ADServiceSheets7565.inc"\n#include "ADServiceSheetImages7565.inc"\n')
 c=subprocess.run([clang,'-x','objective-c++','-std=gnu++98','-fsyntax-only','-Wno-objc-root-class','-I',str(R/'src'),'-I',str(R/'tests/fixtures'),str(p)],capture_output=True,text=True)
 assert c.returncode==0,c.stdout+c.stderr
 # Execute the production premultiplied pixel policy: gray/black ink becomes light,
 # saturated brand colors remain identical, transparent pixels remain transparent.
 p=Path(d)/'pixels.c'
 p.write_text('''#include "ADServiceRaster7565.h"
#include <assert.h>
int main(void){
unsigned char black[]={0,0,0,255},blue[]={0,120,255,255},alpha[]={20,20,20,100},clear[]={0,0,0,0},floor[]={255,255,255,255};
ADServiceLogoPixel7565(black);assert(black[0]==232&&black[3]==255);
ADServiceLogoPixel7565(blue);assert(blue[0]==0&&blue[1]==120&&blue[2]==255);
ADServiceLogoPixel7565(alpha);assert(alpha[0]==90&&alpha[3]==100);
ADServiceLogoPixel7565(clear);assert(clear[0]==0&&clear[3]==0);
ADServiceBannerPixel7565(floor);assert(floor[0]==0&&floor[3]==255);
return 0;}
''')
 out=Path(d)/'pixels'
 subprocess.run(['cc','-I',str(R/'src'),str(p),'-o',str(out)],check=True,capture_output=True)
 subprocess.run([str(out)],check=True)
assert 'pill-bw_health_ai_pill_' in N and 'Find a nearby store' in N
assert 'sheet-inset-view' in N and 'sheet-view' in N
assert 'i<160' in N and 'objc_getAssociatedObject(root,kADServiceSheet7565)' in N
assert 'ADServiceDiscover7565(v,textStorage)' in T
assert 'ADServiceImage7565(self)' in T
assert 'ADEnsureNativeTWBOverlay7270' in I and 'kADServiceLogoPaint7565' in I
for bad in ('MutationObserver','dispatch_after','setInterval','setFrame:','setBounds:','setCornerRadius:'):
 assert bad not in N+I,bad
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
rule=J[J.index('[id^=atf-countdownCard-Text-Timer-Numeric-][class*=_hve-countdown-timer_style_stripeTimerDigit__]'):].split('}',1)[0]
assert 'background:#000!important' in rule and 'color:#fff!important' in rule
assert not any(x in rule for x in ('width:','height:','padding:','border-radius:'))
print('PASS: exact native service-sheet helpers compile; raster color/alpha policy executes; finite hydration, image cache/taming, and countdown geometry contracts retained')
