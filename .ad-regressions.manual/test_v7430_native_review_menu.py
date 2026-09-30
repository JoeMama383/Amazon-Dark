"""Topology checks from the supplied FULL capture; no device rendering claim."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/Tweak.xm').read_text()
ns=json.loads((ROOT/'tests/fixtures/v7430_native_review_menu.json').read_text())
by={n['id']:n for n in ns};children={i:[] for i in by}
for n in ns:
 if n['parent']>=0:children[n['parent']].append(n)
rootcode=s.split('static UIView *ADReviewMenuRoot7430')[1].split('static int ADReviewMenuButton7430')[0]
limit=int(re.search(r'i<(\d+)',rootcode)[1]);marker=re.search(r'isEqualToString:@"([^"]+)"',rootcode)[1]
def owner(n):
 for _ in range(limit):
  if n is None:return None
  if n['aid']==marker:return n['id']
  n=by.get(n['parent'])
 return None
owned=[n for n in ns if owner(n) is not None]
assert len(owned)>100
code=s.split('static int ADReviewMenuButton7430')[1].split('static UIColor *ADReviewMenuFill7430')[0]
names=re.findall(r'isEqualToString:@"([^"]+)"',code)
actions=set(names[:3]);content,details=names[3:]
def role(n):
 if n['aid'] in actions:return 1
 p=by.get(n['parent']);gp=by.get(p['parent']) if p else None
 if not gp or gp['aid']!=content:return 0
 if n['aid']==details:return 2
 if n['cls']=='RCTView' and any(c['aid']==details for c in children[p['id']]):return 3
 return 0
roles={k:[n for n in owned if role(n)==k] for k in [1,2,3]}
assert [len(roles[k]) for k in [1,2,3]]==[3,1,1]
svgs=[n for n in owned if n['cls']=='RNSVGSvgView']
ask=[];attribution=[];untouched=[]
for n in svgs:
 p=by[n['parent']];gp=by[p['parent']]
 if role(gp)==3:ask.append(n)
 elif any(c['cls']=='RCTTextView' for c in children[p['id']]) and any(c['aid']=='aspect-list' for c in children[gp['id']]):attribution.append(n)
 else:untouched.append(n)
assert len(ask)==len(attribution)==1
assert len(untouched)==11 # eight colored/neutral topic symbols + three black action glyphs
assert sum(n['cls']=='UIVisualEffectView' for n in owned)==1
assert 'if(ADReviewMenuVector7430(svg))return;' in s
assert 'if(ADReviewMenuRoot7430(v)){ ADMenuLightStorage7255(textStorage); return YES; }' in s
# Removing the modal marker must reject all descendants and unrelated native UI.
root=by[owner(owned[0])];root['aid']='unrelated-modal'
assert all(owner(n) is None for n in ns)
print('PASS: native review topology: 3 gray actions, 1 OLED details, 1 gray Ask; only Ask gradient and attribution SVG change; 11 glyphs preserved')
