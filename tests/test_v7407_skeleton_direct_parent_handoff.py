from pathlib import Path
import json, os, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]; HELPER=ROOT/'scripts/skeleton-probe.sh'
with tempfile.TemporaryDirectory(prefix='ad7407-parent-handoff-') as td:
    root=Path(td); containers=root/'Containers/Data/Application'; amazon=containers/'AMAZON'/'Documents'; amazon.mkdir(parents=True)
    shared=root/'shared'; shared.mkdir(); bin=root/'bin'; bin.mkdir()
    (bin/'plutil').write_text('#!/bin/sh\nexit 1\n'); (bin/'plutil').chmod(0o755)
    (bin/'dpkg-query').write_text('#!/bin/sh\nprintf "7.409~permission-controls-location-rails-fix"\n'); (bin/'dpkg-query').chmod(0o755)
    receipt=amazon/'AmazonDark-v7.406-probe-status.json'
    receipt.write_text(json.dumps({'event':'PROBE_BOOTSTRAP','bundle':'com.amazon.Amazon','version':'v7.406-video-sponsored-footer-restore'}))
    env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],AD_PROBE_ROOT=str(root),AD_PROBE_CONTAINERS=str(containers),AD_PROBE_DOCS=str(shared))
    r=subprocess.run(['sh',str(HELPER),'arm','transition'],env=env,text=True,capture_output=True,timeout=8)
    assert r.returncode==0,(r.stdout,r.stderr)
    arm=amazon/'AmazonDark-v7.409-probe.arm'; launch=root/'AmazonDark-launch-probe.arm'
    assert arm.exists() and arm.read_text().split()[1]=='transition' and launch.exists()
    r=subprocess.run(['sh',str(HELPER),'disarm'],env=env,text=True,capture_output=True,timeout=8)
    assert r.returncode==0 and not arm.exists() and not launch.exists()
print('PASS: v7.407 skeleton helper discovers Amazon from exact direct-parent v7.406 receipt')
