"""Exercise the v7.446 transition helper boundary with real ZIP output.

The helper must identify only Amazon, remember the current arm epoch/mode, and export
one current-session capture instead of every historical probe on the phone.
"""
import json, os, plistlib, subprocess, tempfile, zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'scripts/skeleton-probe.sh'
VERSION='7.446~probe-responsiveness'

ZIP_SHIM=r'''#!/usr/bin/env python3
import os,sys,zipfile
args=sys.argv[1:]
out=None
for a in args:
    if a.startswith('-'): continue
    out=a; break
if not out: raise SystemExit(2)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for root,dirs,files in os.walk('.'):
        for f in files:
            p=os.path.join(root,f)
            z.write(p,p[2:] if p.startswith('./') else p)
'''
PLUTIL_SHIM=r'''#!/bin/sh
style=${AD_PLUTIL_STYLE:-extract}; last=""; for a in "$@"; do last=$a; done
[ "$style" = unavailable ] && exit 1
value=$(awk '/<key>MCMMetadataIdentifier<\/key>/{take=1;next} take&&/<string>/{s=$0;sub(/^.*<string>/,"",s);sub(/<\/string>.*$/,"",s);print s;exit}' "$last")
case "$1:$style" in
  -extract:extract) printf '%s\n' "$value" ;;
  -convert:extract|-convert:xml) cat "$last" ;;
  -p:pretty) printf '  "MCMMetadataIdentifier" => "%s"\n' "$value" ;;
  *) exit 1 ;;
esac
'''

with tempfile.TemporaryDirectory(prefix='ad-v7445-transition-') as temp:
    root=Path(temp); mobile=root/'mobile'; containers=mobile/'Containers/Data/Application'
    amazon=containers/'AMAZON'; other=containers/'OTHER'; shared=root/'shared'; shared.mkdir(parents=True)
    for p,bid in [(amazon,'com.amazon.Amazon'),(other,'com.example.other')]:
        p.mkdir(parents=True)
        (p/'.com.apple.mobile_container_manager.metadata.plist').write_bytes(plistlib.dumps({'MCMMetadataIdentifier':bid},fmt=plistlib.FMT_XML))
    bindir=root/'bin'; bindir.mkdir()
    (bindir/'plutil').write_text(PLUTIL_SHIM); (bindir/'plutil').chmod(0o755)
    (bindir/'zip').write_text(ZIP_SHIM); (bindir/'zip').chmod(0o755)
    (bindir/'dpkg-query').write_text("#!/bin/sh\nprintf '%s' \"${AD_INSTALLED:-7.446~probe-responsiveness}\"\n"); (bindir/'dpkg-query').chmod(0o755)
    env=dict(os.environ,PATH=str(bindir)+':'+os.environ['PATH'],AD_PROBE_ROOT=str(mobile),AD_PROBE_CONTAINERS=str(containers),AD_PROBE_DOCS=str(shared))
    def run(*args,ok=True,**extra):
        r=subprocess.run(['sh',str(HELPER),*args],env=dict(env,**extra),text=True,capture_output=True)
        assert (r.returncode==0)==ok,(args,r.returncode,r.stdout,r.stderr)
        return r.stdout+r.stderr

    # Package mismatch is rejected before arming.
    run('arm','transition',ok=False,AD_INSTALLED='7.444~pdp-proven-media')
    docs=amazon/'Documents'; arm=docs/'AmazonDark-v7.446-probe.arm'; state=docs/'AmazonDark-v7.446-probe-export.state'
    assert not arm.exists()

    run('arm','transition')
    label,armed=state.read_text().split(); assert label=='transition'; armed=int(armed)
    assert arm.read_text().split()[1]=='transition'
    assert (mobile/'AmazonDark-launch-probe.arm').exists()
    assert not (other/'Documents').exists()

    # Historical and pre-arm files must never be exported.
    old=docs/f'AmazonDark-v7.446-skeleton-{(armed-10)*1000}-111-transition.jsonl'; old.write_text('{"event":"SESSION_START","label":"transition"}\nOLD\n')
    hist=docs/f'AmazonDark-v7.444-skeleton-{(armed+1)*1000}-222-transition.jsonl'; hist.write_text('{"event":"SESSION_START","label":"transition"}\nHIST\n')
    fresh=docs/f'AmazonDark-v7.446-skeleton-{(armed+2)*1000}-333-transition.jsonl'; fresh.write_text('{"event":"SESSION_START","label":"transition"}\nFRESH\n')
    (docs/'AmazonDark-v7.446-probe-status.json').write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon','version':'v7.446-probe-responsiveness','reason':'capture-started'}))
    (mobile/'AmazonDark-v7.446-launch-sb-probe.txt').write_text('switcher evidence\n')

    # Fixture order must not depend on rapid writes having distinct mtimes.
    # Whole-second spacing also exercises shells/filesystems with coarse comparisons.
    marker_epoch=int(state.stat().st_mtime)
    os.utime(state,(marker_epoch,marker_epoch))
    os.utime(fresh,(marker_epoch,marker_epoch))
    ambiguous=run('export')
    assert 'exported diagnostics only' in ambiguous, ambiguous
    with zipfile.ZipFile(Path(ambiguous.strip().splitlines()[-1])) as z:
        assert not [n for n in z.namelist() if '-skeleton-' in n]
    os.utime(old,(marker_epoch-4,marker_epoch-4))
    os.utime(hist,(marker_epoch+4,marker_epoch+4))
    os.utime(fresh,(marker_epoch+4,marker_epoch+4))
    text=run('export')
    assert 'Exported exactly one current v7.446 transition capture' in text, text
    archive=Path(text.strip().splitlines()[-1]); assert archive.suffix=='.zip' and archive.exists()
    with zipfile.ZipFile(archive) as z:
        names=z.namelist(); skeletons=[n for n in names if '-skeleton-' in n and n.endswith('.jsonl')]
        assert skeletons==[fresh.name],names
        assert old.name not in names and hist.name not in names
        assert 'manifest.txt' in names and 'diagnostic-status.txt' in names
        assert 'launch-springboard-last2MiB.txt' in names
        assert b'FRESH' in z.read(fresh.name)
    assert not arm.exists() and not (mobile/'AmazonDark-launch-probe.arm').exists()
    assert state.exists(), 'export state should remain available for deterministic re-export/debugging'

    # A new arm with no resulting app capture still returns a small diagnostic ZIP, not old data.
    run('arm','transition')
    label2,armed2=state.read_text().split(); assert int(armed2)>=armed
    # Model a prior-session capture explicitly; the fixture above used a future mtime.
    prior_epoch=int(state.stat().st_mtime)-4
    os.utime(fresh,(prior_epoch,prior_epoch))
    text=run('export')
    archive=Path(text.strip().splitlines()[-1]); assert archive.suffix=='.zip'
    with zipfile.ZipFile(archive) as z:
        assert not [n for n in z.namelist() if '-skeleton-' in n and n.endswith('.jsonl')]
        assert 'diagnostic-status.txt' in z.namelist()

    # Receipt discovery still works when every plutil route fails.
    (amazon/'.com.apple.mobile_container_manager.metadata.plist').unlink()
    receipt=docs/'AmazonDark-v7.446-probe-status.json'
    receipt.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon','version':'v7.446-probe-responsiveness','reason':'arm-missing-or-unreadable'}))
    run('arm','transition',AD_PLUTIL_STYLE='unavailable')
    assert arm.exists()
    run('disarm',AD_PLUTIL_STYLE='unavailable')
    assert not arm.exists() and state.exists()

print('PASS: v7.446 transition helper exports one current armed session as ZIP and never bundles historical captures')
