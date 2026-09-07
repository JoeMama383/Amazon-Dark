"""Regression for v7.339's Actions compile failure, plus exact JS byte identity.

Compile the actual shipped include, not an imitation, in C99 and C++98. Execute
both outputs and require exactly the inherited v7.346 JavaScript probe bytes.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_SHA256 = "01b809ef43f3b970d8eda61468db6d8bad693dd1bc36d424fd0b01ebe48b270f"


def main():
    inc = ROOT / "src/ADSkeletonProbe7339.js.inc"
    encoded = inc.read_text()
    source = ''.join(json.loads(line) for line in encoded.splitlines()).encode()
    assert hashlib.sha256(source).hexdigest() == PAYLOAD_SHA256, "Probe behavior changed"
    assert 'R"AD7339JS(' not in encoded
    with tempfile.TemporaryDirectory(prefix="ad-probe-embedding-") as tmp:
        tmp = Path(tmp)
        bridge = tmp / "bridge.c"
        bridge.write_text(
            '#include <stdio.h>\nstatic const char script[] =\n'
            '#include "ADSkeletonProbe7339.js.inc"\n;\n'
            'int main(void){return fwrite(script,1,sizeof(script)-1,stdout)==sizeof(script)-1?0:1;}\n')
        for compiler, language, standard in [('cc', 'c', 'c99'), ('c++', 'c++', 'gnu++98')]:
            output = tmp / standard
            subprocess.run([compiler, '-x', language, '-std=' + standard,
                            '-Wall', '-Wextra', '-Werror', '-I', str(inc.parent),
                            str(bridge), '-o', str(output)], check=True)
            assert subprocess.check_output([str(output)]) == source, standard
            print(f"PASS: shipped include compiles in {standard}; emitted JS bytes equal inherited v7.346 payload")

        # Reject the exact former representation in the old dialect. Without this
        # negative control, a default-modern compiler could conceal the regression.
        bad = tmp / 'raw.cpp'
        bad.write_text('const char *script=R"AD7339JS(' + source.decode() + ')AD7339JS";\n')
        failed = subprocess.run(['c++', '-std=gnu++98', '-fsyntax-only', str(bad)], capture_output=True)
        assert failed.returncode != 0, "Test compiler did not reject old raw-string syntax"
        print("PASS: C++98 negative control rejects the failed v7.339 raw-string wrapper")

    native = (ROOT / 'src/ADSkeletonProbe7339.h').read_text()
    control = (ROOT / 'scripts/skeleton-probe.sh').read_text()
    assert 'NSDocumentDirectory,NSUserDomainMask' in native
    assert '@"/var/mobile/' not in native
    assert 'AmazonDark-v7.354-probe.arm' in native
    assert 'AD_PROBE_NAME=AmazonDark-v7.354' in control
    print("PASS: native capture uses app Documents; v7.354 helper identity agrees")



if __name__ == '__main__':
    main()
