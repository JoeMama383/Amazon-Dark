"""Run the actual v7.452 UI helper against disposable filesystem fixtures.

VIEWPORT arming must be passive: it writes a one-shot next-background arm and never
requires a process lookup or SIGUSR2. Export remains current-session and mode-specific.
"""
from pathlib import Path
import json, os, re, subprocess, tarfile, tempfile, time

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'scripts/ui-probe.sh'
version=re.search(r'^Version: ([^\n]+)',(ROOT/'layout/DEBIAN/control').read_text(),re.M)[1]
short=version.split('~')[0];name='AmazonDark-v'+short

with tempfile.TemporaryDirectory(prefix='ad-ui-handoff-') as td:
    root=Path(td);containers=root/'containers';amazon=containers/'AMAZON'/'Documents';other=containers/'OTHER'/'Documents'
    shared=root/'shared Documents';bin=root/'bin'
    for p in [amazon,other,shared,bin]:p.mkdir(parents=True)
    for script,text in {'dpkg-query':'printf "%s" "$AD_TEST_INSTALLED"','plutil':'exit 1','zip':'exit 97'}.items():
        p=bin/script;p.write_text('#!/bin/sh\n'+text+'\n');p.chmod(0o755)
    def receipt(p,bundle,rv=None):
        rv=rv or version
        p.write_text(json.dumps({'bundle':bundle,'event':'PROBE_BOOTSTRAP','version':'v'+rv.replace('~','-')}))
    receipt(other/(name+'-probe-status.json'),'com.example.other')
    env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],AD_UI_ROOT=str(root),AD_UI_CONTAINERS=str(containers),
             AD_UI_SHARED=str(shared),AD_TEST_INSTALLED=version)
    def run(*args,ok=True,**extra):
        r=subprocess.run(['sh',str(HELPER),*args],env=dict(env,**extra),capture_output=True,text=True,timeout=10)
        assert (r.returncode==0)==ok,(args,r.returncode,r.stdout,r.stderr)
        return r.stdout+r.stderr
    arm=amazon/(name+'-ui-viewport.arm')
    receipt(amazon/(name+'-probe-status.json'),'com.amazon.Amazon')
    run('arm',ok=False,AD_TEST_INSTALLED='7.386~old'); assert not arm.exists()
    arm_text=run('arm')
    assert 'next background transition' in arm_text
    assert arm.read_text().startswith('viewport ') and arm.stat().st_mode&0o777==0o600
    assert not (other/arm.name).exists()
    assert 'Viewport next-background arm:' in run('status')
    run('disarm');assert not arm.exists()
    assert 'Viewport next-background arm:' not in run('status')

    # Upgrade receipts locate Amazon before this build writes a new receipt.
    (amazon/(name+'-probe-status.json')).unlink()
    for previous,slug in [('7.400','delivery-instructions-completion'),('7.399','add-address-form-completion'),('7.398','legal-help-completion'),('7.397','checkout-payment-aux-controls'),('7.396','checkout-address-transition-floor-fix'),('7.395','ui-coverage-audit-fix'),('7.394','checkout-address-pickup-help-fix'),('7.393','payment-help-ui-fix'),('7.392','probe-handoff-ci-fix'),('7.391','ui-completion-audit-fix'),('7.390','checkout-ui-completion'),('7.389','checkout-sheet-switcher-fix'),('7.388','native-work-optimization'),('7.387','runtime-css-optimization'),('7.386','sponsored-shell-ownership')]:
        old=amazon/('AmazonDark-v'+previous+'-probe-status.json');receipt(old,'com.amazon.Amazon',previous+'~'+slug)
        run('arm');assert arm.exists();run('disarm');old.unlink()
    bad=amazon/'AmazonDark-v7.391-probe-status.json';receipt(bad,'com.amazon.Amazon','7.390~checkout-ui-completion')
    run('arm',ok=False);assert not arm.exists();bad.unlink()
    receipt(amazon/(name+'-probe-status.json'),'com.amazon.Amazon')

    assert 'exactly one mode' in run('export',ok=False)
    terminal='================ END RUN ================\n'
    full=amazon/(name+'-ui-full-probe-001-r1.txt');full.write_text('FULL\n'+terminal)
    viewport=amazon/(name+'-ui-viewport-probe-001-r1.txt');viewport.write_text('VIEWPORT\n'+terminal)
    partial=amazon/(name+'-ui-full-probe-002-r1.txt');partial.write_text('INCOMPLETE\n')
    (other/full.name).write_text('UNRELATED\n'+terminal)
    now=int(time.time())
    (amazon/(name+'-ui-full.state')).write_text(f'completed {now} {full.name}\n')
    (amazon/(name+'-ui-viewport.state')).write_text(f'completed {now} {viewport.name}\n')

    text=run('export','full'); full_tar=Path(text.strip().splitlines()[-1])
    assert full_tar.parent==shared and full_tar.suffix=='.tar'
    with tarfile.open(full_tar) as z:
        names={n.lstrip('./') for n in z.getnames()}
        assert full.name in names and viewport.name not in names and partial.name not in names and 'manifest.txt' in names

    text=run('export','viewport'); viewport_tar=Path(text.strip().splitlines()[-1])
    assert viewport_tar.parent==shared and viewport_tar.suffix=='.tar'
    with tarfile.open(viewport_tar) as z:
        names={n.lstrip('./') for n in z.getnames()}
        assert viewport.name in names and full.name not in names and 'manifest.txt' in names

    (amazon/(name+'-ui-full.state')).write_text(f'started {now} {partial.name}\n')
    assert 'still running or incomplete' in run('export','full',ok=False)

helper=HELPER.read_text()
assert 'kill -USR2' not in helper and 'find_pid' not in helper
print('PASS: passive next-background VIEWPORT arm, package gate, upgrade discovery, unarmed status, and isolated current-session FULL/VIEWPORT TAR export')
