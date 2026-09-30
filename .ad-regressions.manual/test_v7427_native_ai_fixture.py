"""Probe topology/neutral-palette checks; not an iOS rendering test."""
import json,re,subprocess,tempfile,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'src/Tweak.xm').read_text()
nodes=json.loads((ROOT/'tests/fixtures/v7427_native_ai_results.json').read_text())
children={n['id']:[] for n in nodes}
for n in nodes:
 if n['parent']>=0:children[n['parent']].append(n['id'])
block=src.split('static UIView *ADAlexaResultsRoot7427')[1].split('static BOOL ADAlexaResultsHasChild7427')[0]
limit=int(re.search(r'depth<(\d+)',block)[1]);budget=int(re.search(r'seen>(\d+)',block)[1])
root_name,marker=re.findall(r'isEqualToString:@"([^"]+)"',block)
def owner(i):
 for _ in range(limit):
  if i<0:return None
  n=nodes[i]
  if n['aid']==root_name:
   seen=0
   for a in children[i]:
    seen+=1
    for b in children[a]:
     seen+=1
     for c in children[b]:
      seen+=1
      if seen>budget:return None
      if nodes[c]['aid']==marker:return i
   return None
  i=n['parent']
 return None
root=next(n['id'] for n in nodes if n['aid']=='root-container')
expected=set()
for n in nodes:
 i=n['id']
 while i>=0:
  if i==root:expected.add(n['id']);break
  i=nodes[i]['parent']
actual={n['id'] for n in nodes if owner(n['id']) is not None}
assert actual==expected and len(actual)==429,(len(actual),len(expected))
assert {n['aid'] for n in nodes if n['id'] in actual}>={'back-button','cardboard-background','disclosure-banner','alexa-for-shopping-logo'}
# Losing the distinguishing marker must stop ownership, including generic roots.
marker_node=next(n for n in nodes if n['aid']=='cardboard-background');marker_node['aid']='unrelated-header'
assert all(owner(n['id']) is None for n in nodes)
# Compile the actual neutral-color predicate expression, checking both observed
# neutral tones and representative semantic colors rather than duplicating it.
body=src.split('static BOOL ADDarkNeutral7259')[1].split('static BOOL ADPersonSavingsDarkNeutral7259')[0]
expr=re.search(r'return (\(hi-lo\).*?);',body)[1]
cpp='''#include <algorithm>
#include <cassert>
bool neutral(double r,double g,double b){double hi=std::max(r,std::max(g,b)),lo=std::min(r,std::min(g,b));return EXPR;}
int main(){assert(neutral(.059,.067,.067));assert(neutral(.337,.349,.349));assert(!neutral(.047,.345,.820));assert(!neutral(1,.4,0));assert(!neutral(0,.48,.24));assert(!neutral(1,1,1));}
'''.replace('EXPR',expr)
compiler=shutil.which('g++') or shutil.which('clang++')
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(cpp)
 if compiler:
  subprocess.run([compiler,str(p/'test.cpp'),'-o',str(p/'test')],check=True);subprocess.run([str(p/'test')],check=True)
 else:print('SKIP: compiled palette check (no C++ compiler available)')
print('PASS: all 429 AI-result nodes scoped; unrelated roots rejected')
