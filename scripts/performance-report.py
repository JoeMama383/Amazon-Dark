#!/usr/bin/env python3
"""AmazonDark opt-in performance capture summarizer. Read-only. Standard library only.

Usage:
  python3 scripts/performance-report.py <performance.tar|performance.json> [--baseline <other.tar|json>] [--json output.json]

Never treats missing documents/unsupported observers as zero latency. Bucket-derived
percentiles are explicitly approximate upper bounds, not measured samples.
"""
import argparse
import io
import json
import math
from pathlib import Path
import tarfile

BOUNDS = [1.0,4.0,8.0,16.7,33.4,50.0,100.0,float('inf')]
LANES = ['eventDispatchInclusive','reactLayoutTheme','imageLayoutTheme',
         'imageCommitInclusive','reactTextCommitInclusive','viewBackgroundInclusive',
         'labelAttributedCommitInclusive', 'childFrameRepairRoundTrip']


def load(path):
    path=Path(path)
    if path.suffix.lower()=='.json':
        return json.loads(path.read_text(encoding='utf-8'))
    if path.suffix.lower()!='.tar':
        raise ValueError('Performance session must be .tar or .json: '+str(path))
    with tarfile.open(path,'r:') as archive:
        hits=[m for m in archive.getmembers() if m.isfile() and m.name.endswith('.json')]
        if len(hits)!=1 or hits[0].size>12_000_000:
            raise ValueError('Expected one capped JSON performance session in TAR')
        stream=archive.extractfile(hits[0])
        if stream is None: raise ValueError('Missing member data')
        return json.loads(stream.read().decode('utf-8'))


def numeric(x):
    if isinstance(x,(bool,str)) or not isinstance(x,(int,float)) or not math.isfinite(x):return None
    return float(x)


def fmt(value,unit='ms',places=1):
    n=numeric(value)
    return 'n/a' if n is None else f'{n:,.{places}f} {unit}'.strip()


def bucket_p95(m):
    if not isinstance(m,dict):return 'n/a'
    count=int(m.get('count') or 0)
    buckets=m.get('buckets') or []
    if not count or len(buckets)!=8:return 'n/a'
    goal=math.ceil(count*.95)
    total=0
    for i,b in enumerate(buckets):
        total+=int(b)
        if total>=goal:
            return '>=100 ms' if i==7 else '<=%.1f ms'%(BOUNDS[i])
    return 'n/a'


def metric_line(name,m):
    if not isinstance(m,dict):return f'| {name} | n/a | n/a | n/a | n/a |'
    n=int(m.get('count') or 0)
    average=(numeric(m.get('totalMs')) or 0)/n if n else None
    return f'| {name} | {n:,} | {fmt(average)} | {bucket_p95(m)} | {fmt(m.get("maxMs"))} |'


def flattened(doc):
    nav=doc.get('navigationMs') or {}
    return {k:(numeric(nav.get(k)) if (numeric(nav.get(k)) or 0)>0 else None) for k in ['responseStart','responseEnd','domInteractive','domContentLoadedEventEnd','loadEventEnd']}


def get_top_value(doc,key):
    if not isinstance(doc,dict):return None
    v=doc.get(key)
    return v if isinstance(v,dict) else None


def latest_documents(data):
    # Diagnostic reports are cumulative: count only the latest aggregate for each
    # opaque document ID, not every 5-second snapshot of the same page.
    latest={}; unknown=[]
    for doc in data.get('webDocuments') or []:
        if not isinstance(doc,dict): continue
        ident=doc.get('documentId')
        if isinstance(ident,(int,float)) and not isinstance(ident,bool):
            prior=latest.get(ident)
            # A WKScriptMessage report and evaluateJavaScript fallback may arrive
            # out of order. Keep the largest cumulative duration, not last arrival.
            if prior is None or (numeric(doc.get('durationMs')) or 0)>=(numeric(prior.get('durationMs')) or 0):
                latest[ident]=doc
        else: unknown.append(doc)
    return unknown+list(latest.values())


