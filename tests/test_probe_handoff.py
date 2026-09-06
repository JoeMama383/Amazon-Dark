"""Run the shipped phone helper with actual files/tar and emulated plist/package tools.

Tests the boundary that failed on the phone: arm in Amazon's own container,
export those exact files, recover old paths, and deliver diagnostics on failure.
No iPhone runtime or successful UIKit capture is simulated by these tests.
"""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'scripts/skeleton-probe.sh'
VERSION='7.341~container-capture-startup-diagnostics'

with tempfile.TemporaryDirectory(prefix='ad-probe-handoff-') as temp:
    root=Path(temp);mobile=root/'mobile';containers=mobile/'Containers/Data/Application'
    amazon=containers/'AMAZON';other=containers/'OTHER';docs=root/'shared Documents';docs.mkdir()
    for p,bid in [(amazon,'com.amazon.Amazon'),(other,'com.example.other')]:
        p.mkdir(parents=True)
        (p/'.com.apple.mobile_container_manager.metadata.plist').write_bytes(plistlib.dumps({'MCMMetadataIdentifier':bid},fmt=plistlib.FMT_BINARY))
    bin=root/'bin';bin.mkdir()
    plutil=bin/'plutil'
    plutil.write_text('''#!/usr/bin/env python3
import json,os,plistlib,sys
args=sys.argv[1:];data=plistlib.load(open(args[-1],'rb'));style=os.environ.get('AD_PLUTIL_STYLE','extract')
if args[0]=='-extract' and style=='extract':print(data[args[1]])
elif args[0]=='-convert' and style in ('extract','xml'):sys.stdout.buffer.write(plistlib.dumps(data))
elif args[0]=='-p' and style=='pretty':print(json.dumps(data,indent=2))
else:sys.exit(1)
''');plutil.chmod(0o755)
    dpkg=bin/'dpkg-query'
    dpkg.write_text('''#!/usr/bin/env python3
import os,sys
v=os.environ.get('AD_INSTALLED','7.341~container-capture-startup-diagnostics')
print(('com.joemama383.amazondark ' if '${Package}' in ' '.join(sys.argv) else '')+v,end='')
''');dpkg.chmod(0o755)
    env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],AD_PROBE_ROOT=str(mobile),AD_PROBE_CONTAINERS=str(containers),AD_PROBE_DOCS=str(docs))
    def run(*args,ok=True,**extra):
        r=subprocess.run(['sh',str(HELPER),*args],env=dict(env,**extra),text=True,capture_output=True)
        assert (r.returncode==0)==ok,(args,r.stdout,r.stderr)
        return r.stdout+r.stderr
    arm=amazon/'Documents/AmazonDark-v7.341-probe.arm'
    for style in ['extract','xml','pretty']:
        run('arm','both',AD_PLUTIL_STYLE=style)
        assert arm.read_text().split()[1]=='both'
        assert not (other/'Documents').exists()
        run('disarm')
        assert not arm.exists()
    run('arm','both',ok=False,AD_INSTALLED='7.340~v7309-portable-skeleton-probe')
    assert not arm.exists()
    run('arm','unknown',ok=False)
    assert not arm.exists()
    text=run('export')
    assert 'No app capture ran' in text
    archive=sorted(docs.glob('*.tar.gz'))[-1]
    with tarfile.open(archive) as t:
        report=t.extractfile('./diagnostic-status.txt').read().decode()
        assert VERSION in report and 'Amazon container matches: 1' in report
    run('arm','launch')
    assert arm.read_text().split()[1]=='launch'
    log=amazon/'Documents/AmazonDark-v7.341-skeleton-1-77-launch.jsonl'
    log.write_text('{"event":"SESSION_START","label":"launch"}\n')
    receipt=amazon/'Documents/AmazonDark-v7.341-probe-status.json'
    receipt.write_text(json.dumps({'reason':'capture-started','version':VERSION}))
    old=mobile/'AmazonDark-v7.340-skeleton-1-55-both.jsonl';old.write_text('old capture\n')
    sb=mobile/'AmazonDark-v7.338-launch-sb-probe.txt';sb.write_text('snapshot.dark\n')
    unrelated=other/'Documents';unrelated.mkdir()
    (unrelated/log.name).write_text('MUST NOT EXPORT')
    status=run('status');assert 'SESSION_START' in status and 'capture-started' in status
    text=run('export');assert 'Exported 2 app capture(s)' in text
    archive=Path(text.splitlines()[1])
    with tarfile.open(archive) as t:
        assert t.extractfile('./AMAZON/'+log.name).read()==log.read_bytes()
        assert t.extractfile('./'+old.name).read()==old.read_bytes()
        assert t.extractfile('./launch-springboard-last4MiB.txt').read()==sb.read_bytes()
        assert not any('OTHER' in m.name for m in t.getmembers())
    assert not arm.exists() and log.exists()
    # No container metadata: export still carries a report instead of dead-ending.
    missing=root/'missing';missing.mkdir()
    text=run('export',AD_PROBE_CONTAINERS=str(missing))
    archive=Path(text.splitlines()[1])
    with tarfile.open(archive) as t:
        assert 'Amazon container matches: 0' in t.extractfile('./diagnostic-status.txt').read().decode()
    print('PASS: extract/XML/pretty plist discovery; Amazon-only arming; version/invalid-mode guards')
    print('PASS: real tar exports captures, receipts and SB logs; recovers old paths; disarms; preserves logs')
    print('PASS: missing capture/container still exports actionable status; unrelated app files excluded')
