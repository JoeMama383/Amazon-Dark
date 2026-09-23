from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/'src/Tweak.xm').read_text()
video="[class*='_single-video-card_style_sponsored-label-pill__']{background:rgba(0,0,0,.6)!important;background-color:rgba(0,0,0,.6)!important;}"
creative="[class*='_single-creative-card_style_sponsored-label-pill__']{background:rgba(0,0,0,.6)!important;background-color:rgba(0,0,0,.6)!important;}"
assert video in T
assert creative in T
assert T.count(video)==1 and T.count(creative)==1
assert "[class*='sponsored-label-pill']" not in T
print('PASS: Home hero owns both captured Sponsored-pill variants at black/60% without a broad sponsored-label selector')
