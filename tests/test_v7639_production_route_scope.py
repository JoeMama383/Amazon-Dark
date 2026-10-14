"""v7.639: production Search/PDP render work reduced without deleting menu paint."""
from pathlib import Path
import hashlib, json, re, shutil, subprocess, tempfile
r=Path(__file__).resolve().parents[1]
t=(r/'src/Tweak.xm').read_text()
assert '#define AD_VERSION "v7.639-search-pdp-render-scope"' in t
assert 'static NSString *ADSkipPDPOnSearchHome7639(' in t
core=t.split('static NSString *ADCoreWebJS7271(void){',1)[1].split('static NSString *ADThemeProgram7637(',1)[0]
for method in ('ADPDPCompletionJS7405','ADPDPCompletionTWBJS7405','ADPDPUICompletionJS7439','ADPDPMainResidualJS7440'):
    assert method+'()' in core and '#define '+method+'() ADSkipPDPOnSearchHome7639('+method+'())' in t,method
assert 'ADPDPProbeBackedFixesJS7458()' in core, 'Do not suppress mixed PDP + Returns JS'
assert 'if(window.top===window&&(p===\'/\'||p===\'/s\'||p.indexOf(\'/s/\')===0))return' in t

inc=r/'src/ADNewMenus7482.js.inc'
original=''.join(json.loads(line) for line in inc.read_text().splitlines())
assert 's.textContent=`' in original
scope=''.join(json.loads(line) for line in (r/'src/ADNewMenusScope7639.js.inc').read_text().splitlines())
assert '#include "ADNewMenusScope7639.js.inc"' in t
assert 'base=[base stringByReplacingCharactersInRange:assignment' in t
assert 'base=[base stringByReplacingCharactersInRange:end withString:scope7639];' in t
assert original.count('`;\n// v7.594: arc-button')==1
js=original.replace('s.textContent=`','var ad7639AllCSS=`',1).replace('`;\n// v7.594: arc-button',scope,1)
assert js!=original
assert 'var ad7639Hot=window.top===window' in js
assert js.count('s.textContent=ad7639CSS;')==1
assert 'setInterval(' not in js and 'MutationObserver(' not in js
css=original.split('s.textContent=`',1)[1].split('`;',1)[0]
# Byte-for-byte original 7.638 CSS: no authored colors/geometry/images changed.
assert hashlib.sha256(css.replace('v7.639','v7.638').encode()).hexdigest()=='6e0157c06835898f8c6443d561825853181b5b3adc863fe55d00d5317ef9ea50'
owners=json.loads(re.search(r'var ad7639Unrelated=(\[[^;]+\]);',js).group(1))
# Conservative top-level CSS selector-list parser: a comma in :is() is not
# a new selector. Every skipped rule must be rooted in off-route owners.
def selector_list(s):
    out=[];start=0;paren=0;bracket=0;quote='';escape=False
    for i,ch in enumerate(s):
        if escape:escape=False;continue
        if ch=='\\':escape=True;continue
        if quote:
            if ch==quote:quote=''
            continue
        if ch in "'\"":quote=ch
        elif ch=='(':paren+=1
        elif ch==')':paren-=1
        elif ch=='[':bracket+=1
        elif ch==']':bracket-=1
        elif ch==',' and paren==0 and bracket==0:
            out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip())
    return out
cut=[line for line in css.splitlines() if line.startswith(tuple(owners))]
assert len(cut)==164,len(cut)
for line in cut:
    assert '{' in line and '}' in line, 'Only complete one-line CSS rules may be excluded'
    for selector in selector_list(line.split('{',1)[0]):
        assert selector.startswith(tuple(owners)),(selector,line)
assert '#dp#dp #promoPriceBlockMessage_feature_div' in css
assert '#search' in css
assert '#warblerApplicationRoot' in css
assert 'body:has(.memory-grid-container.mobile)' in css

# Execute the real first-paint payload on four document types. In Search and
# PDP, only unrelated owners are absent; on nonhot or child docs all rules stay.
if shutil.which('node'):
    prefix=js.split('// v7.594: arc-button',1)[0]+'\n}catch(e){throw e;}})();\n'
    harness='''const vm=require('vm');const script=__SOURCE__;let data={};
function paint(route,child){const sheet={id:'ad7482-new-menus',textContent:''};
 const d={head:{appendChild(){}},getElementById(){return sheet},createElement(){return sheet}};
 const w={};w.top=child?{}:w;
 vm.runInNewContext(script,{document:d,window:w,location:{pathname:route}});
 return sheet.textContent;
}
const full=paint('/gp/your-saves',false),home=paint('/',false),search=paint('/s',false),pdp=paint('/dp/B0EXAMPLE',false),frame=paint('/s',true);
const count=x=>x.split('\\n').filter(z=>z.includes('{')&&z.includes('}')).length;
const out={full:count(full),home:count(home),search:count(search),pdp:count(pdp),frame:count(frame),
 exactFull:full===__CSS__,sameNonhot:home===full,sameFrame:frame===full,searchPaint:search.includes('#search'),pdpPaint:pdp.includes('#dp#dp'),
 removedMedical:!search.includes('#warblerApplicationRoot'),menuRetained:full.includes('#warblerApplicationRoot')};
 process.stdout.write(JSON.stringify(out));
'''.replace('__SOURCE__',json.dumps(prefix)).replace('__CSS__',json.dumps(css))
    with tempfile.TemporaryDirectory(prefix='ad7639-') as temp:
        scriptfile=Path(temp)/'test.js'
        scriptfile.write_text(harness)
        proc=subprocess.run(['node',str(scriptfile)],text=True,capture_output=True,timeout=25)
    assert proc.returncode==0,proc.stderr
    results=json.loads(proc.stdout)
    assert results['exactFull'] and results['sameNonhot'] and results['sameFrame']
    assert results['full']-results['search']==164,results
    assert results['full']-results['pdp']==164,results
    assert results['searchPaint'] and results['pdpPaint']
    assert results['removedMedical'] and results['menuRetained']
    print('PASS: real document-start CSS keeps full nonhot/child styling, removes 164 off-route rules on Search/PDP')
else:
    print('PASS: static scope and selector-list guard (Node execution unavailable)')
