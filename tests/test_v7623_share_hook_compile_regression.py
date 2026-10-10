"""Prevent v7.622's UIActivityViewController Logos directive from entering the
v7.597 plain Objective-C++ fixture. Test the exact actual failing fixture.
"""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[1]
src=(root/'src/Tweak.xm').read_text()
control=(root/'layout/DEBIAN/control').read_text()
assert 'Version: 7.623~alexa-ci-compile-repair' in control
assert '#define AD_VERSION "v7.623-alexa-ci-compile-repair"' in src
share=src.index('%hook UIActivityViewController')
live=src.index('static BOOL ADCXINeutralButton7597(')
ctor=src.index('%ctor {',live)
assert share<live<ctor, 'UIKit share Logos directives must not contaminate native mm fixture'
assert src.count('%hook UIActivityViewController')==1
share_body=src[share:live]
assert 'self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;' in share_body
assert 'if(gP.enabled)' in share_body
native=src[live:ctor]
assert '%hook CXIHighlightableTouchAreaButton' in native
assert '%hook UIActivityViewController' not in native
# Run the same native extraction, clang++ compile, and actual Live owner tests
# whose failure triggered this release. Do not mock or weaken their assertions.
runpy.run_path(str(root/'tests/test_v7597_live_thankyou.py'),run_name='__main__')
print('PASS v7.623: original v7.597 native Objective-C++ fixture compiles; UIKit hook isolated')
