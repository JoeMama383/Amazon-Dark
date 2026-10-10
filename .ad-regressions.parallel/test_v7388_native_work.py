"""Execute the production preference planner and guard native optimization scope.

These tests do not simulate UIKit rendering or claim device performance.
"""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, tempfile
from payload_source import TOKEN

ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()

def native_block(source,name):
    m=re.search(r'(?m)^static[^\n;{}]*\b'+re.escape(name)+r'\([^;{}]*\)\s*\{',source)
    assert m,name
    tokens={t.start():t.end() for t in TOKEN.finditer(source,m.end())}
    depth=1;i=m.end()
    while depth:
        if i in tokens:i=tokens[i];continue
        depth+=(source[i]=='{')-(source[i]=='}');i+=1
    return source[m.start():i]

# Reuse the actual C data structure, flags and planner; no copied planner model.
prefs=re.search(r'typedef struct \{[^{}]*\} ADPrefs;',S)[0]
flags=re.search(r'enum \{ ADPrefsFloors7388=[^;]*;',S)[0]
planner=native_block(S,'ADPreferenceChanges7388')
cc=shutil.which('cc') or shutil.which('clang')
if cc:
    with tempfile.TemporaryDirectory(prefix='ad-prefs-') as td:
        td=Path(td);c=td/'prefs.c';exe=td/'prefs'
        c.write_text('#include <assert.h>\n#include <stdio.h>\ntypedef int BOOL;\n'
            '#define MIN(a,b) ((a)<(b)?(a):(b))\n#define MAX(a,b) ((a)>(b)?(a):(b))\n'
            +prefs+'\n'+flags+'\n'+planner+r'''
static ADPrefs p(unsigned bits,long strength){
    ADPrefs v={!!(bits&1),!!(bits&2),!!(bits&4),!!(bits&8),!!(bits&16),!!(bits&32),strength};return v;
}
int main(void){
    /* No-op notifications and relaunch-only options must never refresh a webview. */
    for(unsigned bits=0;bits<64;bits++){
        assert(ADPreferenceChanges7388(p(bits,45),p(bits,45))==0);
        assert(ADPreferenceChanges7388(p(bits,45),p(bits^16,45))==0);
        assert(ADPreferenceChanges7388(p(bits,45),p(bits^32,45))==0);
        if(!(bits&1))assert(ADPreferenceChanges7388(p(bits,0),p(bits^62,100))==0);
    }
    /* Expected refreshes: floor=1, promotion=2, TWB=4, privacy=8. */
    struct {unsigned from,to;long oldStrength,newStrength;unsigned expected;} cases[]={
        {0,1,45,45,1}, {1,0,45,45,0}, {0,15,45,45,15}, {15,0,45,45,14},
        {1,5,45,45,2}, {5,1,45,45,2}, {1,9,45,45,8}, {9,1,45,45,8},
        {1,3,45,45,4}, {3,1,45,45,4}, {3,3,45,100,4}, {1,1,45,100,0},
        {3,3,101,200,0}, {3,3,-99,0,0}, {3,3,0,1,4}, {3,3,100,99,4},
        {14,15,45,45,15}, {15,14,45,45,14}, {9,13,45,45,2}, {13,9,45,45,2},
        {11,11,45,60,4}, {11,9,45,60,4}, {8,9,45,45,9}, {9,8,45,45,8}
    };
    for(unsigned i=0;i<sizeof(cases)/sizeof(cases[0]);i++)
        assert(ADPreferenceChanges7388(p(cases[i].from,cases[i].oldStrength),p(cases[i].to,cases[i].newStrength))==cases[i].expected);
    puts("PASS: production preference planner handles no-op, independent toggles, disable/re-enable and clamped strengths");
}
''')
        subprocess.run([cc,'-std=c99','-Wall','-Wextra','-Werror',str(c),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True)
elif os.environ.get('AD_STRICT_VALIDATE')=='1':
    raise AssertionError('A C compiler is required in strict mode')
else:print('SKIP: compiled preference planner unavailable on this device; strict CI enforces it')

callback=native_block(S,'ADPrefsChanged')
assert callback.index('if(![NSThread isMainThread])')<callback.index('ADPrefs before=gP;')
for flag,call in [('Floors','ADApplyAllFloors'),('Promotion','ADRefreshPromotionState611'),('TWB','ADRefreshWebTWBPrefs791')]:
    assert f'if(changes&ADPrefs{flag}7388){call}();' in callback
assert callback.index('if(!(changes&ADPrefsPrivacy7388))return;')<callback.index('ADCompilePrivacyContentRules7117();')
assert 'ADRefreshRuntimeState7115(YES)' not in callback

# Exact scope/palette functions and checkout transformation retain their prior bodies.
golden=json.loads((ROOT/'tests/v7387_native_baseline.json').read_text())
for name,expected in golden.items():
    body=native_block(S,name).replace('v7.388','v7.387')
    if name=='ADOLEDCheckoutAppearance7375':
        body=body.replace('        if(ADCheckoutAppearanceReady7388(source))return source;\n','')
    if name=='ADReactSurface7226':
        body=body.replace('[aid isEqualToString:@"me"]','[n.accessibilityIdentifier isEqualToString:@"me"]')
    assert hashlib.sha256(body.encode()).hexdigest()==expected,name

# An appearance is reusable only if every owned visual field matches now.
ready=native_block(S,'ADCheckoutAppearanceReady7388')
for token in ['!a.backgroundEffect','!a.backgroundImage','!a.shadowImage','backgroundImageContentMode==UIViewContentModeScaleToFill',
              '[a.backgroundColor isEqual:ADOLED()]','[a.shadowColor isEqual:[UIColor clearColor]]',
              'a.titleTextAttributes[NSForegroundColorAttributeName]','a.largeTitleTextAttributes[NSForegroundColorAttributeName]',
              'a.buttonAppearance','a.backButtonAppearance','a.doneButtonAppearance']:
    assert token in ready,token
button=native_block(S,'ADCheckoutWhiteButton7388')
for state in ['normal','highlighted','disabled','focused']:assert 'button.'+state in button
assert 'attrs.count==1' in native_block(S,'ADCheckoutWhiteState7388')
nav=native_block(S,'ADCheckoutNavAppearances7375')
assert nav.index('ADCheckoutAppearanceReady7388')<nav.index('[CATransaction begin]')
assert '@finally' in nav and nav.index('@finally')<nav.index('[CATransaction commit]')
assert 'gADCheckoutAppearanceWrite7375=previousWrite' in nav
hooks=S[S.index('%hook UINavigationBar'):S.index('%hook CXIStoreModesBottomNavToolbar')]
assert '- (void)layoutSubviews' not in hooks
for setter in ['Standard','ScrollEdge','Compact','CompactScrollEdge']:
    assert '- (void)set'+setter+'Appearance:' in hooks

# Retain hydration traversal bounds and distinguish authored additions from our backing.
glow=S[S.index('%hook GlowIngressView'):S.index('%end',S.index('%hook GlowIngressView'))]
added=glow[glow.index('- (void)didAddSubview:'):glow.index('- (void)setBackgroundColor:')]
assert added.index('%orig;')<added.index('kADGlowFloorSentinel7192')<added.index('ADOwnGlowIngress7140(self)')
assert '- (void)layoutSubviews' in glow and '- (void)didMoveToWindow' in glow
for name in ['ADOwnGlowIngress7140','ADInstallGlowFloorTree7141']:
    assert 'seen<96' in native_block(S,name)
assert S.count('ADInstallGlowFloorTree7141(root)')==1
assert 'ADExactGlowIngress7140(root)' in native_block(S,'ADOwnGlowIngress7140')
floor=native_block(S,'ADInstallGlowFloorView7192')
assert 'if(!CGRectEqualToRect(floor.frame,host.bounds))' in floor
assert 'if(floor.hidden)' in floor and 'if(floor.alpha!=1.0)' in floor
assert 'host.subviews.firstObject!=floor' in floor
assert '||label.attributedText.length' in native_block(S,'ADOwnGlowIngress7140')

# Copies occur only on missing protocol; the exact class/order and disabled path survive.
privacy=native_block(S,'ADPrivacyInstallProtocolOnConfig7117')
assert privacy.index('containsObject:')<privacy.index('mutableCopy')<privacy.index('cfg.protocolClasses=a')
assert '[a insertObject:[ADPrivacyURLProtocol7117 class] atIndex:0]' in privacy
hook=S[S.index('- (void)setProtocolClasses:'):S.index('%end',S.index('- (void)setProtocolClasses:'))]
assert hook.index('containsObject:')<hook.index('mutableCopy')
assert '%orig(protocolClasses);' in hook
print('PASS: native scope/palette goldens, Search hydration/re-entry guard, checkout current-state checks and exception cleanup')
