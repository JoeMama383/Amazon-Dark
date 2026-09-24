from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.479~timer-actionbar-edge' in C
assert '#define AD_VERSION "v7.479-timer-actionbar-edge"' in S
assert len(S.encode()) < 856000, len(S.encode())
# 1: Home Buy Again Rufus pill rows: exact family only, OLED/gray/white.
for t in ('[data-csa-c-painter=Buy-Again-Rufus-Pills-Card][class*=_pillRow_]{background:#000!important;border-color:#747a7c!important;color:#fff!important;box-shadow:none!important}',
          '[data-csa-c-painter=Buy-Again-Rufus-Pills-Card][class*=_pillRow_] [class*=_pillText_]'):
    assert t in S,t
# 2: Countdown numeric chips exclude the -Bottom label family by requiring the exact _Timer-Numeric__ class fragment.
assert '[id^=atf-countdownCard-Text-Timer-Numeric-][class*=_Timer-Numeric__]' in S
assert '[id^=atf-countdownCard-Text-Timer-Numeric-][class*=_Timer-Numeric__]{background:#000!important;box-shadow:inset 0 0 0 64px #000!important}' in S
# 3: Home billboard raster joins the existing configured whiteTame selector, not a hard-coded filter value.
assert '[class*=_billboard-card_regularStyle_gwm-BillboardCard] img' in S
assert '[class*=_billboard-card_regularStyle_gwm-BillboardCard--cropped__]{background:#000!important' in S
# 4: Top tab repairs inner markup instead of imposing copied pixel geometry on the outer anchor.
r=S[S.index('static NSString *ADPDPProbeBackedFixesJS7458'):S.index('static NSString *ADCoreWebJS7271')]
assert "var q=function(){var t=d.getElementById('btfSubNavTopTab')" not in r
for t in ('#btfSubNavTopTab .top-tab-content,#btfSubNavTopTab .top-tab-content>div{display:contents!important;font:inherit!important}',
          '#btfSubNavTopTab .a-icon-section-collapse{display:none!important}',
          '#btfSubNavTopTab .a-size-mini{font:inherit!important}'):
    assert t in r,t
# 5: Medium standalone ad keeps the card OLED but cannot black-cover its sibling content at z=100.
g=S[S.index('static NSString *ADPDPGridCarouselFix7454'):S.index('static NSString *ADPDPCompletionJS7405')]
assert '.sp_hqp_phoneapp_shared_responsive_box_rem{background:#000!important;border-color:#494d4d!important' in g
assert '#sp_hqp_phoneapp_shared_inner{background:transparent!important;box-shadow:none!important}' in g
# 6: Root WKScrollView keeps vertical white semantics while horizontal indicator is suppressed exactly.
w=S[S.index('%hook WKScrollView'):S.index('%end',S.index('%hook WKScrollView'))+4]
assert 'self.indicatorStyle=UIScrollViewIndicatorStyleWhite;self.showsHorizontalScrollIndicator=NO;' in w
assert '- (void)setShowsHorizontalScrollIndicator:(BOOL)show' in w
assert 'strcmp(object_getClassName(self), "WKScrollView")==0){' in w and '%orig(NO);' in w
assert '- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style' in w
# Three independent probe workflows remain versioned and TAR-based.
for h in ('## FULL — v7.479','## VIEWPORT — v7.479','## TRANSITION — v7.479'): assert h in CMD
assert 'export full' in CMD and 'export viewport' in CMD and 'skeleton-probe.sh export' in CMD
print('PASS: v7.479 preserves the six v7.478 Home/PDP ownership repairs while hardening the countdown owner')
