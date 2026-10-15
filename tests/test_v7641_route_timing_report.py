"""Offline attribution must not blend different pages or misidentify child frames."""
from pathlib import Path
import importlib.util
import copy

root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('performance_report',root/'scripts/performance-report.py')
report=importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)
data={
    'themeWork':[
        {'documentId':10,'timeOriginMs':10000,'mainFrame':True,'route':1,'themeRules':700,'durationMs':500},
        {'documentId':10,'timeOriginMs':10001,'mainFrame':True,'route':1,'themeRules':710,'durationMs':1000},
        {'documentId':20,'timeOriginMs':20000,'mainFrame':True,'route':2,'themeRules':730,'durationMs':1000},
    ],
    'webDocuments':[
        {'documentId':101,'timeOriginMs':10003,'durationMs':1000,
         'inputToNextRAF':{'count':2,'totalMs':300,'maxMs':200},
         'eventLoopLag':{'count':4,'totalMs':400,'maxMs':250},'navigationMs':{'domInteractive':900}},
        {'documentId':101,'timeOriginMs':10003,'durationMs':500,
         'inputToNextRAF':{'count':1,'totalMs':100,'maxMs':100}},
        {'documentId':102,'timeOriginMs':20002,'durationMs':1000,
         'inputToNextRAF':{'count':0,'totalMs':0,'maxMs':0},'navigationMs':{'domInteractive':0}},
    ]
}
pairs=report.matched_main_documents(data)
assert len(pairs)==2
assert pairs[0][0]['themeRules']==710 and pairs[0][1]['durationMs']==1000
out='\n'.join(report.route_timing_report(data))
assert '| Search / 101 | 710 | 2 | 150.0 ms | 200.0 ms | 250.0 ms | 900.0 ms |' in out
assert '| Product / 102 | 730 | 0 | n/a | n/a | n/a | n/a |' in out
# A same-time child frame makes attribution unsafe, even with only one web ID.
ambiguous=copy.deepcopy(data)
ambiguous['themeWork'].append({'documentId':30,'mainFrame':False,'timeOriginMs':10000})
assert [t['route'] for t,w in report.matched_main_documents(ambiguous)]==[2]
# Two independently reported web documents are also ambiguous.
ambiguous=copy.deepcopy(data)
ambiguous['webDocuments'].append({'documentId':999,'timeOriginMs':20004,'durationMs':100})
assert [t['route'] for t,w in report.matched_main_documents(ambiguous)]==[1]
assert report.route_timing_report({'themeWork':[{'mainFrame':True,'timeOriginMs':0}]})==[]
print('PASS: offline route timings deduplicate cumulative snapshots, reject ambiguous matches and retain missing values')
