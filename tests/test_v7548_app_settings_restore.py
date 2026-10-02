from pathlib import Path
f=Path('src/Tweak.xm').read_text()+Path('src/ADAppSettings7550.inc').read_text()
for token in [
    'static UIView *ADAppSettingsRoot7548(UIView *v){',
    'static void ADAppSettingsOwn7548(UIView *v){',
    'static void ADAppSettingsOwnText7548(UIView *v){',
    'static void ADAppSettingsOwnVector7548(UIView *svg){',
    'if(ADAppSettingsRoot7548(v)){ ADAppSettingsOwn7548(v); return; }',
    'if(gP.enabled&&ADAppSettingsRoot7548(v)){',
    'BOOL appSettings=gP.enabled&&ADAppSettingsRoot7548(v);',
    'if(appSettings)ADAppSettingsOwnText7548(v);',
    'if(ADAppSettingsRoot7548(v)){ ADAppSettingsOwnText7548(v); return; }',
    'if(ADAppSettingsRoot7548(v)){\n                NSAttributedString *themed=ADMenuLightString7255(attributedText);',
    'if(ADAppSettingsRoot7548(v)){\n                UIColor *themed=ADMenuDarkNeutral7255(color)?ADLightText706():color;'
]:
    assert token in f, token