def latest_theme_documents(data):
    # WebKit privacy rounding changes timeOrigin by ~1 ms between bridge/eval
    # reports. Same opaque document ID and frame must not be counted twice.
    rows=[]
    for doc in data.get('themeWork') or []:
        if not isinstance(doc,dict):continue
        prior=next((i for i,x in enumerate(rows)
            if x.get('documentId')==doc.get('documentId')
            and x.get('mainFrame')==doc.get('mainFrame')
            and abs((numeric(x.get('timeOriginMs')) or 0)-(numeric(doc.get('timeOriginMs')) or 0))<=5),None)
        if prior is None:rows.append(doc)
        elif (numeric(rows[prior].get('durationMs')) or 0)<=(numeric(doc.get('durationMs')) or 0):rows[prior]=doc
    return rows


def matched_main_documents(data):
    # Web timings and theme timings use independent opaque IDs. Correlate only
    # unique time origins, allowing WebKit's <=5 ms privacy rounding. A child
    # frame or another WebView born at the same time makes the match ambiguous.
    themes=latest_theme_documents(data)
    webs=latest_documents(data)
    pairs=[]
    for theme in themes:
        origin=numeric(theme.get('timeOriginMs'))
        if not theme.get('mainFrame') or not origin:continue
        matches=[w for w in webs if numeric(w.get('timeOriginMs')) is not None
                 and abs(w['timeOriginMs']-origin)<=5]
        if len(matches)!=1:continue
        web=matches[0]
        reverse=[t for t in themes if numeric(t.get('timeOriginMs')) is not None
                 and abs(t['timeOriginMs']-web['timeOriginMs'])<=5]
        if len(reverse)==1:pairs.append((theme,web))
    return pairs


