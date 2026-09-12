from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JS=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
assert 'Version: 7.416~location-canonical-owner' in C
assert '#define AD_VERSION "v7.416-location-canonical-owner"' in S
# latent help typed-query list
assert '#help_srch_sggst' in S and '#suggested-help-topics-wrapper' in S
# add-address latent location feedback/error states
assert '#address-ui-widgets-address-form-location-autofill-feedback-message .a-changeover-inner' in S
assert '#address-ui-widgets-location-detection-error-touch-link' in S
# pickup latent alerts: own floor/text but do not replace authored red/green border colors
seg=S.split('// v7.395 re-audit: Bolt also pre-mounts zero-rect success/error alert cards.',1)[1].split('// v7.394 FULL r1 (17:28):',1)[0]
assert '.a-alert-success' in seg and '.a-alert-error' in seg
assert 'border-color:' not in seg
# Current probe identity aligned
assert 'VER=7.416' in UI
assert 'AD_PROBE_VERSION=7.416' in SK and 'AD_PROBE_NAME=AmazonDark-v7.416' in SK
assert 'AMAZONDARK v7.416 UNIVERSAL' in INC
assert "version:'7.416'" in JS
# Architecture remains static/event-driven
new=S.split('// v7.395 re-audit:',1)[1]
for bad in ['MutationObserver(', 'setInterval(', 'requestAnimationFrame(']:
    assert bad not in new
print('PASS: v7.398 retains v7.395 typed-help, address-location, and pickup-alert latent white-state fixes')
