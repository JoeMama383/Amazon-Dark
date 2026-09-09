from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
A=(ROOT/'src/ADSponsored.m').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
S=(ROOT/'src/Tweak.xm').read_text()
assert 'Version: 7.386~sponsored-shell-ownership' in C
assert '#define AD_VERSION "v7.386-sponsored-shell-ownership"' in S
assert 'mobile-gateway-atf_Spons' in A
assert 'npack-asin-card-cards' in A
assert '_widget-sponsored-badge-container_' in A
# Do not return to broad descendant promotion that caused the v7.381 carousel regression.
assert '#gwm-dashboard>li.gwm-tile:has([class*=' not in A
# New ownership rules have one :has each, not nested :has().
prefix=A.split('#gwm-dashboard>li.gwm-tile:has(>span.a-list-item>div[data-ad-id])',1)[0]
assert prefix.count(':has(')==2
print('PASS: v7.386 collapses only the two probe-proven sponsored outer shells')
