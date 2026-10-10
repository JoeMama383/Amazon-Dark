"""Captured v7.555 FULL/VIEWPORT owners; real cascade checks when CSS tooling exists."""
from pathlib import Path
import json, subprocess, shutil, tempfile
from payload_source import payload
R=Path(__file__).resolve().parents[1]
js=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
css=js.split('s.textContent=`',1)[1].split('`;',1)[0]
new=css.split('/* v7.556 captured ',1)[1].split('/* End v7.556',1)[0]
for token in ('a.sf-filter-floatbox','a.sf-bottom-nav-btn.sf-show-results','border-top:1px solid #494d4d','li.a-carousel-card.s-tile:has(.scx-stt)','[class*=_c2Itd_pdcol_]'):
 assert token in new,token
for token in ('width:','height:','padding:','margin:','border-radius:','display:','opacity:','filter:'):
 assert token not in new,token
S=(R/'src/Tweak.xm').read_text()
for strength,factor in ((0,'.900'),(45,'.684'),(100,'.420')):
 twb=payload(S,'ADTWBJS',strength)
 assert '#search .scx-pt-price-budget,#search .scx-pt-price-indulgent,' in twb
 # Emit actual program and collect the Search stylesheet, validating formatting and route.
 harness="""var out={};global.location={hostname:'www.amazon.com',pathname:'/s'};global.window=global;global.top=global;global.document={getElementById:()=>null,createElement:()=>({}),head:{appendChild:s=>{}},documentElement:{setAttribute:()=>{}}};document.createElement=()=>{var s={};Object.defineProperty(s,'textContent',{set:v=>{out[s.id]=v}});return s};"""
 code=harness+twb+";process.stdout.write(out['ad7-product-feed-twb']);"
 result=subprocess.run([shutil.which('node'),'-e',code],capture_output=True,text=True)
 assert result.returncode==0,result.stderr
 assert 'brightness(0'+factor+')' in result.stdout
try:
 import tinycss2, cssselect2
 from lxml import html
except ImportError:
 print('PASS: captured owners, paint-only scope and Search strength 0/45/100; SKIP optional CSS matcher')
 raise SystemExit(0)
fixture='''<html><body><div id="dropdown-content-s-all-filters"><div id="sf-filters-vtabs"><div class="s-vtabs-contents-container"><a id="choice" class="a-link-normal sf-filter-floatbox"><span id="label">Steel</span><i id="star" class="a-icon a-icon-star"></i></a></div></div></div><div id="footer" class="sf-bottom-nav sf-bottom-nav-current"><a id="results" class="a-link-normal sf-bottom-nav-btn sf-show-results"><span id="count">Show 283 results</span></a></div><div id="search"><div class="s-tiles-carousel"><li id="tile" class="a-carousel-card s-tile"><div class="scx-stt"><div id="caption" class="scx-stt-title">Wooden</div></div></li></div><div data-csa-c-painter="sb-video-product-collection-mobile-cards"><li id="adcard" class="a-carousel-card"><div id="adcopy" class="a-column _c2Itd_pdcol_3gSOx">Wensilon<i id="adstar" class="a-icon-star"></i></div></li></div></div><div id="unrelated" class="_c2Itd_pdcol_3gSOx"></div></body></html>'''
matcher=cssselect2.Matcher()
# Simulate authored white/yellow rules arriving AFTER theme; important specificity must win.
css+='\n.sf-filter-floatbox{background:#fff!important}.sf-rib-pill-redesign .sf-show-results,.sf-bottom-nav.sf-bottom-nav-current .sf-show-results{background:#ffd814!important}'
for rule in tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True):
 if rule.type!='qualified-rule':continue
 try: sels=cssselect2.compile_selector_list(tinycss2.serialize(rule.prelude))
 except cssselect2.SelectorError:continue
 decls=[d for d in tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True) if d.type=='declaration']
 for sel in sels:matcher.add_selector(sel,decls)
styles={}
for el in cssselect2.ElementWrapper.from_html_root(html.fromstring(fixture)).iter_subtree():
 id=el.etree_element.get('id');wins={}
 for spec,order,pseudo,ds in matcher.match(el):
  if pseudo:continue
  for d in ds:
   rank=(d.important,spec,order)
   if d.name not in wins or rank>=wins[d.name][0]:wins[d.name]=(rank,tinycss2.serialize(d.value).strip())
 if id:styles[id]={k:v[1] for k,v in wins.items()}
for id in ('tile','caption','adcard','adcopy','results'): assert styles[id]['background']=='#000',(id,styles[id])
assert styles['choice']['background']=='#303335'
for id in ('choice','label','results','count'):assert styles[id]['-webkit-text-fill-color']=='#fff'
assert styles['footer']['border-top']=='1px solid #494d4d'
assert styles['footer']['border-bottom']=='0'
assert styles['results']['border']=='1px solid #747a7c'
assert 'background' not in styles['unrelated']
for id in ('star','adstar'):assert 'filter' not in styles[id]
print('PASS: captured Filters/Search cascade, detached footer divider, glyph preservation and strength bounds')
