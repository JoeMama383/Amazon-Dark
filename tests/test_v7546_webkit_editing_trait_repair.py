from pathlib import Path
R=Path(__file__).resolve().parents[1]
t=(R/'src/Tweak.xm').read_text();h=(R/'src/ADWebKeyboardStyle7546.h').read_text();p=(R/'src/ADSkeletonProbe7339.h').read_text()
b=t.split('%hook WKContentView',1)[1].split('%end',1)[0]
f=b.split('- (BOOL)becomeFirstResponder {',1)[1].split('- (BOOL)resignFirstResponder',1)[0]
assert f.index('ADWebKeyboardStyle7546((UIView *)self,YES);')<f.index('BOOL became=%orig;')
assert 'if(!became&&!self.isFirstResponder)' in f
assert 'if(resigned)ADWebKeyboardStyle7546((UIView *)self,NO);' in b
assert 'UIUserInterfaceStyle next=ADWebKeyboardRequestedStyle7546((UIView *)self,style);\n    %orig(next);' in b
assert 'if(acquire&&gP.enabled)' in h and 'if(!saved)' in h and 'saved.integerValue' in h
assert '@finally { ADWebKeyboardStyleWrite7546=NO; }' in h
for token in ('setFrame:', 'setBounds:', 'setCenter:', 'setTransform:', 'reloadInputViews','dispatch_after','NSTimer','addObserver'):
 assert token not in h and token not in b
raw=p.split('static id ADSkelStoredKeyboardAppearance7546',1)[1].split('static NSDictionary *ADSkelKeyboardObjectState7542',1)[0]
assert 'objc_msgSend' not in raw and 'object_setIvar' not in raw
assert 'class_getInstanceSize' in raw and 'memcpy' in raw and '[NSNull null]' in raw
assert t.count('ADKeyboardOwner7546(self,traits);')==3
assert len(t.encode())<856000
print('PASS: focused WebKit native style precedes focus; successful resign/failed acquisition release ownership; geometry unchanged; stored appearance evidence avoids hooked getters')
