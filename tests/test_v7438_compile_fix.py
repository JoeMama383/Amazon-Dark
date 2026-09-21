from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.438~compile-fix' in C
assert '#define AD_VERSION "v7.438-compile-fix"' in S
assert 'class*="widgetId=container-search-results_sponsored"' not in S
assert "class*='widgetId=container-search-results_sponsored'" in S
start=S.index('static NSString *ADCheckoutTWBJS7369')
end=S.index('// v7.378:', start)
f=S[start:end]
assert f.count('%.3f') == 8, f.count('%.3f')
tail=f[f.index('return [NSString stringWithFormat:'):]
assert tail.count(',factor') == 8, tail.count(',factor')
print('PASS: v7.438 repairs the Search Objective-C literal and balances checkout format arguments 8/8')
