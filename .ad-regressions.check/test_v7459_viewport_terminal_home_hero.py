from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
U=(R/'src/ADUniversalUIProbe7362.js.inc').read_text()
I=(R/'src/ADUniversalUIProbe7362.inc').read_text()
SH=(R/'scripts/ui-probe.sh').read_text()
SK=(R/'scripts/skeleton-probe.sh').read_text()
C=(R/'layout/DEBIAN/control').read_text()

assert 'Version: 7.470~pdp-isolated-frame-ownership' in C
assert '#define AD_VERSION "v7.470-pdp-isolated-frame-ownership"' in T
assert 'VER=7.470' in SH
assert 'AD_PROBE_VERSION=7.470' in SK and 'AD_PROBE_NAME=AmazonDark-v7.470' in SK

# Exact v7.458 VIEWPORT evidence: hero pill was rgba(255,255,255,0.6).
hero="""[class*='_single-video-card_style_sponsored-label-pill__']{background:rgba(0,0,0,.6)!important;background-color:rgba(0,0,0,.6)!important;}"""
assert hero in T
assert 'ad7461-home-hero-pill' in T
assert "#gwm-dashboard [class*='_single-video-card_style_sponsored-label-pill__']" not in T
assert "sponsored-label-pill__']{background:rgba(255,255,255,.6)" not in T

# VIEWPORT must finish in one JS evaluation rather than the v7.458 100+ continuation path.
assert 'limit=viewportOnly?maxNodes:32,budget=3' in U
assert 'viewportOnly||n===0||Date.now()-start<budget' in U
assert 'limit=viewportOnly?48:32' not in U
assert 'budget=viewportOnly?4:3' not in U
assert 'if(viewportOnly&&!intersects(r))return;cs=getComputedStyle(el)' in U
# FULL still owns the cooperative continuation machinery.
assert 'window.__adUIProbeContinue7446=more?pump:null' in U

# VIEWPORT terminal state is no longer delayed by FULL's 900 ms frame flush.
assert 'NSTimeInterval flushDelay=viewportOnly?0.20:0.90;' in I
assert 'CROSS_FRAME_FLUSH_WAIT policy=viewport-200ms/full-900ms' in I

# Export tolerates switching to NewTerm before the final state write.
assert 'if [ "$mode" = viewport ]; then' in SH
assert 'tries=$((tries+1)); [ "$tries" -ge 10 ] && break' in SH
assert 'sleep 1' in SH

# Preserve the hard production source-size gate rather than moving it.
assert len(T.encode()) < 856000, len(T.encode())
print('PASS: v7.470 makes VIEWPORT single-pass/terminal-safe and flips the exact home hero sponsored pill to black at the same alpha')
