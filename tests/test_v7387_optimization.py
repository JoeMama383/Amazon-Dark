"""Golden semantic contracts derived from the supplied v7.386 source, plus execution tests.
No browser, account, npm package or third-party Python dependency is required.
"""
from pathlib import Path
import hashlib,json,re,subprocess,shutil,os
from payload_source import payload,block
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text();A=(ROOT/'src/ADSponsored.m').read_text()
golden=json.loads((ROOT/'tests/v7386_semantic_baseline.json').read_text())
def digest(s):return hashlib.sha256(s.encode()).hexdigest()
for name,expected in golden['programs'].items():
    assert digest(payload(S,name))==expected, name+' changed beyond the approved CSS shorthand compaction'
# Expand comma lists without splitting inside quotes, attributes or pseudo-classes.
def selectors(s):
    out=[];start=0;quote=None;escape=False;depth=0
    for i,c in enumerate(s):
        if quote:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c==quote:quote=None
        elif c in ('"',"'"):quote=c
        elif c in '([':depth+=1
        elif c in ')]':depth-=1
        elif c==',' and depth==0:out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip());return out
js=payload(A,'ADKillerSponsoredJS7384')
css=json.loads(re.search(r'textContent=("(?:\\.|[^"\\])*")',js)[1])
rules=[]
for group,body in re.findall(r'([^{}]+)\{([^{}]+)\}',css):
    group=selectors(group)
    if any(':has(' in x for x in group):assert len(group)==1,'relational rule lost isolation'
    rules.extend((sel,body) for sel in group)
assert len(rules)==golden['sponsored_selectors']==86
assert digest(json.dumps(rules,separators=(',',':')))==golden['sponsored_rules_sha256'],'sponsored scope, specificity, cascade order or declaration changed'
for name,h in golden['probe_sha256'].items():
    data=(ROOT/'src'/name).read_bytes()
    if name=='ADUniversalUIProbe7362.js.inc':data=data.replace(b"version:'7.388'",b"version:'7.386'")  # capture-version metadata only
    assert hashlib.sha256(data).hexdigest()==h, name
assert 'ADHomeFrameProbeBridgeJS7265' not in S and '__adHomeProbeReq7265' not in S
# Script sharing is bounded, maintains order, document-start timing and frame scope.
expected=[('ADCoreWebJS7271','NO','YES'),('ADKillerSponsoredJS7384','NO','NO'),('ADPriceHistoryJS7380','YES','NO'),('ADTWBJS','NO','YES'),('ADCheckoutFloorJS7369','NO','NO'),('ADCheckoutTWBJS7369','NO','YES'),('ADCheckoutBYGHydrateJS7378','YES','NO'),('ADPrivacyModeJS7117','NO','NO')]
positions=[]
for slot,(fn,main,strength) in enumerate(expected):
    token=f'ADSharedUserScript7387({slot},{fn},{main},{strength})';assert S.count(token)==1;positions.append(S.index(token))
assert positions==sorted(positions)
assert 'static WKUserScript *scripts[8]={nil}' in S
assert 'strengthDependent&&strengths[slot]!=strength' in S
assert 'injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:mainOnly' in S
remove=S[S.index('- (void)removeAllUserScripts'):S.index('- (void)removeAllContentRuleLists')]
assert remove.index('kADCoreWebUS7271,nil')<remove.index('if(gP.enabled)'), 'disabled UCC clear kept stale receipts'
assert 'lookUpContentRuleListForIdentifier:@"AmazonDarkPrivacy7118"' in S
assert '[ADTWBJS() stringByAppendingString:ADCheckoutTWBJS7369()]' in S
# Preserve Amazon's actual caches/network configuration; optional privacy blocker is unchanged in scope.
for forbidden in ['setWebsiteDataStore:','removeDataOfTypes:','removeAllCachedResponses','setCachePolicy:','setURLCache:','setProcessPool:']:
    assert forbidden not in S,forbidden
programs={'hydrate':payload(S,'ADCheckoutBYGHydrateJS7378'),'clear':payload(S,'ADTWBClearJS791'),'privacy':payload(S,'ADPrivacyModeJS7117')}
if shutil.which('node'):
    subprocess.run(['node',str(ROOT/'tests/test_v7387_runtime.cjs')],input=json.dumps(programs),text=True,check=True)
elif os.environ.get('AD_STRICT_VALIDATE')=='1':raise AssertionError('node required in CI for runtime regressions')
else:print('SKIP: Node execution unavailable on this device; strict CI enforces it')
print('PASS: v7.386 CSS semantic hashes, all 86 sponsored selectors, unchanged probe payloads, script/cache contracts')
