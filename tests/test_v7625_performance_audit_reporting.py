from pathlib import Path
import subprocess,sys,tempfile,json,os,tarfile
R=Path(__file__).resolve().parents[1]
PERF=R/'scripts/performance-probe.sh'
REPORT=R/'scripts/performance-report.py'
AUDIT=R/'scripts/performance-source-audit.py'
S=PERF.read_text()
assert 'CUR=${VER#7.}' in S and '[ "$rv" -le "$CUR" ]' in S
assert 'VER=7.625' in S and 'NAME=AmazonDark-v$VER-performance' in S
assert 'sh scripts/performance-probe.sh' not in (R/'src/ADPerformance7596.inc').read_text()
assert 'gADPerformanceActive7596=NO' in (R/'src/ADPerformance7596.h').read_text()
assert 'MutationObserver' not in (R/'src/ADPerformance7596.js').read_text()
with tempfile.TemporaryDirectory() as td:
    t=Path(td); docs=t/'Containers/Data/Application'/'TESTUID'/'Documents';docs.mkdir(parents=True)
    shared=t/'Shared';shared.mkdir()
    # The receipt may belong to last installed build, but the new armed performance
    # state is current and must still be created in the same Amazon container.
    (docs/'AmazonDark-v7.624-probe-status.json').write_text('{"bundle":"com.amazon.Amazon","event":"PROBE_BOOTSTRAP","version":"v7.624-previous"}')
    bindir=t/'bin';bindir.mkdir()
    tool=bindir/'dpkg-query';tool.write_text('#!/bin/sh\nprintf "7.625~performance-audit-and-report"\n');tool.chmod(0o755)
    env={**os.environ,'PATH':str(bindir)+os.pathsep+os.environ['PATH'],'AD_UI_ROOT':str(t),
         'AD_UI_CONTAINERS':str(t/'Containers/Data/Application'),'AD_UI_SHARED':str(shared)}
    proc=subprocess.run(['sh',str(PERF),'arm'],env=env,text=True,capture_output=True)
    assert proc.returncode==0,(proc.stdout,proc.stderr)
    assert (docs/'AmazonDark-v7.625-performance.state').read_text().strip()=='armed'
    # Seed a representative completed, native + WebKit 90-second JSON report.
    m={'count':2,'totalMs':35.4,'maxMs':24.2,'buckets':[0,0,0,1,1,0,0,0]}
    perf={'version':'v7.625-performance-audit-and-report','durationMs':90000,'endReason':'deadline',
          'nativeFrames':m,'touchEventAge':m,
          'frameGapsOver50MsBySecond':[1]+[0]*89,
          'lanes':{'eventDispatchInclusive':m},'enrolledWebViews':1,
          'webDocuments':[{'navigationMs':{'domInteractive':590,'domContentLoadedEventEnd':630,'loadEventEnd':680},
             'frames':m,'inputToNextRAF':m,'resources':m,'eventTiming':m,'longTasks':m,'supported':['resource']}],
          'otherDiagnosticObserved':False,'injectionErrors':0,'droppedRecords':0}
    (docs/'AmazonDark-v7.625-performance.json').write_text(json.dumps(perf))
    (docs/'AmazonDark-v7.625-performance.state').write_text('completed\n')
    e=subprocess.run(['sh',str(PERF),'export'],env=env,text=True,capture_output=True)
    assert e.returncode==0,(e.stdout,e.stderr)
    outputs=list(shared.glob('AmazonDark-v7.625-performance-*.tar'))
    assert len(outputs)==1,outputs
    cp=subprocess.run([sys.executable,str(REPORT),str(outputs[0]),'--baseline',str(outputs[0])],text=True,capture_output=True)
    assert cp.returncode==0,cp.stderr
    assert 'domInteractive' in cp.stdout and 'reactLayoutTheme' in cp.stdout
    assert '## Comparison' in cp.stdout and 'main-runloop callback gap' in cp.stdout
    bad=t/'invalid.json';bad.write_text('{"webDocuments":[]}')
    cp=subprocess.run([sys.executable,str(REPORT),str(bad)],text=True,capture_output=True)
    assert cp.returncode!=0
    ca=subprocess.run([sys.executable,str(AUDIT),str(R)],text=True,capture_output=True)
    assert ca.returncode==0,ca.stderr
    assert 'ADPerformance7596.js' in ca.stdout
    assert 'opt-in diagnostics' in ca.stdout
    # Strict production scanner gate. Opt-in diagnostics may use RAF/MO while armed.
    import importlib.util
    spec=importlib.util.spec_from_file_location('ad_perf_source_audit',AUDIT)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    rows,groups=module.analyze(R)
    prod=groups['production / combined']
    # v7.642 explicitly budgets one ID-only review ownership observer, replacing
    # repeated relational CSS checks. It is not a DOM scanner; do not hide it
    # from the production census or permit any additional observer.
    assert prod['MutationObserver']==1 and prod['setInterval']==0 and prod['requestAnimationFrame']==0 and prod['TreeWalker']==0,prod
    review=(R/'src/ADRenderScope7640.js').read_text().split('function ad7642ReviewScope(css) {')[1].split('function ad7640Style(style) {')[0]
    assert review.count('new MutationObserver(')==1
    for banned in ('querySelector', 'getComputedStyle', 'offsetHeight', 'setTimeout', 'setInterval', 'requestAnimationFrame'):
        assert banned not in review
    assert prod['scroll-listener']==0,prod
    # v7.634: one reviewed, once-only catch-up under customer-corner-root.
    books=(R/'src/ADAccountMenus7634.js').read_text()
    assert books.count('querySelectorAll(')==1 and "getElementById('customer-corner-root')" in books
    assert 'count<256' in books and "'DOMContentLoaded',existing,{once:true}" in books
    assert prod['querySelectorAll']<=9,(prod['querySelectorAll'], 'new production DOM scanner requires review')
    assert groups['opt-in diagnostics']['MutationObserver']>=1  # FULL/transition probe retained
    assert groups['opt-in diagnostics']['requestAnimationFrame']>=1  # performance diagnostic retained
    assert not any('picture img' in (R/'src'/n).read_text() for n in ('ADKeepShopping7613.js', 'ADKeepShopping7613.js.inc'))
print('PASS: v7.625 source-scanner audit, existing-receipt performance ARM/EXPORT and raw capture Markdown compare')
