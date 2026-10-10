"""CSS owner/cascade test of v7.620 selectors on sanitized probe-equivalent DOMs."""
from pathlib import Path
import tinycss2, cssselect2
from lxml import html
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/ADOrderAdsPrivacy7620.js').read_text()
css=source.split('style.textContent=`',1)[1].split('`;',1)[0].replace('__AD7620_ORDER_IMAGES__','')
rules=tinycss2.parse_rule_list(css,skip_comments=True,skip_whitespace=True)
assert not [x for x in rules if x.type=='error']
matcher=cssselect2.Matcher()
for rule in rules:
    if rule.type!='qualified-rule':continue
    decls=tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True)
    assert not [x for x in decls if x.type=='error'],rule
    payload={x.lower_name: tinycss2.serialize(x.value).strip() for x in decls if x.type=='declaration' and x.important}
    for selector in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):
        matcher.add_selector(selector,payload)

def paint(markup, target):
    doc=html.fromstring(markup)
    compiled=cssselect2.compile_selector_list(target)
    for elt in cssselect2.ElementWrapper.from_html_root(doc).iter_subtree():
        if any(sel.test(elt) for sel in compiled):
            color={}
            for match in matcher.match(elt):color.update(match[-1])
            return color
    raise AssertionError('missing target')

landing='''<html data-ad7620-adprefs="1"><body><div id="a-page">
<h1 class="header-text-mobile">Advertising Privacy and Preferences</h1>
<div class="a-container container-background"><div class="a-box-group">
<div class="a-box a-box-normal"><div class="a-box-inner">
<a id="mobileDataDeleteButton" class="a-touch-link a-box"><div class="a-box-inner"><span>Delete ad data</span><i class="a-icon a-icon-touch-link"></i></div></a></div></div>
<div class="a-box a-box-normal"><div class="a-box-inner">
<a id="mobileAdPreferenceButton" class="a-touch-link a-box"><div class="a-box-inner"><span>Interest-based</span><i class="a-icon a-icon-touch-link"></i></div></a></div></div>
</div><span class="column-text"><span class="a-size-large">Legal policies</span><a>Privacy Notice</a></span></div></div></body></html>'''
assert paint(landing,'.container-background')['background']=='#000'
assert paint(landing,'#mobileDataDeleteButton')['background']=='#000'
assert paint(landing,'#mobileAdPreferenceButton')['background']=='#000'
assert paint(landing,'#mobileDataDeleteButton span')['color']=='#fff'
assert paint(landing,'#mobileDataDeleteButton i')['border-color']=='#fff'
assert paint(landing,'.column-text a')['-webkit-text-fill-color']=='currentColor'
assert 'background' not in paint(landing,'h1.header-text-mobile') # authored teal stays intact

prefs='''<html data-ad7620-adprefs="1"><body><div id="a-page"><a class="back-button a-box a-touch-link a-color-alternate-background"><div class="a-box-inner"><span class="back-button-text">Amazon Advertising Preferences</span><i class="a-icon a-icon-touch-link"></i></div></a>
<div class="a-container"><span class="a-size-large">Interest-based ad preferences</span>
<div class="a-box-group a-spacing-base"><div class="a-box a-first a-box-title"><div class="a-box-inner">Select your preference</div></div>
<div class="a-box a-last"><div class="a-box-inner"><div class="a-radio a-radio-fancy"><span>Show me interest-based ads</span></div><span id="optOutControl" class="a-button"><span class="a-button-inner"><span class="a-button-text">Submit</span></span></span>
<div class="a-row a-expander-container a-expander-extend-container"><div class="a-expander-content a-expander-extend-content"><p>Information</p></div></div>
</div></div></div></div></div></body></html>'''
assert paint(prefs,'.back-button')['background']=='#000'
assert paint(prefs,'.a-box.a-first.a-box-title')['background']=='#000'
assert paint(prefs,'.a-box.a-last')['background']=='#000'
assert paint(prefs,'#optOutControl')['background']=='#000'
assert paint(prefs,'#optOutControl')['border-color']=='#747a7c'
assert paint(prefs,'#optOutControl .a-button-text')['color']=='#fff'
assert paint(prefs,'.a-expander-content p')['color']=='#fff'

orders='''<html><body><div id="a-page"><div class="od-modernized"><div class="a-container a-color-base-background od-container"><div class="a-subheader"><h4>Your Orders</h4></div>
<div class="a-cardui-deck"><div class="a-cardui"><div class="a-cardui-body"><div class="a-box-group oui-shipment-card"><div class="a-box"><div class="a-box-inner"><h3>Now arriving</h3><div class="od-milestone-marker"></div><div class="od-milestone-marker active"></div><div class="od-milestone-bar active"></div></div></div>
<a class="a-expander-header a-declarative a-expander-section-header">See details</a><div class="a-row a-expander-container"><span class="a-button a-button-primary"><span class="a-button-inner"><a class="a-button-text">Track package</a></span></span></div>
</div></div></div></div></div></div></body></html>'''
assert paint(orders,'.od-container')['background']=='#000'
assert paint(orders,'.a-cardui')['background']=='#000'
assert paint(orders,'.a-expander-header')['background']=='#000'
assert paint(orders,'.a-button-primary')['background']=='#000'
assert paint(orders,'.a-button-text')['color']=='#fff'
assert paint(orders,'.od-milestone-marker')['background']=='#000'
assert 'background' not in paint(orders,'.od-milestone-marker.active')
assert 'background' not in paint(orders,'.od-milestone-bar.active')
print('PASS: v7.620 probe-equivalent selector match and black/white/gray existing-border CSS cascade')
