"""Updated Amazon React profile sheet and conservative notifications fallback."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/Tweak.xm').read_text()
assert 'Version: 7.611~your-saves-oled-followup' in (Path(__file__).resolve().parents[1]/'layout/DEBIAN/control').read_text()
# Probe r6: new profile picker is not under AppCXWindow but AMSModalLayoutOverlay.
assert 'ADProfilePickerSheet7482' in s
assert '[a.accessibilityIdentifier isEqualToString:@"AMSModalLayoutOverlay"]' in s
assert 'if(!appWindow&&!modalWindow)return nil;' in s
assert '[aid isEqualToString:@"profile-picker-close-bottomsheet-button"]' in s
assert '[aid isEqualToString:@"sheet-inset-view"]' in s
for label in ('Switch_Accounts_Ingress','profile-picker-list-profile-item-row-0-account-holder'):
    assert label in s
assert 'ADProfilePickerInitialPaint7610(v);' in s
assert 'head<192' in s
assert 'ADPersonSavingsLightStorage7259(text);' in s
assert 'ADProfilePickerBackground7610(v,color)' in s
assert 'ADInPersonSavingsSheet7259(v)){ ADPersonSavingsLightStorage7259(textStorage); return YES;' in s
# The r7 data was NOT a notification feed.  Rule must fail closed for unconfirmed UI.
assert 'ADNotificationsController7610' in s
assert '[cls rangeOfString:@"Notification" options:NSCaseInsensitiveSearch]' in s
assert 'if(!react&&![v isKindOfClass:[UIImageView class]])return NO;' in s
assert 'ADNotificationsNeutralFloor7610(color)' in s
assert 'ADNotificationsFloorColor7610' in s
assert 'return ADBorderGray706();' in s
assert 'ADNotificationsImage7610(self);' in s
assert 'if(!iv.image)return;' not in s.split('static void ADNotificationsImage7610',1)[1].split('}',1)[0] # single combined guard
assert 'if(!gP.enabled||!gP.whiteTame||!iv||!iv.window||!iv.image)return;' in s
assert 'ADEnsureNativeTWBOverlay7270(iv);' in s
# No global background selector for notifications, no fixed text color override.
source=s.split('static BOOL ADNotificationsController7610',1)[1].split('static void ADOwnPersonSavingsFloor7259',1)[0]
assert 'return YES;' in source and 'return NO;' in source
assert 'ADNotificationsNeutralFloor7610' in source
for banned in ('dispatch_after','MutationObserver','setInterval','scrollTo','setBorderRadius','setNeedsLayout'):
    assert banned not in source
print('PASS: updated native profile exact owner and notification controller guard, untouched dynamic text')
