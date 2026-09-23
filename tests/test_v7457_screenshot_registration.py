from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
H=(R/'src/ADScreenshotObservers7457.h').read_text()
P=(R/'src/ADUniversalUIProbe7362.inc').read_text()
hook=T.split('%hook NSNotificationCenter\n',1)[1].split('%end',1)[0]
assert '%orig(observer,selector,name,object);' in hook
assert 'return %orig(name,object,queue,block);' in hook
assert 'gADScreenshotRegistrations7457.count>=64' in H
assert 'stack.count>12' in H
assert 'UIApplicationUserDidTakeScreenshotNotification' in H
assert 'ADScreenshotRegistrationReport7457(),cap' in P
for forbidden in ['removeObserver','postNotification','setInterval','evaluateJavaScript','userInfo','performSelector','dispatch_after']:
    assert forbidden not in hook
    assert forbidden not in H.replace('notification userInfo','notification payload')
assert '@"observer":observer' not in H
print('PASS: screenshot registration evidence is bounded, preserves registrations and never intercepts delivery')
