"""Actual shipped cascade on probe-shaped medical/chat nodes."""
import json
from pathlib import Path
import tinycss2, cssselect2
from lxml import html
from payload_source import block
ROOT=Path(__file__).resolve().parents[1]
js=''.join(json.loads(line) for line in (ROOT/'src/ADNewMenus7482.js.inc').read_text().splitlines() if line.strip())
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
matcher=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
    if rule.type!='qualified-rule':continue
    try: sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError:continue
    ds={d.lower_name:(tinycss2.serialize(d.value).strip(),d.important) for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
    for sel in sels:matcher.add_selector(sel,ds)
doc=html.fromstring('''<div id="a-page"><div id="main-content" class="ap-lego"><a id="nav-link-health-ai-mobile"><img id="sparkle"/></a><div class="kyanite-nav-logo-img" id="brand"></div><div class="background-color-off-white" id="hero"><h1 class="color-squid" id="title">Your health</h1><span class="color-health-text" id="teal">made easy</span></div><button class="pui-button yellow-round-button" id="cta">Get started</button><div class="color-health-dark" id="copy">Treatment</div><pui-divider id="divider"></pui-divider></div><div id="warblerApplicationRoot"><div data-testid="wfe-sidebar-mobile" id="sidebar"><p class="O8hGCkXk" id="sidebar-copy">Instructions</p><button class="arc-button" id="signin">Sign in</button></div><div data-testid="wfe-app-header" id="header"></div><div data-testid="wfe-assistant-message"><div id="answer">Response</div></div><div class="wwEJQMuD"><button class="pmIXYaVR" id="terms">Terms</button></div><div data-testid="pill-option-0-container" id="pill"><div class="r-vxra60" id="pilltext">Suggestion</div></div><div id="input-container"><div class="hpUFzdnr" id="composer"></div></div><button class="tWrZhXu7"><svg><path id="close"/></svg></button></div><div id="unrelated" class="background-color-off-white color-health-dark">Unrelated</div></div>''')
nodes={e.etree_element.get('id'):e for e in cssselect2.ElementWrapper.from_html_root(doc).iter_subtree() if e.etree_element.get('id')}
def paint(id,prop,pseudo=None):
    wins=[]
    for spec,order,ps,ds in matcher.match(nodes[id]):
        if ps!=pseudo or prop not in ds:continue
        value,important=ds[prop];wins.append(((important,spec,order),value))
    return max(wins)[1] if wins else None
for id in ['title','copy','answer','sidebar-copy','pilltext']:
    assert paint(id,'color')=='#fff',(id,paint(id,'color'))
for id in ['header','sidebar','composer','cta','signin']:
    assert paint(id,'background')=='#000',(id,paint(id,'background'))
assert paint('hero','background-color')=='#000'
assert paint('pill','background')=='#303335'
assert paint('divider','background')=='#494d4d'
assert paint('close','fill')=='#fff'
for id in ['teal','terms','unrelated']:assert paint(id,'color') is None,id
for id in ['sparkle','brand']:assert paint(id,'filter')=='none',id
assert paint('input-container','background','before')=='linear-gradient(transparent,#000)'
source=(ROOT/'src/Tweak.xm').read_text();media=block(source,'ADPharmacyMediaJS7563')
assert '.image.image-size-fit>img,.healthai-storefront-carousel-card img,video' in media
assert '0.10+0.48*MAX(0,MIN(100,gP.whiteTameStrength))/100.0' in media
assert 'BOOL medical=fabs(r)<.01&&fabs(g-40.0/255.0)<.01&&fabs(b-52.0/255.0)<.01' in source
print('PASS: v7.584 medical/chat cascade restores text and controls, preserves semantic paint, excludes glyphs from dimming')
# Parse the real emitted Objective-C format at preference endpoints; assert leaf scope.
from payload_source import strings
import subprocess,tempfile
fmt=strings(media)
for factor in (1.,.9,.684,.42):
    emitted=fmt%(factor,factor)
    with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
        f.write(emitted);f.flush();subprocess.run(['node','--check',f.name],check=True,capture_output=True)
    rules=emitted.split("s.textContent='",1)[1].split("';",1)[0]
    media_matcher=cssselect2.Matcher()
    for rule in tinycss2.parse_stylesheet(rules):
        if rule.type!='qualified-rule':continue
        for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):media_matcher.add_selector(sel,True)
    art=html.fromstring('<div id="main-content" class="ap-lego"><a id="nav-link-health-ai-mobile"><img id="glyph"/></a><div class="image image-size-fit"><img id="photo"/></div><div class="healthai-storefront-carousel-card"><img id="tile"/></div><div class="image image-size-custom"><img id="sparkle"/></div><video id="film"/></div>')
    matched={e.etree_element.get('id') for e in cssselect2.ElementWrapper.from_html_root(art).iter_subtree() if media_matcher.match(e)}
    assert matched=={'photo','tile','film'},matched
print('PASS: One Medical media payload parses at disabled/0/45/100 strengths and only artwork leaves match')
