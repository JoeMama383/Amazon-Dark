from pathlib import Path
import shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / 'src/Tweak.xm').read_text()

# v7.479 failed in Theos because this was a chained Objective-C message send
# without the outer '['. Keep the exact production block syntax-checked before CI build.
r0 = S.index('static NSString *ADReturnsThemeJS7480')
r1 = S.index('static long gADCoreWebJSStrength7271', r0)
p0 = S.index('static NSString *ADPDPProbeBackedFixesJS7458', r1)
p1 = S.index('static NSString *ADCoreWebJS7271', p0)
block = S[r0:r1] + '\n' + S[p0:p1]
assert 'return [[NSString stringWithFormat:' in block
assert '] stringByAppendingString:ADReturnsThemeJS7480()];' in block
assert 'return [NSString stringWithFormat:' not in block

clangxx = shutil.which('clang++')
assert clangxx, 'clang++ is required for the Objective-C++ syntax preflight'
prelude = r'''
#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))
typedef double CGFloat;
@interface NSString
+ (id)stringWithUTF8String:(const char*)s;
+ (id)stringWithFormat:(id)format, ...;
- (id)stringByAppendingString:(id)s;
@end
struct ADPrefs { int whiteTame; int whiteTameStrength; };
static ADPrefs gP;
'''
with tempfile.TemporaryDirectory() as td:
    mm = Path(td) / 'returns_pdp_preflight.mm'
    mm.write_text(prelude + block + '\n')
    subprocess.run([
        clangxx, '-x', 'objective-c++', '-std=gnu++98', '-fsyntax-only',
        '-I', str(ROOT / 'src'), str(mm)
    ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# Camera repair must extend the new full-screen family without repainting the
# historical allow-all-CAMERA checkbox that v7.409 intentionally preserved.
for token in (
    'ADPermissionFullscreenCheckbox7480',
    'fullscreen-inflight-animated-view',
    'fullscreen-inflight-prompt-dismiss-button',
    'fullscreen-inflight-prompt-allow-button',
    'permission-icon-camera',
    'fullscreen-feature-content-icon',
    'fullscreen-inflight-link-to-dashboard-icon',
):
    assert token in S, token
assert 'if(ADPermissionCameraCheckbox7408(v))return nil;' in S
assert 'if(ADPermissionFullscreenCheckbox7480(v))return ADMenuButtonFill7255();' in S
assert '%orig(24.0);' in S
assert len(S.encode()) < 856000

print('PASS: v7.480 preflights the exact v7.479 Objective-C++ failure and preserves legacy/new Camera checkbox ownership')
