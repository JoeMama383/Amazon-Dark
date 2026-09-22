from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
assert 'Version: 7.447~probe-responsiveness' in C
assert '#define AD_VERSION "v7.447-probe-responsiveness"' in S
needle=".s-widget-container[class*=\'widgetId=container-search-results_sponsored\']>.s-container-results"
assert needle in S
seg=S[S.index(needle):S.index(needle)+1000]
for tok in ['background:#000!important','background-color:#000!important','border-left-color:#000!important','border-right-color:#000!important']:
    assert tok in seg,tok
for bad in ('new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'"):
    assert bad not in seg,bad
print('PASS: v7.437 owns the probe-confirmed white sponsored-results parent rail')
