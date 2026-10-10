"""v7.616: exact installed-runtime capture discovery and screenshot receipt."""
from pathlib import Path
import os, subprocess, tempfile, tarfile
r=Path(__file__).resolve().parents[1]
shell=(r/'scripts/ui-probe.sh').read_text()
source=(r/'src/ADUniversalUIProbe7362.inc').read_text()
workflow=(r/'.github/workflows/build.yml').read_text()
assert 'VER=7.616' in shell
assert 'RUNTIME_VER=${installed%%~*}' in shell
assert 'NAME=AmazonDark-v$RUNTIME_VER' in shell
assert '"$CONTAINERS"/*/Documents/"$NAME"-ui-full.state' in shell
assert 'ADUIRecordScreenshotTrigger7616(); ADCaptureThreeTabProbe7254(@"screenshot");' in source
assert 'AmazonDark-v7.616-ui-trigger.receipt' in source
assert 'ADUIHandleDidBecomeActive7616' in source
assert 'ADUIConsumeFullArm7616' in source
assert 'explicit-foreground-full-arm' in source
assert 'if [ "${2:-}" = full ]; then' in shell
assert 'Actual compiler errors (not trailing ARC warnings)' in workflow
assert 'compile_rc=${PIPESTATUS[0]}' in workflow
subprocess.run(['sh','-n',str(r/'scripts/ui-probe.sh')],check=True)

def run_fixture(installed, capture_version, include_state=True):
    with tempfile.TemporaryDirectory() as td:
        base=Path(td)
        containers=base/'Containers/Data/Application'
        docs=containers/'FAKE-APP-CONTAINER'/'Documents'
        docs.mkdir(parents=True)
        shared=base/'shared';shared.mkdir()
        tools=base/'bin';tools.mkdir()
        cmd=tools/'dpkg-query'
        cmd.write_text('#!/bin/sh\nprintf %s\\n '+repr(installed)+'\n')
        cmd.chmod(0o755)
        stem=f'AmazonDark-v{capture_version}'
        capture=docs/f'{stem}-ui-full-probe-20261009-211500-004-r1.txt'
        capture.write_text('AMAZONDARK FULL SAMPLE\nUI_PROBE_END\n================ END RUN ================\n')
        if include_state:
            import time
            (docs/f'{stem}-ui-full.state').write_text(f'completed {int(time.time())} {capture.name}\n')
        env={**os.environ,'AD_UI_ROOT':str(base),'AD_UI_CONTAINERS':str(containers),'AD_UI_SHARED':str(shared),'PATH':str(tools)+':'+os.environ['PATH']}
        a=subprocess.run(['sh',str(r/'scripts/ui-probe.sh'),'export','full'],text=True,capture_output=True,env=env)
        if include_state:
            assert a.returncode==0,(a.stdout,a.stderr)
            assert f'v{capture_version}' in a.stdout
            tars=list(shared.glob('*.tar'))
            assert len(tars)==1
            with tarfile.open(tars[0]) as t:
                manifest=t.extractfile('./manifest.txt').read().decode()
                assert f'AmazonDark v{capture_version}' in manifest
                assert t.extractfile('./'+capture.name).read().decode().startswith('AMAZONDARK')
        else:
            assert a.returncode!=0
            assert 'No current v' in a.stderr
            assert not list(shared.glob('*.tar'))
        return a.stdout,a.stderr

# An uncompiled helper version must not mask the still-installed live v7.615 probe.
stdout,stderr=run_fixture('7.615~native-live-compile-repair','7.615')
assert 'helper v7.616' in stderr
# On matching current build, an Amazon Documents state is sufficient even when
# the old signed bootstrap receipt and metadata plist cannot be located.
run_fixture('7.616~universal-probe-transport','7.616')
# A stale different-version state is never silently bundled.
stdout,stderr=run_fixture('7.616~universal-probe-transport','7.615',False)
assert 'Other retained FULL state' not in stderr

# A separate screenshot-independent FULL arm must be one-shot and active build only.
with tempfile.TemporaryDirectory() as td:
    base=Path(td); docs=base/'Containers/Data/Application/FAKE-APP-CONTAINER/Documents';docs.mkdir(parents=True)
    (docs/'AmazonDark-v7.616-ui-trigger.receipt').write_text('event=screenshot\n')
    shared=base/'shared';shared.mkdir()
    tools=base/'bin';tools.mkdir()
    cmd=tools/'dpkg-query';cmd.write_text('#!/bin/sh\nprintf %s\\n 7.616~universal-probe-transport\n');cmd.chmod(0o755)
    env={**os.environ,'AD_UI_ROOT':str(base),'AD_UI_CONTAINERS':str(base/'Containers/Data/Application'),'AD_UI_SHARED':str(shared),'PATH':str(tools)+':'+os.environ['PATH']}
    a=subprocess.run(['sh',str(r/'scripts/ui-probe.sh'),'arm','full'],env=env,text=True,capture_output=True)
    assert a.returncode==0,(a.stdout,a.stderr)
    assert 'foreground' in a.stdout
    assert (docs/'AmazonDark-v7.616-ui-full.arm').read_text().startswith('full ')
    assert not (docs/'AmazonDark-v7.616-ui-full.state').exists()
print('PASS v7.616: installed-runtime export, state-only discovery, no historical fallback, real TAR integrity, universal foreground-full fallback, trigger and CI diagnostics')