def route_timing_report(data):
    pairs=matched_main_documents(data)
    if not pairs:return []
    names={0:'Other',1:'Search',2:'Product'}
    lines=['','Matched main-document timings (unique time-origin correlation; ambiguous matches omitted):','',
           '| Route / web document | Theme rules | Input samples | Mean input → RAF | Max input → RAF | Max event-loop lag | DOM interactive |',
           '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for theme,web in pairs:
        inputs=web.get('inputToNextRAF') or {}
        count=int(inputs.get('count') or 0)
        total=numeric(inputs.get('totalMs'))
        mean=total/count if count and total is not None else None
        loop=web.get('eventLoopLag') or {}
        rules=numeric(theme.get('themeRules'))
        lines.append('| %s / %s | %s | %d | %s | %s | %s | %s |'%(
            names.get(theme.get('route'),'Unknown'),web.get('documentId','unknown'),
            str(int(rules)) if rules is not None else 'n/a',count,fmt(mean),
            fmt(inputs.get('maxMs') if count else None),
            fmt(loop.get('maxMs') if loop.get('count') else None),
            fmt(flattened(web)['domInteractive'])))
    return lines


def theme_work_report(data):
    docs=latest_theme_documents(data)
    inventory=[x for x in data.get('userScriptInventory',[]) if isinstance(x,dict)]
    if not docs and not inventory:return []
    names={'s0':'Core/menus','s1':'Sponsored filter','s2':'Price history','s3':'Image taming',
           's4':'Checkout floors','s5':'Checkout media','s6':'Checkout hydration','s7':'Privacy','s8':'Child-frame delivery'}
    lines=['','AmazonDark execution attribution (armed only):']
    if inventory:
        before=[x for x in inventory if x.get('phase')==0];after=[x for x in inventory if x.get('phase')==1]
        lines.append('- Duplicate WKUserScript object entries: **%d before enrollment**, **%d after cleanup** (summed across controllers).'%(sum(int(x.get('duplicateObjects',0)) for x in before),sum(int(x.get('duplicateObjects',0)) for x in after)))
    if not docs:
        return lines+['- **No theme execution reports.** Already-loaded documents cannot report earlier startup work; navigate to a fresh page after arming.']
    main=[x for x in docs if x.get('mainFrame')];child=[x for x in docs if not x.get('mainFrame')]
    lines.append('- Theme-work coverage: **%d main documents**, **%d child documents**.'%(len(main),len(child)))
    lines.append('- Largest main-document sheet inventory: **%d owned theme sheets**, **%d top-level rules**, **%d adopted sheets**. Counts include constructed theme sheets and do not measure matching/rendering cost. In isolation mode the final inventory is taken after restoration; use residual-at-stop values below for the withheld state.'%(max([int(x.get('themeSheets',0)) for x in main]+[0]),max([int(x.get('themeRules',0)) for x in main]+[0]),max([int(x.get('adoptedSheets',0)) for x in main]+[0])))
    if any('staticThemeSheets' in x for x in main):
        lines.append('- Largest constructed theme inventory: **%d sheets** (included in owned-theme totals).'%max([int(x.get('staticThemeSheets',0)) for x in main]+[0]))
    metrics={}
    for doc in docs:
        for m in doc.get('metrics',[]):
            if not isinstance(m,dict):continue
            name=m.get('name','');key=('main' if doc.get('mainFrame') else 'child',name)
            row=metrics.setdefault(key,{'count':0,'total':0,'max':0})
            row['count']+=int(m.get('count',0));row['total']+=numeric(m.get('totalMs')) or 0;row['max']=max(row['max'],numeric(m.get('maxMs')) or 0)
    lines+=['','| Scope | Own script/callback | Calls | Total inclusive | Slowest |','| --- | --- | ---: | ---: | ---: |']
    for (scope,name),m in sorted(metrics.items(),key=lambda pair:pair[1]['max'],reverse=True)[:40]:
        slot,_,callback=name.partition('/');label=names.get(slot,slot)+' / '+callback
        lines.append('| %s | %s | %d | %s | %s |'%(scope,label,m['count'],fmt(m['total']),fmt(m['max'])))
    lines+=route_timing_report(data)
    for theme,web in matched_main_documents(data):
        install=sum((numeric(m.get('totalMs')) or 0) for m in theme.get('metrics',[]) if str(m.get('name','')).endswith('/install'))
        lag=(web.get('eventLoopLag') or {}).get('maxMs')
        if (numeric(lag) or 0)>=100:
            lines.append('- Document %s: measured theme installs **%s**, worst event-loop lag **%s**. Install totals exclude deferred style/layout/paint and later callbacks.'%(web.get('documentId'),fmt(install),fmt(lag)))
    trials=[(doc.get('documentId'),trial) for doc in docs for trial in doc.get('styleTrials',[]) if isinstance(trial,dict)]
    mode=int(data.get('startupIsolationMode') or 0)
    if mode:
        labels={1:'all intercepted theme CSS',2:'base Search/product CSS',3:'follow-up theme CSS'}
        lines+=['','**Document-start isolation:** '+labels.get(mode,'unknown mode')+' withheld on newly loaded main Search/product documents. This is a counterfactual diagnostic, not normal themed-page performance. It does not remove native hooks or page scripts.']
        eligible=[doc for doc in main if doc.get('isolationEligible') and doc.get('isolationStyles')]
        if not eligible:lines.append('- **No eligible fresh document had CSS withheld. This capture cannot test the stylesheet hypothesis.** Navigate to fresh Search/product documents after arming.')
        for doc in eligible:
            lines.append('- Document %s: %d style elements intercepted, %s bytes withheld; %d restores, %d failures; retained theme rules at stop: %s; adopted sheets at stop: %s.'%(doc.get('documentId'),int(doc.get('isolationStyles',0)),format(int(doc.get('isolationBytes',0)),','),int(doc.get('isolationRestored',0)),int(doc.get('isolationFailures',0)),doc.get('isolationRulesAtStop','not recorded'),doc.get('isolationAdoptedAtStop','not recorded')))
            if 'isolationRulesAtStop' not in doc or 'isolationAdoptedAtStop' not in doc:
                lines.append('  - **Isolation completion unconfirmed:** final rule inventory was not recorded. Missing evidence is not zero residual CSS; do not interpret this as complete isolation or confirmed restoration.')
            elif mode==1 and (doc.get('isolationFailures') or doc.get('isolationRulesAtStop',0) or doc.get('isolationAdoptedAtStop',0)):
                lines.append('  - **Isolation incomplete:** residual styles/adopted sheets or restoration failures remain; do not interpret this as all theme CSS removed.')
        late=sum(1 for doc in main if doc.get('isolationLate'))
        if late:lines.append('- %d already-loaded documents were deliberately left unchanged.'%late)
    if data.get('styleExperiment'):
        lines+=['','**Style-cost experiment:** input/RAF gaps include deliberate forced recalculations and must not be compared with ordinary-use latency. The paired costs rank reapplication work; they do not prove which sheet caused the original stall.']
        if trials:
            lines+=['','| Theme stylesheet | Rules | Disable + flush | Restore + flush | Error |','| --- | ---: | ---: | ---: | ---: |']
            for _,m in sorted(trials,key=lambda x:numeric(x[1].get('restoreMs')) or 0,reverse=True):
                lines.append('| %s | %d | %s | %s | %s |'%(m.get('name','unknown'),int(m.get('rules',0)),fmt(m.get('disableMs')),fmt(m.get('restoreMs')),m.get('failed',0)))
        else:lines.append('- No stylesheet trials completed. Leave a freshly loaded menu visible until the experiment completes; an empty result is not zero cost.')
        states={0:'not completed',1:'completed',2:'soft budget reached',3:'interrupted'}
        for doc in main:
            if doc.get('styleMode'):lines.append('- Style trial document %s: **%s**, %s spent; at most 24 owned style elements/adopted sheets tested; 15s soft work budget.'%(doc.get('documentId'),states.get(doc.get('styleState'),'unknown'),fmt(doc.get('styleSpentMs'))))
    lines.append('- Callback labels include registration index and function name; computed-style reads overlap their parent callback. Do not sum inclusive rows. Cheap JS timings with large input gaps leave deferred CSS/rendering or uninstrumented work unresolved.')
    return lines


def brief_report(data,label='Current'):
    duration=(numeric(data.get('durationMs')) or 0)/1000
    native=data.get('nativeFrames') or {}
    gaps=native.get('buckets') or []
    nframes=int(native.get('count') or 0)
    gapover50=sum(int(v) for v in gaps[6:]) if len(gaps)==8 else None # index 6 = (50,100]
    observed=int(sum(data.get('frameGapsOver50MsBySecond') or []))
    rawdocs=data.get('webDocuments') or []
    docs=latest_documents(data)
    navs=[flattened(x) for x in docs if isinstance(x,dict)]
    cover={key: [x[key] for x in navs if x.get(key) is not None] for key in
           ['responseStart','responseEnd','domInteractive','domContentLoadedEventEnd','loadEventEnd']}
    lines=[f'## {label}: {data.get("version","unknown")}',
       f'- Session duration: **{duration:.1f}s**, end reason: **{data.get("endReason","unknown")}**.',
       f'- WebKit coverage: **{len(docs)} document instances** from **{len(rawdocs)} cumulative snapshots/reports**, **{data.get("enrolledWebViews",0)} enrolled views**, **{data.get("injectionErrors",0)} JS injection errors**.',
       f'- Recorder quality: **{data.get("droppedRecords",0)} dropped records**, other probe overlapping: **{data.get("otherDiagnosticObserved", "unknown")}**.',
       f'- Main-runloop callback gaps >50ms: **{observed}** ({(100*observed/nframes):.2f}% of {nframes:,} intervals)' if nframes else '- Main-runloop callback gaps: **no valid samples**.',
       '', '| Native measurement (inclusive; overlapping) | Calls | Mean | P95 bucket upper bound | Max |',
       '| --- | ---: | ---: | ---: | ---: |',
       metric_line('main-runloop callback gap',native),
       metric_line('touch event age',data.get('touchEventAge') or {}),
       ]
    lanes=data.get('lanes') or {}
    for name in LANES: lines.append(metric_line(name,lanes.get(name) or {}))
    lines+=['','| Web navigation field | Documents with data | Median observed | Worst observed |','| --- | ---: | ---: | ---: |']
    for k,vals in cover.items():
        vals=sorted(vals)
        if vals:
            median=vals[len(vals)//2] if len(vals)%2 else (vals[len(vals)//2-1]+vals[len(vals)//2])/2
            lines.append(f'| {k} | {len(vals):,} | {fmt(median)} | {fmt(vals[-1])} |')
        else:lines.append(f'| {k} | 0 | n/a | n/a |')
    lines.append('')
    def aggregate(name):
        vals=[d.get(name) or {} for d in docs if isinstance(d,dict)]
        return {'count':sum(int(x.get('count') or 0) for x in vals),
                'maxMs':max([numeric(x.get('maxMs')) or 0 for x in vals]+[0]),
                'totalMs':sum(numeric(x.get('totalMs')) or 0 for x in vals)}
    for name in ['frames','inputToNextRAF','eventTiming','longTasks','resources','scrollFromMove','scrollFromTouch','inputArrival','inputTaskDelay','eventLoopLag']:
        m=aggregate(name)
        lines.append(f'- Web `{name}`: **{m["count"]:,} samples**, mean **{fmt(m["totalMs"]/m["count"] if m["count"] else None)}**, max **{fmt(m["maxMs"] if m["count"] else None)}**.')
    started=sum(int(d.get('scrollStarted') or 0) for d in docs if isinstance(d,dict))
    gestures=sum(int(d.get('scrollGestures') or 0) for d in docs if isinstance(d,dict))
    lines.append(f'- Web scroll gestures observed: **{gestures}**; gestures followed by observed scroll: **{started}**. These are proxies, not proof of scrolling intent.')
    loading=[numeric(d.get('loadingMs')) for d in (data.get('webLoadingIntervals') or []) if isinstance(d,dict)]
    loading=[v for v in loading if v is not None]
    if loading:lines.append(f'- Native WebView `loading==YES` intervals: **{len(loading)}**, longest **{fmt(max(loading))}**, median **{fmt(sorted(loading)[len(loading)//2])}**. A loading flag is NOT an input-blocking duration.')
    supported=set(t for d in docs if isinstance(d,dict) for t in d.get('supported',[]))
    # v7.629: measure evaluation wait time even when WebKit never sends a
    # document callback; identify attempts made during an active load.
    attempts=[x for x in data.get('injectionTimings',[]) if isinstance(x,dict)]
    a_loading=[x for x in attempts if x.get('wasLoading') is True]
    elapsed=[numeric(x.get('evalMs')) for x in attempts]
    elapsed=[x for x in elapsed if x is not None]
    failed=sum(x.get('success') is False for x in attempts)
    lines.append(f'- JS install/evaluation callbacks: **{len(attempts)}**; requested while loading: **{len(a_loading)}**; failures: **{failed}**; slowest callback: **{fmt(max(elapsed) if elapsed else None)}**.')
    if any(key in data for key in ('webEvalAcks','webEvalMissing','webBridgeReports')):
        lines.append(f'- WebKit telemetry handshake: **{data.get("webEvalAcks",0)} returned eval snapshots**, **{data.get("webBridgeReports",0)} bridge messages**, **{data.get("webEvalMissing",0)} evals without usable snapshots**. The eval return path works independently of the message bridge.')
        badbridge=sum((numeric(d.get('bridgeFailed')) or 0)>0 for d in rawdocs if isinstance(d,dict))
        if badbridge: lines.append(f'- **Warning:** {badbridge} reports signaled a WebKit message-bridge failure; eval-returned snapshots may still retain timing aggregates.')
    if 'webPeriodicSamples' in data or 'webPeriodicFailures' in data:
        lines.append(f'- Armed WebKit sampling: **{data.get("webPeriodicSamples",0)} successful 5-second snapshots**, **{data.get("webPeriodicFailures",0)} missing/error snapshots**. Missing samples are not zero work or zero latency.')
    samples=[x for x in data.get('sampleDiagnostics',[]) if isinstance(x,dict)]
    if samples:
        waits=[numeric(x.get('evalMs')) for x in samples]
        waits=[x for x in waits if x is not None]
        codes=sorted({int(x.get('errorCode') or 0) for x in samples if x.get('errorCode')})
        lines.append(f'- Periodic evaluation wait: **{fmt(max(waits) if waits else None)}** maximum; WebKit error codes: **{codes or "none"}**. This includes IPC and scheduling, not just script execution.')
    if any('inputArrival' in d for d in docs):
        lines.append('- Input arrival measures event timestamp to capture listener; task delay measures listener to a queued task; event-loop lag measures a 250 ms foreground heartbeat. They are distinct proxies, not hardware presentation latency.')
    lines+=theme_work_report(data)
    lines.append(f'- Theme preference enabled when armed: **{data.get("themeEnabledAtArm", "unknown")}** (same phone, same network and menu required for an A/B comparison).')
    # Link navigation controller appearances to adjacent WebView loading starts.
    # The heuristic is never presented as a definitive ownership mapping.
    events=[(numeric(x.get('atMs')),str(x.get('controllerClass',''))) for x in (data.get('controllerTransitions') or []) if isinstance(x,dict)]
    events=[x for x in events if x[0] is not None]
    intervals=[]
    for entry in (data.get('webLoadingIntervals') or []):
        if not isinstance(entry,dict):continue
        at=numeric(entry.get('atMs'));dur=numeric(entry.get('loadingMs'))
        if at is None or dur is None:continue
        candidates=[(abs(t-at),name) for t,name in events if abs(t-at)<=3000]
        source=min(candidates)[1] if candidates else 'unattributed'
        if 'SXWebResultsViewController' in source:source='Search Results'
        elif 'AMIWebViewController' in source:source='Product Detail'
        intervals.append((source,at,dur))
    if intervals:
        lines.append('')
        lines+=['| WebKit loading timeline (controller correlation is approximate) | Began at | loading-state duration |', '| --- | ---: | ---: |']
        for name,at,dur in intervals[:20]:lines.append(f'| {name} | {fmt(at)} | {fmt(dur)} |')
    lines.append('- Web observer types supported during capture: **'+(', '.join(sorted(supported)) or 'none reported')+'**.')
    if not docs:lines.append('- **Warning:** no WebKit document report. Web metrics are unavailable, NOT zero.')
    if data.get('otherDiagnosticObserved'):lines.append('- **Warning:** Another diagnostic overlapped this capture; comparisons may be distorted.')
    lines+=['','**Interpretation:** Native lanes are inclusive and must not be summed. Bucket P95 is an upper bound only. CADisplayLink/RAF gaps measure callback cadence, **not actual rendered FPS or hardware presentation latency**. WebKit navigation fields depend on document completion and are not directly comparable to server latency or cold app startup.']
    return '\n'.join(lines)


def delta(current,baseline):
    lines=['## Comparison (same device, same menu, comparable workflow required)','| Metric | Baseline | Current | Change |','| --- | ---: | ---: | ---: |']
    def add(name,b,c,scale=1,unit='ms'):
        if b is None or c is None:lines.append(f'| {name} | n/a | n/a | n/a |');return
        change=c-b; lines.append(f'| {name} | {fmt(b*scale,unit)} | {fmt(c*scale,unit)} | {change*100/b:+.1f}% ' + ('(higher is worse)' if change>0 else '(lower is better)') + ' |' if b else f'| {name} | {b} | {c} | n/a |')
    for name in ['nativeFrames','touchEventAge']:
        b=baseline.get(name) or {}; c=current.get(name) or {}
        add(name+' mean', (numeric(b.get('totalMs')) or 0)/b['count'] if b.get('count') else None, (numeric(c.get('totalMs')) or 0)/c['count'] if c.get('count') else None)
    for name in LANES:
        b=(baseline.get('lanes') or {}).get(name) or {};c=(current.get('lanes') or {}).get(name) or {}
        add(name+' mean', (numeric(b.get('totalMs')) or 0)/b['count'] if b.get('count') else None,(numeric(c.get('totalMs')) or 0)/c['count'] if c.get('count') else None)
    lines.append('**Note:** These deltas are descriptive. Missing, different-session, or diagnostic-overlap data invalidate a strict regression claim.')
    return '\n'.join(lines)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('session',help='Current opt-in performance TAR or JSON')
    p.add_argument('--baseline',help='An earlier performance TAR/JSON for paired comparison')
    p.add_argument('--output',help='Write Markdown report here (stdout otherwise)')
    a=p.parse_args()
    cur=load(a.session)
    if not isinstance(cur,dict) or 'lanes' not in cur:raise SystemExit('Not an AmazonDark performance-session JSON')
    sections=['# AmazonDark Performance Session',brief_report(cur)]
    if a.baseline:
        base=load(a.baseline)
        if not isinstance(base,dict) or 'lanes' not in base:raise SystemExit('Baseline is not an AmazonDark performance-session JSON')
        sections += [brief_report(base,'Baseline'),delta(cur,base)]
    out='\n\n'.join(sections)+'\n'
    if a.output:Path(a.output).write_text(out)
    else:print(out)

if __name__=='__main__':main()
