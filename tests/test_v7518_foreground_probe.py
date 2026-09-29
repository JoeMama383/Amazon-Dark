from pathlib import Path
R=Path(__file__).resolve().parents[1]
u=(R/'src/ADUniversalUIProbe7362.inc').read_text()
p=(R/'src/ADPersonReturns7514.inc').read_text()
# Discovery must use the same foreground predicate in all three web collection paths.
assert 'webs&&[v isKindOfClass:[WKWebView class]]&&ADUIRendererExposed7518(v)' in u
assert u.count('!ADUIRendererExposed7518(wv)') == 2
assert 'if(hit==v||[hit isDescendantOfView:v])return YES;' in u
assert 'if(n.clipsToBounds)rect=CGRectIntersection' in u
assert 'NATIVE_FIRST_DISCOVERY' in u and 'native,0,path,cap,scanWeb' in u
assert 'NATIVE_MOVE selected=' in u and 'offset-not-accepted' in u
assert 'fabs(settled-nmax)' in u
# Only outer card gets the foreground contour; every nested wrapper is borderless.
f=p[p.index('static void ADPersonOwnReturnsCard7514'):p.index('static void ADPersonPrimeReturns7514')]
assert f.index('if(!outer)return;') < f.index('[CAShapeLayer layer]')
assert 'ADPersonSetRCTBorder7208(v,0.0)' in f
assert 'ADPersonSetRCTBorder7208(v,1.0)' not in f
assert 'ol.zPosition=FLT_MAX' in f and 'CGRectInset(v.bounds,0.5,0.5)' in f
assert 'if(!outer&&ol)' in f
print('PASS: foreground-only discovery, native-first scheduling, measured scroll progress and one unobscured Returns contour')

handler=u[u.index('static void ADUIHandleWillResignActive7447'):u.index('static void ADCaptureThreeTabProbe7254')]
assert handler.index('ADUIConsumeViewportArm7362()') < handler.index('gADUIProbeBusy7362')
assert 'ADUIViewportBusyBoundary7518()' in handler
assert 'web=omitted coverage=partial' in u
