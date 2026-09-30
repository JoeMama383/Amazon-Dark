from pathlib import Path
R=Path(__file__).resolve().parents[1]
u=(R/'src/ADUniversalUIProbe7362.inc').read_text()
p=(R/'src/ADPersonReturns7514.inc').read_text()
t=(R/'src/Tweak.xm').read_text()

# FULL Person must use the exact historically proven React wrapper and its real scroll descendant.
assert 'static UIView *ADUIPersonWrapper7519' in u
assert '[cn isEqualToString:@"RCTScrollView"]&&[v.accessibilityIdentifier isEqualToString:@"me"]&&v.window&&ADUIViewActuallyVisible7362(v)' in u
assert 'RCTCustomScroll' in u
assert 'static void ADUIScanPersonFull7519' in u
assert 'hydrationMs=340' in u and 'maxSteps=40' in u
assert 'PERSON_FULL_MOVE step=' in u and 'PERSON_FULL_SCAN_END' in u
assert '[root setContentOffset:original animated:NO]' in u
assert 'root.scrollEnabled=NO' not in u
assert 'scrollEnabledPreserved=' in u
assert 'ADUIScanPersonFull7519(path,cap' in u
assert 'personPriority=before-PDP-detection' in u
assert u.index('UIView *personWrap=ADUIPersonWrapper7519();') < u.index('ADUIDetectPDPSession7451(webs,^')
# Other non-PDP screens retain the pre-7.500-equivalent generic route; PDP stays DOM-owned.
assert 'ADUINativeScrollCandidatesAsync7449' in u
assert 'PDP_READONLY_NATIVE_SCROLL policy=skipped reason=DOM-walker-owns-product-scrolling' in u
assert 'ADUIRendererExposed7518' not in u
assert 'ADUIViewportBusyBoundary7518' not in u
handler=u[u.index('static void ADUIHandleWillResignActive7447'):u.index('static void ADCaptureThreeTabProbe7254')]
assert handler.index('gADUIProbeBusy7362') < handler.index('ADUIConsumeViewportArm7362()')

# Returns ownership must preserve React/Amazon geometry and change paint only.
body=p[p.index('static void ADPersonOwnReturnsCard7514'):p.index('static void ADPersonPrimeReturns7514')]
assert 'ADPersonReturnsBorderColors7519(v);' in body
assert 'ADPersonSetRCTBorder7208' not in body
assert 'borderWidth=' not in body
assert 'setBorderRadius:' not in body
assert '[CAShapeLayer layer]' not in body
assert 'UIBezierPath' not in body
helper=p[p.index('static void ADPersonReturnsBorderColors7519'):p.index('static void ADPersonOwnReturnsCard7514')]
assert 'setBorderColor:' in helper and 'setBorderTopColor:' in helper and 'setBorderEndColor:' in helper
assert 'setBorderWidth:' not in helper.replace('// Paint-only React border reassertion. Intentionally NO setBorderWidth:, edge-width,\n// radius, frame, bounds, transform, mask, or custom outline writes.\n','')
assert 'setBorderRadius:' not in helper
assert 'v.layer.borderWidth>0.01' in helper and 'v.layer.borderColor=gray.CGColor' in helper

# Hydration-time React color setters must be constrained without constraining widths/radii.
for meth in ['setBorderColor','setBorderTopColor','setBorderRightColor','setBorderBottomColor','setBorderLeftColor']:
    assert f'- (void){meth}:(UIColor *)value' in t
assert t.count('if(gP.enabled&&ADPersonReturnsCard7514(') >= 5
assert 'setBorderStartColor:' in helper and 'setBorderEndColor:' in helper
width_hook=t[t.index('- (void)setBorderWidth:(CGFloat)value'):t.index('- (void)setBorderColor:(UIColor *)value')]
assert 'ADPersonReturnsCard7514' not in width_hook
radius_hook=t[t.index('- (void)setBorderRadius:(CGFloat)value'):t.index('- (void)setBorderWidth:(CGFloat)value')]
assert 'ADPersonReturnsCard7514' not in radius_hook

print('PASS: v7.519 exact Person deep scan + restored viewport boundary + paint-only Returns border geometry')
