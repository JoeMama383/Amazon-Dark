"""v7.619: keep legacy probe handoff contract while using installed runtime version."""
from pathlib import Path
import os
import subprocess
import tempfile
import time
import tarfile

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / 'scripts/ui-probe.sh').read_text()
assert 'VER=7.619' in S
assert 'CUR=${VER#7.}' in S  # frozen v7.392 source handoff contract
assert 'if [ "$RUNTIME_VER" != "$VER" ]; then\n  CUR=${RUNTIME_VER#7.}\nfi' in S
assert 'NAME=AmazonDark-v$RUNTIME_VER' in S
assert '[ "$rv" -le "$CUR" ]' in S
subprocess.run(['sh', '-n', str(ROOT/'scripts/ui-probe.sh')], check=True)


def check(version):
    with tempfile.TemporaryDirectory() as td:
        base=Path(td)
        docs=base/'Containers/Data/Application/TARGET/Documents'
        docs.mkdir(parents=True)
        shared=base/'shared'; shared.mkdir()
        bindir=base/'bin'; bindir.mkdir()
        fake=bindir/'dpkg-query'
        fake.write_text('#!/bin/sh\necho '+version+'~fake-installed\n')
        fake.chmod(0o755)
        name='AmazonDark-v'+version
        fn=name+'-ui-full-probe-20261010-100000-001-r1.txt'
        (docs/fn).write_text('FULL EVIDENCE\n================ END RUN ================\n')
        (docs/(name+'-ui-full.state')).write_text(f'completed {int(time.time())} {fn}\n')
        env={**os.environ,
             'AD_UI_ROOT':str(base),
             'AD_UI_CONTAINERS':str(base/'Containers/Data/Application'),
             'AD_UI_SHARED':str(shared),
             'PATH':str(bindir)+':'+os.environ['PATH']}
        r=subprocess.run(['sh',str(ROOT/'scripts/ui-probe.sh'),'export','full'],text=True,capture_output=True,env=env,timeout=20)
        assert r.returncode==0,(version,r.stdout,r.stderr)
        assert 'v'+version in r.stdout
        tars=list(shared.glob('*.tar'))
        assert len(tars)==1
        with tarfile.open(tars[0]) as t:
            manifest=t.extractfile('./manifest.txt').read().decode()
            assert 'AmazonDark v'+version in manifest
            assert t.extractfile('./'+fn).read().decode().startswith('FULL EVIDENCE')
        if version!='7.619':
            assert 'installed package' in r.stderr and 'v7.619' in r.stderr


check('7.619')
check('7.615')
print('PASS: v7.619 legacy CUR contract + current/older installed runtime FULL TAR export')
