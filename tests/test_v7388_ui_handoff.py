"""Run the actual UI helper against files and a disposable SIGUSR2 receiver.

Only package/process discovery is stubbed; no Amazon app or UIKit is simulated.
"""
from pathlib import Path
import json, os, re, selectors, subprocess, sys, tempfile

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'scripts/ui-probe.sh'
version=re.search(r'^Version: ([^\n]+)',(ROOT/'layout/DEBIAN/control').read_text(),re.M)[1]
short=version.split('~')[0];name='AmazonDark-v'+short

with tempfile.TemporaryDirectory(prefix='ad-ui-handoff-') as td:
    root=Path(td);containers=root/'containers';amazon=containers/'AMAZON'/'Documents';other=containers/'OTHER'/'Documents'
    shared=root/'shared Documents';bin=root/'bin'
    for p in [amazon,other,shared,bin]:p.mkdir(parents=True)
    for script,text in {
        'dpkg-query':'printf "%s" "$AD_TEST_INSTALLED"',
        'plutil':'exit 1',
        'ps':'printf "%s /fixture/Amazon.app/Amazon\\n" "$AD_TEST_PID"',
        'pgrep':'exit 1',
    }.items():
        p=bin/script;p.write_text('#!/bin/sh\n'+text+'\n');p.chmod(0o755)
    def receipt(p,bundle):p.write_text(json.dumps({'bundle':bundle,'event':'PROBE_BOOTSTRAP','version':'v'+version.replace('~','-')}))
    receipt(other/(name+'-probe-status.json'),'com.example.other')
    child=subprocess.Popen([sys.executable,'-u','-c',
        'import signal\nsignal.signal(signal.SIGUSR2,lambda *_:print("signal",flush=True))\nprint("ready",flush=True)\nwhile True:signal.pause()'],stdout=subprocess.PIPE,text=True)
    sel=selectors.DefaultSelector();sel.register(child.stdout,selectors.EVENT_READ)
    def output(expected):
        assert sel.select(5),'test signal receiver timed out'
        assert child.stdout.readline().strip()==expected
    try:
        output('ready')
        env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],AD_UI_ROOT=str(root),AD_UI_CONTAINERS=str(containers),
                 AD_UI_SHARED=str(shared),AD_TEST_INSTALLED=version,AD_TEST_PID=str(child.pid))
        def run(mode,ok=True,**extra):
            r=subprocess.run(['sh',str(HELPER),mode],env=dict(env,**extra),capture_output=True,text=True,timeout=10)
            assert (r.returncode==0)==ok,(mode,r.returncode,r.stdout,r.stderr)
            return r.stdout+r.stderr
        arm=amazon/(name+'-ui-viewport.arm')
        # The current installed package must be accepted; old packages must not be signalled.
        receipt(amazon/(name+'-probe-status.json'),'com.amazon.Amazon')
        run('arm',ok=False,AD_TEST_INSTALLED='7.386~old')
        assert not arm.exists()
        run('arm');output('signal')
        assert arm.read_text().startswith('viewport ') and arm.stat().st_mode&0o777==0o600
        assert not (other/arm.name).exists()
        assert 'Viewport arm:' in run('status')
        run('disarm');assert not arm.exists()
        assert 'Viewport arm:' not in run('status')  # status must also succeed when unarmed.
        # Upgrade receipts locate Amazon before this build writes a new receipt.
        (amazon/(name+'-probe-status.json')).unlink()
        for previous in ['7.387','7.386']:
            old=amazon/('AmazonDark-v'+previous+'-probe-status.json');receipt(old,'com.amazon.Amazon')
            run('arm');output('signal');assert arm.exists();run('disarm');old.unlink()
        receipt(amazon/(name+'-probe-status.json'),'com.amazon.Amazon')
        assert 'v'+short in run('export',ok=False)
        terminal='================ END RUN ================\n'
        full=amazon/(name+'-ui-full-probe-001-r1.txt');full.write_text('FULL\n'+terminal)
        viewport=amazon/(name+'-ui-viewport-probe-001-r1.txt');viewport.write_text('VIEWPORT\n'+terminal)
        partial=amazon/(name+'-ui-full-probe-002-r1.txt');partial.write_text('INCOMPLETE\n')
        (other/full.name).write_text('UNRELATED\n'+terminal)
        run('export')
        assert (shared/full.name).read_bytes()==full.read_bytes()
        assert (shared/viewport.name).read_bytes()==viewport.read_bytes()
        assert not (shared/partial.name).exists()
        full.unlink();viewport.unlink()
        assert 'still sweeping' in run('export',ok=False)
    finally:
        child.terminate();child.wait(timeout=5);sel.close();child.stdout.close()
print('PASS: actual viewport arm/SIGUSR2, package gate, upgrade discovery, unarmed status and completed-only full/viewport export')
