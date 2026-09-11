"""Run the shipped phone helper with actual files/tar and emulated plist/package tools.

Tests the boundary that failed on the phone: arm in Amazon's own container,
export those exact files, recover old paths, and deliver diagnostics on failure.
No iPhone runtime or successful UIKit capture is simulated by these tests.
"""
import json
import shutil
import os
from pathlib import Path
import plistlib
import subprocess
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'scripts/skeleton-probe.sh'
VERSION='7.398~legal-help-completion'

with tempfile.TemporaryDirectory(prefix='ad-probe-handoff-') as temp:
    root=Path(temp);mobile=root/'mobile';containers=mobile/'Containers/Data/Application'
    amazon=containers/'AMAZON';other=containers/'OTHER';docs=root/'shared Documents';docs.mkdir()
    for p,bid in [(amazon,'com.amazon.Amazon'),(other,'com.example.other')]:
        p.mkdir(parents=True)
        (p/'.com.apple.mobile_container_manager.metadata.plist').write_bytes(plistlib.dumps({'MCMMetadataIdentifier':bid},fmt=plistlib.FMT_XML))
    bin=root/'bin';bin.mkdir()
    plutil=bin/'plutil'
    plutil.write_text(r'''#!/bin/sh
style=${AD_PLUTIL_STYLE:-extract}; last=""; for a in "$@"; do last=$a; done
value=$(awk '/<key>MCMMetadataIdentifier<\/key>/{take=1;next} take&&/<string>/{s=$0;sub(/^.*<string>/,"",s);sub(/<\/string>.*$/,"",s);print s;exit}' "$last")
case "$1:$style" in
  -extract:extract) printf '%s\n' "$value" ;;
  -convert:extract|-convert:xml) cat "$last" ;;
  -p:pretty) printf '  "MCMMetadataIdentifier" => "%s"\n' "$value" ;;
  *) exit 1 ;;
esac
''');plutil.chmod(0o755)
    # A broken/missing gzip must have no effect on the new export path.
    gzip=bin/'gzip'
    gzip.write_text('#!/bin/sh\nprintf called > "$AD_GZIP_CALLED"\nexit 127\n');gzip.chmod(0o755)
    real_tar=shutil.which('tar');assert real_tar
    tar=bin/'tar'
    tar.write_text('#!/bin/sh\n[ "${AD_TAR_FAIL:-0}" = 1 ] && exit 2\nexec '+real_tar+' "$@"\n');tar.chmod(0o755)
    dpkg=bin/'dpkg-query'
    dpkg.write_text('''#!/usr/bin/env python3
import os,sys
v=os.environ.get('AD_INSTALLED','7.398~legal-help-completion')
print(('com.joemama383.amazondark ' if '${Package}' in ' '.join(sys.argv) else '')+v,end='')
''');dpkg.chmod(0o755)
    env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],AD_PROBE_ROOT=str(mobile),AD_PROBE_CONTAINERS=str(containers),AD_PROBE_DOCS=str(docs),AD_GZIP_CALLED=str(root/'gzip-called'))
    def run(*args,ok=True,**extra):
        r=subprocess.run(['sh',str(HELPER),*args],env=dict(env,**extra),text=True,capture_output=True)
        assert (r.returncode==0)==ok,(args,r.stdout,r.stderr)
        return r.stdout+r.stderr
    arm=amazon/'Documents/AmazonDark-v7.398-probe.arm'
    launch_arm=mobile/'AmazonDark-launch-probe.arm'
    for style in ['extract','xml','pretty']:
        run('arm','both',AD_PLUTIL_STYLE=style)
        assert arm.read_text().split()[1]=='both'
        assert not launch_arm.exists(), 'non-launch probe must not arm SpringBoard logging'
        assert not (other/'Documents').exists()
        run('disarm')
        assert not arm.exists()
    run('arm','both',ok=False,AD_INSTALLED='7.340~v7309-portable-skeleton-probe')
    assert not arm.exists()
    run('arm','unknown',ok=False)
    assert not arm.exists()
    text=run('export')
    assert 'No app capture ran' in text
    archive=sorted(docs.glob('*.tar'))[-1]
    with tarfile.open(archive) as t:
        report=t.extractfile('./diagnostic-status.txt').read().decode()
        assert VERSION in report and 'Amazon container matches: 1' in report
    run('arm','launch')
    assert arm.read_text().split()[1]=='launch'
    assert launch_arm.exists(), 'launch probe must arm SpringBoard launch logging'
    log=amazon/'Documents/AmazonDark-v7.398-skeleton-1-77-launch.jsonl'
    log.write_text('{"event":"SESSION_START","label":"launch"}\n')
    receipt=amazon/'Documents/AmazonDark-v7.398-probe-status.json'
    receipt.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon','reason':'capture-started','version':'v7.398-legal-help-completion'}))
    old=mobile/'AmazonDark-v7.340-skeleton-1-55-both.jsonl';old.write_text('old capture\n')
    sb=mobile/'AmazonDark-v7.398-launch-sb-probe.txt';sb.write_text('snapshot.dark\n')
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
    assert not arm.exists() and not launch_arm.exists() and log.exists()
    # No container metadata: export still carries a report instead of dead-ending.
    missing=root/'missing';missing.mkdir()
    text=run('export',AD_PROBE_CONTAINERS=str(missing))
    archive=Path(text.splitlines()[1])
    with tarfile.open(archive) as t:
        assert 'Amazon container matches: 0' in t.extractfile('./diagnostic-status.txt').read().decode()
    # Exact installed receipt restores arming with every plutil operation failing.
    (amazon/'.com.apple.mobile_container_manager.metadata.plist').unlink()
    (other/'Documents/AmazonDark-v7.346-probe-status.json').write_text(json.dumps({
        'event':'PROBE_BOOTSTRAP','bundle':'com.example.other','version':'v7.346-v7344-cart-strip-button'}))
    (other/'Documents/AmazonDark-v7.391-probe-status.json').write_text(json.dumps({
        'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon','version':'v7.390-checkout-ui-completion'}))
    run('arm','launch',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='launch'
    assert launch_arm.exists()
    assert not (other/'Documents/AmazonDark-v7.398-probe.arm').exists()
    status=run('status',AD_PLUTIL_STYLE='unavailable')
    assert 'Verified Amazon startup receipts: 1' in status and 'Amazon container matches: 1' in status
    text=run('export',AD_PLUTIL_STYLE='unavailable')
    archive=Path(text.splitlines()[1]);assert archive.suffix=='.tar'
    with tarfile.open(archive) as t:
        assert t.extractfile('./AMAZON/'+log.name).read()==log.read_bytes()
    assert not launch_arm.exists()
    # During upgrade, the immediately previous installed receipt must locate Amazon even when
    # every plutil dialect fails. This is the exact version-rolling boundary that regressed in v7.391.
    receipt.unlink()
    previous397=amazon/'Documents/AmazonDark-v7.397-probe-status.json'
    previous397.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.397-checkout-payment-aux-controls','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous397.unlink()

    previous393=amazon/'Documents/AmazonDark-v7.393-probe-status.json'
    previous393.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.393-payment-help-ui-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous393.unlink()

    previous392=amazon/'Documents/AmazonDark-v7.392-probe-status.json'
    previous392.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.392-probe-handoff-ci-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous392.unlink()

    previous391=amazon/'Documents/AmazonDark-v7.391-probe-status.json'
    previous391.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.391-ui-completion-audit-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous391.unlink()

    # Keep the prior release too; v7.391 accidentally omitted v7.390 from its explicit filename list.
    previous390=amazon/'Documents/AmazonDark-v7.390-probe-status.json'
    previous390.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.390-checkout-ui-completion','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous390.unlink()

    # Retain older proven receipts as compatibility locators.
    previous370=amazon/'Documents/AmazonDark-v7.370-probe-status.json'
    previous370.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.370-checkout-script-reinstall-theme','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous370.unlink()

    previous369=amazon/'Documents/AmazonDark-v7.369-probe-status.json'
    previous369.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.369-checkout-isolated-theme','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous369.unlink()

    previous366=amazon/'Documents/AmazonDark-v7.366-probe-status.json'
    previous366.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.366-cart-empty-caption-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous366.unlink()

    previous365=amazon/'Documents/AmazonDark-v7.365-probe-status.json'
    previous365.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.365-probe-backed-cart-sameday-sustainability','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous365.unlink()

    previous364=amazon/'Documents/AmazonDark-v7.364-probe-status.json'
    previous364.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.364-universal-full-sweep-probes','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous364.unlink()

    previous361=amazon/'Documents/AmazonDark-v7.361-probe-status.json'
    previous361.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.361-probed-renderer-paint-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous361.unlink()

    # v7.360 remains a proven older locator.
    previous360=amazon/'Documents/AmazonDark-v7.360-probe-status.json'
    previous360.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.360-search-tiles-cart-coupon-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous360.unlink()

    # Retain older proven receipts too.
    previous359=amazon/'Documents/AmazonDark-v7.359-probe-status.json'
    previous359.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.359-product-mab-controls-menu-fix','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    run('disarm'); assert not launch_arm.exists(); previous359.unlink()

    # Older proven receipts remain valid upgrade locators too.
    previous346=amazon/'Documents/AmazonDark-v7.346-probe-status.json'
    previous346.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.346-v7344-cart-strip-button','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists(), 'transition probe must include SpringBoard launch logging'
    run('disarm'); assert not launch_arm.exists(); previous346.unlink()

    # The older v7.344 receipt must also remain a valid upgrade locator.
    previous=amazon/'Documents/AmazonDark-v7.344-probe-status.json'
    previous.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon',
        'version':'v7.344-cart-loader-image-preservation','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.read_text().split()[1]=='transition'
    assert launch_arm.exists()
    assert not (amazon/'Documents/AmazonDark-v7.344-probe.arm').exists()
    text=run('export',AD_PLUTIL_STYLE='unavailable')
    with tarfile.open(Path(text.splitlines()[1])) as t:
        assert t.extractfile('./AMAZON/'+previous.name).read()==previous.read_bytes()
    assert not launch_arm.exists()
    print('PASS: current v7.398 plus direct-parent v7.397 and older proven upgrade receipts discover Amazon with plutil unavailable')
    # Even a broken tar returns the actual logs and status in a plain text file.
    run('arm','both',AD_PLUTIL_STYLE='unavailable')
    text=run('export',AD_PLUTIL_STYLE='unavailable',AD_TAR_FAIL='1')
    out=Path(text.splitlines()[1]);assert out.suffix=='.txt'
    data=out.read_text();assert 'SESSION_START' in data and 'snapshot.dark' in data and previous.read_text() in data
    assert not arm.exists() and not list(docs.glob('*.partial'))
    assert not (root/'gzip-called').exists(), 'Helper attempted to invoke gzip'
    print('PASS: receipt discovery works without metadata/plutil; rejects another bundle and filename/payload version mismatch; de-duplicates paths')
    print('PASS: no gzip invocation; uncompressed archive contains captures; tar failure exports plain-text evidence')
    print('PASS: extract/XML/pretty plist discovery; Amazon-only arming; version/invalid-mode guards')
    print('PASS: real tar exports captures, receipts and SB logs; recovers old paths; disarms; preserves logs')
    print('PASS: missing capture/container still exports actionable status; unrelated app files excluded')
