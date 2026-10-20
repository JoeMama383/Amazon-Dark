#!/usr/bin/env python3
"""Static AmazonDark architecture census; opt-in probes are classified separately.

This intentionally counts SOURCE OCCURRENCES, not runtime invocations. It does not
claim that `querySelectorAll` or `setTimeout` executes on every frame, and the
absence of an API name cannot prove no scanner exists in Objective-C++.
"""
import argparse
import collections
import re
from pathlib import Path
import zipfile

MARKERS={
 'MutationObserver':r'\b(?:new\s+)?MutationObserver\s*\(',
 'setInterval':r'\bsetInterval\s*\(',
 'requestAnimationFrame':r'\brequestAnimationFrame\s*\(',
 'TreeWalker':r'\bcreateTreeWalker\s*\(',
 'querySelectorAll':r'\bquerySelectorAll\s*\(',
 'querySelector':r'\bquerySelector\s*\(',
 'getElementsByTagName':r'\bgetElementsByTagName\s*\(',
 'getComputedStyle':r'\bgetComputedStyle\s*\(',
 'getBoundingClientRect':r'\bgetBoundingClientRect\s*\(',
 'innerText':r'\binnerText\b',
 'attachShadow-hook':r'Element\.prototype\.attachShadow\s*=',
 'setTimeout':r'\bsetTimeout\s*\(',
 'addEventListener':r'\baddEventListener\s*\(',
 'scroll-listener':r'addEventListener\s*\(\s*[\x22\x27]scroll[\x22\x27]',
 'dispatch_after':r'\bdispatch_after\s*\(',
 'Logos-hook':r'(?m)^\s*%hook\s+',
 'WKUserScript':r'\bWKUserScript\b',
}
# Explicitly opt-in / unrelated to ordinary themed-page performance.
DIAGNOSTIC={
 'ADStartupIsolation7643.js','ADStartupIsolation7643.js.inc',
 'ADThemeWork7637.js','ADThemeWork7637.js.inc',
 'ADUniversalUIProbe7362.js.inc','ADUniversalUIProbe7362.frame.js.inc',
 'ADUIProbeViewportSample7449.js.inc','ADPDPMainStream7451.js.inc',
 'ADUIImmediate7568.js.inc','ADPerformance7596.js','ADPerformance7596.js.inc',
 'ADSkeletonProbe7339.js.inc','ADPDPShareGate7456.js.inc','ADPDPShareGate7456.js',
}
NATIVE_DIAG={'ADUniversalUIProbe7362.inc','ADSkeletonProbe7339.h','ADPerformance7596.inc'}


def extract(path):
    path=Path(path)
    if path.is_dir():
        return [(p.name, p.read_text(errors='replace'))
                 for p in (path/'src').glob('*') if p.is_file() and p.suffix in ('.xm','.m','.mm','.inc','.js','.h')
                 and not (p.name.endswith('.js.inc') and (p.parent/p.name[:-4]).exists())]
    if path.suffix!='.zip':raise ValueError('Expected a source tree or source ZIP')
    with zipfile.ZipFile(path) as archive:
        names=archive.namelist()
        matches=[n for n in names if '/src/' in n and not n.endswith('/') and n.rsplit('/',1)[-1].endswith(('.xm','.m','.mm','.inc','.js','.h')) and not (n.endswith('.js.inc') and n[:-4] in names)]
        return [(n.rsplit('/',1)[-1],archive.read(n).decode('utf-8','replace')) for n in matches]


def analyze(source):
    records=[];counters=collections.defaultdict(lambda:collections.Counter())
    for name,content in extract(source):
        group='opt-in diagnostics' if name in DIAGNOSTIC or name in NATIVE_DIAG else 'production / combined'
        # Treat Tweak.xm as combined since it also embeds probe harness hooks.
        if name=='Tweak.xm': group='native combined (production + diagnostic hooks)'
        counts={key:len(re.findall(pattern,content)) for key,pattern in MARKERS.items()}
        records.append((name,group,counts,len(content.encode('utf-8'))))
        counters[group].update(counts)
    return records,counters


def output(records,counters,title):
    lines=['# '+title,'','**Warning:** This is a static source-token census, not a runtime benchmark. `Tweak.xm` includes diagnostic and native logic, and counters measure occurrences, not rates. Diagnostic probes are dormant unless explicitly armed.','',
           '| Source group | Files | Code bytes (raw) | MutationObserver | setInterval | requestAnimationFrame | TreeWalker | querySelectorAll | setTimeout | native dispatch_after |',
           '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
    for group in sorted(counters):
        r=[x for x in records if x[1]==group]
        c=counters[group];size=sum(x[3] for x in r)
        lines.append('| '+group+' | '+str(len(r))+' | '+format(size,',')+' | '+' | '.join(str(c[x]) for x in ['MutationObserver','setInterval','requestAnimationFrame','TreeWalker','querySelectorAll','setTimeout','dispatch_after'])+' |')
    lines+=['','## Scanner and recurring-work sites','', '| Source file | Group | Patterns present |','|---|---|---|']
    for name,group,counts,size in sorted(records):
        hits=[f'{k}={counts[k]}' for k in ['MutationObserver','setInterval','requestAnimationFrame','TreeWalker','querySelectorAll','querySelector','getElementsByTagName','getComputedStyle','getBoundingClientRect','innerText','attachShadow-hook','setTimeout','scroll-listener'] if counts[k]]
        if hits: lines.append('| `src/'+name+'` | '+group+' | '+', '.join(hits)+' |')
    lines+=['','**Interpretation:** `querySelectorAll()` in a document-start one-shot is not equivalent to a recurring MutationObserver. Production source can include bounded DOM inspection on DOMContentLoaded/load; inspect the owner and gate before deleting. Explicit probes use TreeWalkers, RAF, and observers for their capture windows and must remain available.']
    return '\n'.join(lines)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',help='Versioned AmazonDark source ZIP or extracted source root')
    p.add_argument('--baseline',help='Optional older exact source ZIP/dir, e.g. v7.400')
    p.add_argument('--output',help='Path to write Markdown (otherwise stdout)')
    a=p.parse_args()
    r,c=analyze(a.source)
    report=output(r,c,'AmazonDark architecture census — current source')
    if a.baseline:
        br,bc=analyze(a.baseline)
        report+='\n\n'+output(br,bc,'Historical baseline source census')
        keys=['MutationObserver','setInterval','requestAnimationFrame','TreeWalker','querySelectorAll','setTimeout','Logos-hook']
        report+='\n\n## Source-code token delta (all groups, including diagnostics)\n\n| Pattern | Baseline | Current | Delta |\n|---|---:|---:|---:|\n'
        for k in keys:
            b=sum(x[k] for x in bc.values());v=sum(x[k] for x in c.values())
            report+=f'| {k} | {b} | {v} | {v-b:+} |\n'
    if a.output:Path(a.output).write_text(report+'\n')
    else:print(report)
if __name__=='__main__':main()
