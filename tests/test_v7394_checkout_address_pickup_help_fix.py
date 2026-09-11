from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'src/Tweak.xm').read_text()
C=(ROOT/'layout/DEBIAN/control').read_text()
UI=(ROOT/'scripts/ui-probe.sh').read_text()
SK=(ROOT/'scripts/skeleton-probe.sh').read_text()
INC=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
JSINC=(ROOT/'src/ADUniversalUIProbe7362.js.inc').read_text()
SB=(ROOT/'src/AmazonDarkSB.xm').read_text()

assert 'Version: 7.404~product-scroll-video-alexa-polish' in C
assert '#define AD_VERSION "v7.404-product-scroll-video-alexa-polish"' in S

# Add-address: exact stable AUI ids only, standard controls, visible raster glyphs.
for token in [
    '#address-ui-widgets-enterAddressFormContainer',
    '#address-ui-widgets-countryCode',
    '#address-ui-widgets-DetectLocationButton',
    '#address-ui-widgets-enterAddressStateOrRegion',
    '#address-ui-widgets-delivery-instructions-mobile-touch-link',
    '.address-ui-widgets-clear-icon .a-icon-close',
]: assert token in S, token
addr=S.split('// v7.394 FULL r5 (17:20):',1)[1].split('// v7.400 FULL r1 + v7.398 FULL r5/r6:',1)[0]
assert '#303335' in addr and '#747a7c' in addr and '#e8e6e3' in addr
assert '.a-icon-dropdown' in addr and '.a-icon-touch-link' in addr
assert '.a-icon-checkbox' not in addr and '.a-icon-radio' not in addr

# Pickup: exact root + stable IDs, black neutral UI, selected cue, no generic map/image taming.
pick=S.split('// v7.394 FULL r7 (17:25):',1)[1].split('// v7.394 FULL r1 (17:28):',1)[0]
for token in [
    '#bolt-widget-amazon_us_checkout_generic_mobile', '#country-dropdown',
    '#hubOrderingByRecommendationFilterByMobileId', '#hubOrderingByDistanceFilterByMobileId',
    '#hubOrderingByFastestFilterByMobileId', '#hubUseLowerLockerPrefBottomSheetTriggerButtonId',
    '#bolt-widget-card-panel', "[id^='bolt-widget-card-']", '.a-button-primary'
]: assert token in pick, token
assert 'box-shadow:inset 0 0 0 2px #007185!important' in pick
assert '#hubUseLowerLockerPrefBottomSheetTriggerButtonId{filter:none!important' in pick
# Do not overwrite the selected access-point card's authored orange left edge.
assert 'border-left' not in pick
assert '#Microsoft' not in pick  # map media belongs only to TWB, not static floor CSS

# Map TWB is scoped to the base road canvas. Labels/pins/accessibility UI stay unfiltered.
twb=S.split('static NSString *ADCheckoutTWBJS7369(void){',1)[1].split('// v7.378:',1)[0]
assert 'canvas#Microsoft\\\\.Maps\\\\.Imagery\\\\.LiteRoad' in twb
assert 'labelCanvasId' not in twb
assert 'hubUseLowerLockerPrefBottomSheetTriggerButtonId' not in twb

# Delivery/Pickup toggle: OLED for both; gray edge only for unselected; selected blue edge not overwritten.
tog=S.split('// v7.394 FULL r1 (17:28):',1)[1].split('// v7.394 FULL r1 (17:38):',1)[0]
assert '.edg-delivery-type-toggle-button:not(.a-button-selected)' in tog
assert 'border-color:#747a7c' in tog
assert '.edg-delivery-type-toggle-button.a-button-selected' not in tog
assert '.a-button-inner' in tog and '#e8e6e3' in tog

# Suggested topics are exact help family; star-note icon made visible on OLED.
helpb=S.split('// v7.394 FULL r1 (17:38):',1)[1].split('// v7.373 FULL r1/r2:',1)[0]
for token in ['#suggested-help-topics-wrapper','.suggested-help-topics-title','.suggested-help-topics-button','.star-note-icon']:
    assert token in helpb
assert '#000' in helpb and '#747a7c' in helpb and '#e8e6e3' in helpb

# WebKit HTML search now requests the same dark keyboard appearance as native text fields.
wk=S.split('%hook WKContentView',1)[1].split('%end',1)[0]
assert '- (BOOL)becomeFirstResponder' in wk
assert wk.count('ADPrepareSearchKeyboard7120')>=2
# Remote host/placeholder gets a dark trait only inside the existing hidden-dock gate.
lower=S.split('static void ADOwnLowerKeyboardSurface7130',1)[1].split('%hook UIInputSetHostView',1)[0]
assert 'overrideUserInterfaceStyle=UIUserInterfaceStyleDark' in lower
# Accessory-bar repair is scoped structurally to UIWebFormAccessory and hides only its full-width raster.
assert 'ADInWebFormAccessory7394' in S and 'UIWebFormAccessory' in S
bar=S.split('static BOOL ADInWebFormAccessory7394',1)[1].split('%hook UIInputSetHostView',1)[0]
assert 'kADWebFormBarImageHidden7394' in bar
assert 'r.size.width>=bar.bounds.size.width*0.90' in bar
assert 'r.size.height>=bar.bounds.size.height*0.80' in bar
assert 'iv.hidden=YES' in bar
assert '[UIColor whiteColor]' in bar
assert '%hook UIToolbar' in bar
# No global keyboard compositor filter / recurring machinery is introduced by v7.394.
new=S.split('// v7.394 FULL r5 (17:20):',1)[1]
for forbidden in ['new MutationObserver(', 'setInterval(', 'requestAnimationFrame(', "addEventListener('scroll'", 'CATransform3D']:
    assert forbidden not in new

# Probe identities all roll together.
assert 'VER=7.404' in UI and 'AD_PROBE_VERSION=7.404' in SK and 'AD_PROBE_NAME=AmazonDark-v7.404' in SK
assert 'AMAZONDARK v7.404 UNIVERSAL' in INC
assert "version:'7.404'" in JSINC
assert 'AmazonDark-v7.404-launch-sb-probe.txt' in SB
print('PASS: v7.394 covers add-address, pickup/map/card, delivery/pickup toggle and suggested-help/WebKit keyboard accessory with exact probe-backed ownership')
