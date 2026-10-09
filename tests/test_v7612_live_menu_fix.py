"""v7.612: native Amazon Live viewer/report sheet theming and video tame."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
control=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.612~live-menu-fix' in control
assert '#define AD_VERSION "v7.612-live-menu-fix"' in s
for token in [
    'static BOOL ADLiveReportSheet7612(UIView *v)',
    'static BOOL ADLiveTitlePlate7612(UIView *v)',
    'static BOOL ADLiveFollowPill7612(UIView *v)',
    'static void ADLiveOwnVideo7612(UIView *v)',
    '%hook AmazonIvsView',
    'ADLiveOwnVideo7612((UIView *)self);',
    'ADLiveOwnVector7612((UIView *)self);',
    'if(ADLiveOwnView7612(v))return;',
    'if(ADLiveTextOwner7612(v)){ ADLiveOwnText7612(v); return; }',
    'UIColor *live=ADLiveForcedBackground7612(self,color);',
    'if(live){',
    'AnimatedFollowButton',
    'AnimatedButtonGradient',
    'AnimatedFollowButtonText',
    'overflow-submenu-report',
    'bottom-sheet-content',
    'bottom-sheet-close-icon',
    'expandable-text-title',
    'expandable-scrollview',
    'IVSPlayer',
]:
    assert token in s, token
# Ensure the gradient is suppressed instead of introducing new geometry.
assert 'v.hidden=YES; v.alpha=0.0;' in s
# Preserve the requested OLED/gray button treatment.
assert 'v.layer.borderColor=ADMenuButtonBorder7255().CGColor;' in s
assert 'ADSetViewBackground7226(v,ADOLED(),YES);' in s
print('PASS v7.612: native live viewer/report-sheet/follow button/video ownership wired and versioned')
