from pathlib import Path
import json, os, plistlib, subprocess, tempfile, time, zipfile
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); INC=(R/'src/ADUniversalUIProbe7362.inc').read_text(); SKH=(R/'src/ADSkeletonProbe7339.h').read_text()
UI=(R/'scripts/ui-probe.sh').read_text(); SK=(R/'scripts/skeleton-probe.sh').read_text(); C=(R/'layout/DEBIAN/control').read_text()

assert 'Version: 7.445~probe-transition-hardening' in C
assert '#define AD_VERSION "v7.445-probe-transition-hardening"' in S
# Transition probe no longer steals screenshot/SIGUSR2 from the UI probe.
assert 'if([trigger isEqualToString:@"screenshot"]){ ADSkelTrigger7339(trigger); ADCaptureUniversalUIProbe7362(NO,trigger); return; }' in INC
assert 'if([trigger isEqualToString:@"SIGUSR2"]){ ADSkelTrigger7339(trigger); if(ADUIConsumeViewportArm7362())' in INC
# FULL sweep survives lazy PDP growth and cannot hang forever on a JS callback.
for token in ['WEB_TIMEOUT label=%@ after=4.0s','WEB_CONTENT_GROWTH','WEB_BOTTOM_HOLD','bottomStable>=3','maxSteps=120 bottomStable=3']:
    assert token in INC,token
assert 'selected.count>=4' in INC and 'maxSteps=horizontal?16:32' in INC
assert 'ADUIWriteState7445(viewportOnly,@"started",path);' in INC
assert 'ADUIWriteState7445(viewportOnly,@"completed",path);' in INC
# UI helper requires explicit export mode and produces ZIPs from the exact state-selected file.
assert 'export full | export viewport' in UI
assert 'ui-$mode.state' in UI and 'make_zip "$archive" "$stage"' in UI
assert 'for kind in ui-full-probe ui-viewport-probe' not in UI
# Transition export is current-version/current-arm only.
assert '$AD_PROBE_NAME"-skeleton-*-$label.jsonl' in SK
assert 'AmazonDark-v7.*-skeleton-*.jsonl' not in SK
assert '.zip' in SK and 'historical captures are never bundled' in SK
# Fresh v7.444 trace: 460x1036 logical skeleton now matches independent of @2x/@3x backing pixels.
matcher=S[S.index('static BOOL ADPDPTransitionSkeletonImage7407'):S.index('static UIImage *ADPDPDarkSkeletonRaster7407')]
for token in ['CGFloat scale=im.scale>0.01?im.scale:1.0','im.size.width','CGImageGetWidth(im.CGImage)','pw/scale','iw>=420.0&&iw<=520.0','ih>=940.0&&ih<=1120.0','fillsOwner']:
    assert token in matcher,token
assert 'if(pw<400||pw>560||ph<880||ph>1200)return NO;' not in matcher
for token in ['imageScale','imagePixels','imageRenderingMode','imageContentMode']:
    assert token in SKH,token

# Runtime shell check: FULL and VIEWPORT exports cannot cross-export each other.
ZIP_SHIM='''#!/usr/bin/env python3\nimport os,sys,zipfile\nout=next(a for a in sys.argv[1:] if not a.startswith('-'))\nwith zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:\n  [z.write(os.path.join(r,f),os.path.join(r,f)[2:] if os.path.join(r,f).startswith('./') else os.path.join(r,f)) for r,ds,fs in os.walk('.') for f in fs]\n'''
PLUTIL='''#!/bin/sh\nlast=""; for a in "$@"; do last=$a; done\nawk '/<key>MCMMetadataIdentifier<\\/key>/{take=1;next} take&&/<string>/{s=$0;sub(/^.*<string>/,"",s);sub(/<\\/string>.*$/,"",s);print s;exit}' "$last"\n'''
with tempfile.TemporaryDirectory(prefix='ad-v7445-ui-') as t:
    root=Path(t); mobile=root/'mobile'; cont=mobile/'Containers/Data/Application'; amazon=cont/'A'; amazon.mkdir(parents=True); shared=root/'shared'; shared.mkdir()
    (amazon/'.com.apple.mobile_container_manager.metadata.plist').write_bytes(plistlib.dumps({'MCMMetadataIdentifier':'com.amazon.Amazon'},fmt=plistlib.FMT_XML))
    docs=amazon/'Documents'; docs.mkdir()
    now=int(time.time())
    full='AmazonDark-v7.445-ui-full-probe-20260921-000000-000-r1.txt'; view='AmazonDark-v7.445-ui-viewport-probe-20260921-000001-000-r1.txt'
    (docs/full).write_text('FULL\n================ END RUN ================\n'); (docs/view).write_text('VIEWPORT\n================ END RUN ================\n')
    (docs/'AmazonDark-v7.445-ui-full.state').write_text(f'completed {now} {full}\n'); (docs/'AmazonDark-v7.445-ui-viewport.state').write_text(f'completed {now} {view}\n')
    b=root/'bin'; b.mkdir(); (b/'plutil').write_text(PLUTIL); (b/'plutil').chmod(0o755); (b/'zip').write_text(ZIP_SHIM); (b/'zip').chmod(0o755); (b/'dpkg-query').write_text("#!/bin/sh\nprintf '7.445~probe-transition-hardening'\n"); (b/'dpkg-query').chmod(0o755)
    env=dict(os.environ,PATH=str(b)+':'+os.environ['PATH'],AD_UI_ROOT=str(mobile),AD_UI_CONTAINERS=str(cont),AD_UI_SHARED=str(shared))
    def run(*a,ok=True):
        q=subprocess.run(['sh',str(R/'scripts/ui-probe.sh'),*a],env=env,text=True,capture_output=True)
        assert (q.returncode==0)==ok,(a,q.stdout,q.stderr); return q.stdout+q.stderr
    assert 'exactly one completed' in run('export','full')
    z=sorted(shared.glob('*ui-full-probe-*.zip'))[-1]
    with zipfile.ZipFile(z) as x:
        assert full in x.namelist() and view not in x.namelist()
    assert 'exactly one completed' in run('export','viewport')
    z=sorted(shared.glob('*ui-viewport-probe-*.zip'))[-1]
    with zipfile.ZipFile(z) as x:
        assert view in x.namelist() and full not in x.namelist()
    run('export',ok=False)
    (docs/'AmazonDark-v7.445-ui-full.state').write_text(f'started {now} {full}\n')
    assert 'still running or incomplete' in run('export','full',ok=False)

print('PASS: v7.445 isolates all three probes, hardens PDP FULL completion, and scale-normalizes the proven transition skeleton')
