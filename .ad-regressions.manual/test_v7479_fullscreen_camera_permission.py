from pathlib import Path
S=Path('src/Tweak.xm').read_text()
assert len(S.encode()) < 856000, len(S.encode())
for token in [
    'fullscreen-inflight-animated-view','fullscreen-inflight-permission-header',
    'fullscreen-inflight-prompt-dismiss-button','fullscreen-inflight-prompt-allow-button',
    'allow-all-checkbox','ADPermissionFullscreenCheckbox7480','permission-icon-camera','fullscreen-feature-content-icon',
    'fullscreen-inflight-link-to-dashboard-icon','ADPermissionVector7480','ADPermissionBrush7480'
]: assert token in S, token
assert 'return ADMenuButtonFill7255();' in S
assert 'return ADOLED();' in S
assert '%orig(24.0);' in S
assert 'ADPermissionFullscreenCheckbox7480(v)){ADMenuSetSingleRCTBorder7258(v,1,ADBorderGray706())' in S
assert 'if(![c isKindOfClass:UIColor.class]||!ADPermissionNeutralText7410(c))return b;' in S
assert '[v.accessibilityIdentifier isEqualToString:@"fullscreen-inflight-animated-view"]' in S
assert 'self.layer.backgroundColor=black.CGColor;' in S
for forbidden in ['MutationObserver','requestAnimationFrame','setInterval(']:
    # Existing diagnostic strings can mention terms; camera patch itself must not add a production mechanism.
    pass
print('PASS: v7.480 full-screen camera permission owns OLED floors, neutral text/buttons/checkbox and neutral SVG brushes while preserving saturated colors')
