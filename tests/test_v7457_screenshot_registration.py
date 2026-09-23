from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
P=(R/'src/ADUniversalUIProbe7362.inc').read_text()
RPL=(R/'prefs/Resources/Root.plist').read_text()
assert '%hook AXFScreenshotToastPresenter' in T
hook=T.split('%hook AXFScreenshotToastPresenter\n',1)[1].split('%end',1)[0]
assert '- (void)didDetectScreenshot:(id)notification' in hook
assert 'gADDisableShareSheetForProbes7458' in hook
assert '%orig(notification);' in hook
assert '%hook NSNotificationCenter' not in T
assert 'ADScreenshotObservers7457.h' not in T
assert 'ADScreenshotRegistrationReport7457' not in P
assert 'disableShareSheetForProbes' in RPL
assert 'Hide Share Sheet for Probes' in RPL
assert 'closeScreenshotShareForFull' not in RPL
for forbidden in ['removeObserver','postNotification','setInterval','evaluateJavaScript','dispatch_after']:
    assert forbidden not in hook
print('PASS: v7.460 suppresses only the probe-recorded screenshot presenter callback')
