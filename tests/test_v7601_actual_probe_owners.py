"""Verify real v7.600 captured DOM owners, not invented selector-only test HTML."""
import json,re,subprocess
from pathlib import Path
from lxml import etree
import cssselect2,tinycss2
ROOT=Path(__file__).resolve().parents[1]
js=(ROOT/'src/ADPDPProbeOwners7601.js').read_text()
assert ''.join(json.loads(x) for x in (ROOT/'src/ADPDPProbeOwners7601.js.inc').read_text().splitlines())==js
assert 'ADPDPProbeOwners7601.js.inc' in (ROOT/'src/Tweak.xm').read_text()
assert all(s not in js for s in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame('])
subprocess.run(['node','--check',str(ROOT/'src/ADPDPProbeOwners7601.js')],check=True)
fixture=json.loads((ROOT/'tests/fixtures/v7601_probe_owners.json').read_text())
css=js.split('var css=`',1)[1].split('`;',1)[0].replace('__FACTOR__','0.420')
matcher=cssselect2.Matcher()
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
 if rule.type!='qualified-rule':continue
 ds={d.lower_name:tinycss2.serialize(d.value).strip() for d in tinycss2.parse_declaration_list(rule.content) if d.type=='declaration'}
 for sel in cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude)):matcher.add_selector(sel,ds)

def styles(key):
 """Reconstruct only captured ancestor tokens. No hand-invented owner IDs/classes."""
 n=fixture[key]; parts=n['chain'].split('<-');parent=None
 for tok in reversed(parts):
  # The probe truncates chains to 8 ancestors; skip ellipsis/hash suffixes.
  m=re.match(r'^([a-zA-Z][\w-]*)(?:#([\w-]+))?((?:\.[\w-]+)*)',tok)
  if not m:continue
  tag,ident,classes=m.groups(); e=etree.Element(tag)
  if ident:e.set('id',ident)
  if classes:e.set('class',' '.join(classes.lstrip('.').split('.')))
  if parent is not None:parent.append(e)
  else:root=e
  parent=e
 # The capture limits ancestry to 8 tokens. Its separate viewport owner record
 # proves this aisle widget lives inside #ax-mbs; rejoin those two REAL records.
 if key in ('fbt_untamed','complement_image','complement_plus'):
  overlay=etree.Element('div',id='dp')
  if key=='complement_image':
   owner=etree.Element('div',id='sims-complements_feature_div_0')
   owner.append(root);overlay.append(owner)
  else:overlay.append(root)
  root=overlay
 if key in ('progress_outer','progress_track','progress_fill'):
  overlay=etree.Element('div',id='ax-mbs')
  overlay.append(root);root=overlay
 if key=='aisle_image':
  overlay=etree.Element('div',id='ax-mbs')
  widget=etree.Element('div',id='ee-aisles-on-uss-widget-container')
  widget.append(root);overlay.append(widget);root=overlay
 assert parent is not None,key
 wrap=cssselect2.ElementWrapper.from_xml_root(root)
 leaf=list(wrap.iter_subtree())[-1]
 matched={}
 for spec,order,pseudo,ds in matcher.match(leaf):
  if pseudo is None:
   for k,v in ds.items():matched[k]=(spec,order,v)
 return {k:v[2] for k,v in matched.items()}

assert fixture['brand_gradient']['bgImage']=='gradient'
assert fixture['brand_gradient']['border'][1]=='rgb(213, 217, 217)'
assert styles('brand_gradient')['background']=='#000'
assert styles('brand_gradient')['background-image']=='none'
assert styles('brand_gradient')['border-color']=='#494d4d'
assert fixture['brand_logo']['filter']=='none'
assert fixture['brand_stars']['filter']=='none'
assert 'filter' not in styles('brand_logo') and 'filter' not in styles('brand_stars')
assert fixture['aisle_image']['filter']=='none'
assert styles('aisle_image')['filter']=='brightness(0.420)'
assert fixture['close_outline']['outline'][0]=='3px'
assert styles('close_outline')['outline']=='none'
assert styles('close_outline')['outline-width']=='0'
assert fixture['progress_outer']['radius']=='0px'
assert fixture['progress_track']['bg']=='rgb(255, 255, 255)'
assert styles('progress_outer')['border-radius']=='999px'
assert styles('progress_track')['background']=='#44494b'
assert styles('progress_track')['border-radius']=='999px'
assert styles('progress_fill')['border-radius']=='999px 0 0 999px'
assert fixture['fbt_untamed']['filter']=='none'
assert styles('fbt_untamed')['filter']=='brightness(0.420)'
assert fixture['complement_image']['filter']=='brightness(0.42)'
assert styles('complement_image')['filter']=='brightness(0.420)'
assert styles('complement_plus')['background']=='#303335'
assert styles('complement_plus')['border-color']=='#202324'
assert fixture['complement_plus']['bg']=='rgb(48, 51, 53)'
assert fixture['bundle_white_border']['border'][1]=='rgb(216, 220, 220)'
assert styles('bundle_white_border')['border-top-color']=='#494d4d'
print('PASS: v7.601 exact captured owners: brand gradient, brand text/art isolation, Shop Aisles IMG, purple focus ring, pill meter/gray remainder, FBT untamed image, bundle white top border, complementary media/buttons')
