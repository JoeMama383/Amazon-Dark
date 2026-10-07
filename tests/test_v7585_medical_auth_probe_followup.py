"""Probe-shaped regression for v7.585 One Medical / Health AI / verification follow-up."""
import json
from pathlib import Path
import tinycss2, cssselect2
from lxml import html
from payload_source import block, strings
import subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
inc=(ROOT/'src/ADNewMenus7482.js.inc').read_text()
js=''.join(json.loads(line) for line in inc.splitlines() if line.strip())
assert 'function ad7585WarblerShadow()' in js
assert 'arc-button[data-testid=\\"wfe-sidebar-cid-signin-btn\\"]' in js
assert "q.id='ad7585-sidebar-cid-style'" in js
for bad in ('MutationObserver(', 'setInterval(', 'setTimeout(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in js, bad

css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
matcher=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
    if rule.type!='qualified-rule': continue
    try: sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
    except cssselect2.SelectorError: continue
    ds={d.lower_name:(tinycss2.serialize(d.value).strip(),d.important)
        for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
    for sel in sels: matcher.add_selector(sel,ds)

doc=html.fromstring('''<html><body>
<div id="a-page"><div id="root"><div><pui-loading-indicator class="pui-loading-indicator" id="loading"><div class="circle" id="spinner"></div></pui-loading-indicator></div></div></div>
<div id="people-picker-parent-container">
  <h1 class="pui-heading black-color" id="picker-title">Who is using One Medical?</h1>
  <span class="pui-text black-color" id="picker-sub">Choose account holder</span>
  <div class="pui-sub-nav-person-icon" id="avatar"><div class="pui-text black-color" id="avatar-letter">A</div></div>
  <div class="pui-text dark-grey-color" id="picker-gray">secondary</div>
  <div class="pui-icon chevron-right" id="picker-chevron"></div>
  <a class="pui-link link-color" id="picker-link">Add adult</a>
  <pui-divider id="picker-divider"></pui-divider>
</div>
<div id="warblerApplicationRoot">
  <button class="bbVzSV55" data-csa-c-slot-id="warbler-chat-quick-action-cos-static-contents-override_quick_action_check_symptoms" id="quick">Check symptoms</button>
  <div class="ssyRqSbd EwAzg4W1" data-csa-c-slot-id="warbler-chat-conv-card-abc" id="card">
    <div class="X5qnxnlL" id="image-lane"><img id="card-image"/></div>
    <div class="a2laKri9" id="card-copy"><h3 class="_5l7LqHGU" id="card-title">Need treatment?</h3><div class="_73fyFmE-" id="card-body">Care</div><span class="Q6Chms9f" id="card-blue">dynamic</span><span class="yv9yvOR2" id="card-gray">gray</span></div>
  </div>
  <textarea id="chat-input-textarea"></textarea>
</div>
<div class="cvf-widget-container"><div class="cvf-page-layout"><div id="cvf-page-content"><div class="a-box" id="auth-box"><div class="a-box-inner">
<form id="verification-code-form"><h1 id="auth-title">Verify</h1><div id="instruction_text"><span id="auth-copy">Enter code</span></div><div id="otp_box_label"><label class="a-form-label" id="auth-label">Code</label></div><div id="cvf-input-code-container"><div class="a-input-text-wrapper" id="auth-input-wrap"><input id="cvf-input-code"/></div></div><span id="cvf-submit-otp-button"><span class="a-button-inner"><span class="a-button-text" id="verify-text">Verify</span></span></span></form>
</div></div></div></div></div>
<div class="a-divider-inner" id="auth-divider"></div><span class="a-color-secondary" id="auth-gray">secondary</span><a class="a-link-normal" id="auth-link">link</a>
</body></html>''')
wrap=cssselect2.ElementWrapper.from_html_root(doc)
nodes={e.etree_element.get('id'):e for e in wrap.iter_subtree() if e.etree_element.get('id')}

def paint(node_id,prop,pseudo=None):
    wins=[]
    for spec,order,ps,ds in matcher.match(nodes[node_id]):
        if ps!=pseudo or prop not in ds: continue
        value,important=ds[prop]; wins.append(((important,spec,order),value))
    return max(wins)[1] if wins else None

# Standalone One Medical picker: exact neutral paint, dynamic link untouched.
assert paint('picker-title','color')=='#fff'
assert paint('picker-sub','color')=='#fff'
assert paint('avatar','background')=='#303335'
assert paint('avatar','border-color')=='#747a7c'
assert paint('avatar-letter','color')=='#fff'
assert paint('picker-gray','color')=='#b1b5b5'
assert paint('picker-divider','background')=='#494d4d'
assert paint('picker-chevron','filter')=='brightness(0) invert(1)'
assert paint('picker-link','color') is None
assert paint('picker-link','-webkit-text-fill-color')=='currentColor'

# Warbler exact owners from r1/r3.
assert paint('quick','background')=='#303335'
assert paint('quick','border-color')=='#747a7c'
assert paint('quick','color')=='#fff'
assert paint('card','background')=='#000'
assert paint('image-lane','background')=='#000'
assert paint('card-title','color')=='#fff'
assert paint('card-body','color')=='#fff'
assert paint('card-blue','color') is None
assert paint('card-blue','-webkit-text-fill-color')=='currentColor'
assert paint('card-gray','color')=='#b1b5b5'
assert paint('chat-input-textarea','background')=='#000'

# OTP/auth owner from r5: OLED card/button, white neutral copy, gray authored divider/secondary text.
assert paint('loading','background')=='#000'
assert paint('spinner','background') is None
assert paint('auth-box','background')=='#000'
assert paint('auth-box','border-color')=='#494d4d'
for i in ('auth-title','auth-copy','auth-label','verify-text'):
    assert paint(i,'color')=='#fff',(i,paint(i,'color'))
assert paint('auth-input-wrap','background')=='#181a1b'
assert paint('cvf-input-code','background')=='#181a1b'
assert paint('cvf-submit-otp-button','background')=='#000'
assert paint('cvf-submit-otp-button','border-color')=='#747a7c'
assert paint('auth-divider','border-top-color')=='#494d4d'
assert paint('auth-gray','color')=='#b1b5b5'
assert paint('auth-link','color') is None
assert paint('auth-link','-webkit-text-fill-color')=='currentColor'

# Configured white-tame now reaches only the recommendation artwork leaf, not structural/glyph nodes.
source=(ROOT/'src/Tweak.xm').read_text(); media=block(source,'ADPharmacyMediaJS7563'); fmt=strings(media)
assert '#warblerApplicationRoot div.ssyRqSbd.EwAzg4W1[data-csa-c-slot-id^=warbler-chat-conv-card-] .X5qnxnlL img' in media
emitted=fmt%(.684,.684)
rules=emitted.split("s.textContent='",1)[1].split("';",1)[0]
mm=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(rules,skip_comments=True,skip_whitespace=True):
    if rule.type!='qualified-rule': continue
    for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)): mm.add_selector(sel,True)
art=html.fromstring('''<div id="warblerApplicationRoot"><div class="ssyRqSbd EwAzg4W1" data-csa-c-slot-id="warbler-chat-conv-card-1"><div class="X5qnxnlL"><img id="art"/></div><svg><path id="glyph"/></svg></div></div>''')
matched={e.etree_element.get('id') for e in cssselect2.ElementWrapper.from_html_root(art).iter_subtree() if e.etree_element.get('id') and mm.match(e)}
assert matched=={'art'},matched

with tempfile.NamedTemporaryFile(mode='w',suffix='.js') as f:
    f.write(js); f.flush(); subprocess.run(['node','--check',f.name],check=True,capture_output=True)
print('PASS: v7.585 probe-shaped medical/auth follow-up fixes exact owners while preserving semantic colors and non-recurring runtime policy')
