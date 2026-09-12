from pathlib import Path
import subprocess, tempfile, textwrap
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
A=(ROOT/'src/ADSponsored.m').read_text()
H=(ROOT/'src/ADSponsored.h').read_text()
M=(ROOT/'Makefile').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()

assert 'Version: 7.413~address-location-compile-fix' in C
assert '#define AD_VERSION "v7.413-address-location-compile-fix"' in S
assert '#import "ADSponsored.h"' in S
assert '#import "ADSponsored.h"' in A
assert '#ifdef __cplusplus' in H
assert 'extern "C" {' in H
assert 'NSString *ADKillerSponsoredJS7384(void);' in H
assert 'NSString *ADKillerSponsoredJS7384(void)' in A
assert 'AmazonDark_FILES      = src/Tweak.xm src/ADSponsored.m' in M
# The bare declaration that caused C++ name mangling must not return to Tweak.xm.
assert 'extern NSString *ADKillerSponsoredJS7384(void);' not in S

# Prove the linkage pattern with the host C/C++ toolchain without needing iOS SDK headers.
with tempfile.TemporaryDirectory(prefix='ad-c-linkage-') as td:
    d=Path(td)
    (d/'api.h').write_text(textwrap.dedent('''\
        #pragma once
        #ifdef __cplusplus
        extern "C" {
        #endif
        int ADKillerSponsoredJS7384(void);
        #ifdef __cplusplus
        }
        #endif
    '''))
    (d/'impl.c').write_text('#include "api.h"\nint ADKillerSponsoredJS7384(void){return 7;}\n')
    (d/'caller.cc').write_text('#include "api.h"\nint main(){return ADKillerSponsoredJS7384()==7?0:1;}\n')
    c=subprocess.run(['clang','-c',str(d/'impl.c'),'-o',str(d/'impl.o')],capture_output=True,text=True)
    assert c.returncode==0,c.stderr
    c=subprocess.run(['clang++','-c',str(d/'caller.cc'),'-o',str(d/'caller.o')],capture_output=True,text=True)
    assert c.returncode==0,c.stderr
    c=subprocess.run(['clang++',str(d/'caller.o'),str(d/'impl.o'),'-o',str(d/'linktest')],capture_output=True,text=True)
    assert c.returncode==0,c.stderr
    c=subprocess.run([str(d/'linktest')],capture_output=True,text=True)
    assert c.returncode==0,(c.stdout,c.stderr)
print('PASS: Objective-C++/Objective-C sponsored boundary is explicitly C-linkage compatible')
