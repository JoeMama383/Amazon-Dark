from pathlib import Path
import shutil, subprocess, tempfile
from payload_source import block as function_block

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / 'src/Tweak.xm').read_text()

# v7.479 failed in Theos because this was a chained Objective-C message send
# without the outer '['. Keep the exact production block syntax-checked before CI build.
# Extract complete function definitions and their real dependencies. The old
# contiguous slice included ADNewMenus but omitted Seller/Pharmacy definitions,
# producing undeclared-function errors in this standalone fixture only.
returns = function_block(S, 'ADReturnsThemeJS7480')
pdp = function_block(S, 'ADPDPProbeBackedFixesJS7458')
block = returns + '\n' + pdp
names = ('ADPharmacyMediaJS7563', 'ADSellerMessagingThemeJS7562',
         'ADReturnsThemeJS7480', 'ADNewMenusJS7482', 'ADPDPProbeBackedFixesJS7458')
functions = [function_block(S, name) for name in names]
compile_block = '\n'.join(sorted(functions, key=S.index))
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
    mm.write_text(prelude + compile_block + '\n')
    result = subprocess.run([
        clangxx, '-x', 'objective-c++', '-std=gnu++98', '-fsyntax-only',
        '-I', str(ROOT / 'src'), str(mm)
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert result.returncode == 0, result.stdout + result.stderr

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

print('PASS: v7.480 preflights the exact v7.479 Objective-C++ failure and preserves legacy/new Camera checkbox ownership')
