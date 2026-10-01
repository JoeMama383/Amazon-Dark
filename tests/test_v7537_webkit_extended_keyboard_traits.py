from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=(R/'src/Tweak.xm').read_text(); C=(R/'layout/DEBIAN/control').read_text(); CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.537~interests-webkit-extended-keyboard-fix' in C
assert '#define AD_VERSION "v7.537-interests-webkit-extended-keyboard-fix"' in S
assert '@interface WKExtendedTextInputTraits : NSObject @end' in S
block=S[S.index('%hook WKExtendedTextInputTraits'):S.index('%hook WKContentView')]
assert 'UIKeyboardAppearance next=gP.enabled?UIKeyboardAppearanceDark:a;' in block and '%orig(next);' in block
assert '- (void)restoreDefaultValues {' in block and '%orig;' in block and 'if(gP.enabled)ADDarkWebInputTraits7512(self);' in block
assert 'class_replaceMethod' not in block and 'objc_setAssociatedObject' not in block
assert len(S.encode()) < 856000
assert 'AmazonDark-v7.537-interests-webkit-extended-keyboard-fix-source.zip' in CMD
print('PASS: v7.537 owns WebKit extended input traits so restoreDefaultValues cannot revert the remote keyboard to light')
