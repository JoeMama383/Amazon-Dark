"""Exercise the production cold-launch decision without UIKit.

Enforce exact v7.344 outside the reviewed Cart paint additions. This is a host
regression test, not proof of device rendering or private-selector invocation.
Runs from a Git checkout or the complete source handoff using its manifest.
"""
import ctypes as c
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = "5bf6c356489bef37783fe25cee127799fa4f7578"
SB = ROOT / "src/AmazonDarkSB.xm"


def main():
    source = SB.read_text()
    policy = source.split("// BEGIN HOST-TESTED COLD-LAUNCH POLICY\n", 1)[1].split(
        "// END HOST-TESTED COLD-LAUNCH POLICY", 1)[0]
    with tempfile.TemporaryDirectory(prefix="amazondark-cold-policy-") as tmp:
        bridge = Path(tmp) / "policy.c"
        # Generated compilation input, not a hand-maintained duplicate policy.
        bridge.write_text('#include <string.h>\n#include <ctype.h>\n' + policy + "\n"
                          "int kind(const char *s){return ADContentKind7337(s);}\n"
                          "int launch(int k,const char *p,int v,int r){return ADIsColdLaunchArtwork7337(k,p,v,r);}\n")
        libpath = Path(tmp) / "policy.so"
        subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-shared", "-fPIC",
                        str(bridge), "-o", str(libpath)], check=True)
        lib = c.CDLL(str(libpath))
        lib.kind.argtypes = [c.c_char_p]
        lib.launch.argtypes = [c.c_int, c.c_char_p, c.c_int, c.c_int]
        samples = [
            (None, 0), (b"", 0), (b"unrelated description", 0),
            (b"<XBApplicationSnapshot: 0x1; contentType: GeneratedDefault>", 1),
            (b"<XBApplicationSnapshot: 0x1; contentType: Default; referenceSize: {430, 932}>", 2),
            (b"<XBApplicationSnapshot: 0x1; name: SBSuspendSnapshot; contentType: SceneContent>", 3),
            (b"contentType = GeneratedDefault;", 1), (b"contentType:\n Default\r\n", 2),
            (b"contentType: GeneratedDefaultExtra;", 0), (b"contentType: SceneContentExtra;", 0),
            (b"contentType: Generated;", 0), (b"contentType:", 0),
            (b"contentTypeOther: GeneratedDefault", 0),
            (b"contentType: SceneContent; variants = {contentType: GeneratedDefault}", 3),
            (b"contentType: Unknown; variants = {contentType: GeneratedDefault}", 0),
        ]
        for raw, expected in samples:
            assert lib.kind(raw) == expected, (raw, expected)
        count = len(samples)
        # Every combination: a saved scene/protected image ALWAYS passes through.
        # Nil-provider generated launches and request-backed pending images do not.
        for kind in range(4):
            for provider in [None, b"", b"XBLaunchImageDataProvider", b"SBSceneSnapshotDataProvider"]:
                for protected in [0, 1]:
                    for request in [0, 1]:
                        expected = not protected and kind != 3 and (
                            bool(request) or kind in (1, 2) or provider == b"XBLaunchImageDataProvider")
                        assert lib.launch(kind, provider, protected, request) == expected
                        count += 1
        print(f"PASS: {count} production cold-launch policy cases")

    tweak = (ROOT / "src/Tweak.xm").read_text()
    # Match the ACTUAL production hook surface, not a simulated cold/warm model.
    import re
    hooks = re.findall(r"^%hook (\w+)", source, re.M)
    assert hooks == [
        "XBApplicationSnapshot",
        "XBApplicationSnapshotManifestImpl",
        "XBApplicationSnapshotImage",
        "SBDeviceApplicationSceneViewPlaceholderContentViewProvider",
    ], hooks
    forbidden = [
        "SBIconView", "SBSceneView", "processState", "isRunning",
        "_processWillLaunch", "liveScenes", "notify_register", "notify_post",
        "dispatch_after", "animateWithDuration", "removeFromSuperview",
        "addSubview", "kCoverHardCap", "gCoverOverlay", "ADLaunchClassifyPixels",
        "deleteAllSnapshots", "removeItemAtPath", "dispatch_sync",
    ]
    assert not any(token in source for token in forbidden), "Presentation machinery returned"
    for token in ["ADConsiderLaunchReady706", "ADPostReadyOnce", "gADReadyPosted706",
                  "ADPurgeSplashSnapshots7271", "SplashBoard/Snapshots",
                  'notify_post("com.colindavidr.amazondark.ready']:
        assert token not in tweak, token
    assert 'if(![bundle isEqual:kAMZ])return original;' in source
    assert 'if(![[application valueForKey:@"bundleIdentifier"] isEqual:kAMZ])return original;' in source
    assert 'producingImage=NO;' in source and '@finally' in source
    for method in ["imageForInterfaceOrientation:(long long)orientation {",
                   "imageForInterfaceOrientation:(long long)orientation generationOptions:",
                   "cachedImageForInterfaceOrientation:(long long)orientation {"]:
        assert method in source
    assert 'format.opaque=YES' in source
    assert '[[UIColor blackColor] setFill]' in source
    assert 'version=7.338~v7307-constructor-safe-artwork base=4bbbbd9 mode=artwork-only' in source
    assert "Version: 7.346~v7344-cart-strip-button\n" in (ROOT / "layout/DEBIAN/control").read_text()
    manifest = json.loads((ROOT / "SOURCE-BASELINE.json").read_text())
    assert manifest['base_commit'] == BASE
    assert hashlib.sha256(SB.read_bytes()).hexdigest() == "076a9bc1c1cc0424e4bd79e79306b5791da90bfd66f5c973ddbb86c1215f3806"
    restored = without_cart_changes(tweak)
    assert hashlib.sha256(restored.encode()).hexdigest() == manifest['baseline_sha256']['src/Tweak.xm'], "Unexpected changes outside the reviewed Cart patch"
    for path in manifest['unchanged_files']:
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == manifest['baseline_sha256'][path], path
    for path, digest in manifest['delivery_sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest, path
    print("PASS: full Tweak.xm restores byte-for-byte to v7.344 after removing only the reviewed Cart additions")
    print("PASS: SpringBoard, launch behavior, image/skeleton rules and build/install wiring preserve v7.344")


def without_cart_changes(tweak):
    replacements = {
        " * AmazonDark v7.346 — exact v7.344 base + Cart loading-strip and buying-options paint":
            " * AmazonDark v7.344 — v7.343 skeleton fixes + Cart authored-loader/image preservation",
        '"v7.346-v7344-cart-strip-button"': '"v7.344-cart-loader-image-preservation"',
        '// v7.345: the 430x5 content-backed Cart progress/strip owner captured by the transition recorder.\n@interface AWLoadingIndicatorBarView : UIView @end\n': '',
        '- (void)setSelected:(BOOL)selected {\n    UIView *v=(UIView *)self;\n    @try {\n        NSString *aid=v.accessibilityIdentifier?:@"";\n        if([aid isEqualToString:@"cartTab"])ADSetCartTabSelected7345(gP.enabled&&selected);\n        else if(selected)ADSetCartTabSelected7345(NO);\n    } @catch(...) {}\n    %orig;':
            '- (void)setSelected:(BOOL)selected {\n    %orig;\n    UIView *v=(UIView *)self;',
    }
    for old,new in replacements.items():
        assert tweak.count(old)==1, old
        tweak=tweak.replace(old,new)
    for begin,end in [
        ('        // v7.345: exact p13n buying-options fallback', '        // Cart item action controls:'),
        ('// v7.345 — transition capture identifies', '%hook AWLoadingIndicatorWidgets_LoadingText')]:
        assert tweak.count(begin)==1 and tweak.count(end)==1
        a=tweak.index(begin);b=tweak.index(end,a)
        tweak=tweak[:a]+tweak[b:]
    return tweak


if __name__ == "__main__":
    main()
