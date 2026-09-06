"""Exercise the production cold-launch decision without UIKit.

Preserve the inherited cold-launch policy while v7.348 changes only explicitly armed
Cart-strip diagnostics. This is a host regression test, not proof of device rendering
or private-selector invocation.
"""
import ctypes as c
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
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
    assert "Version: 7.349~cart-shimmer-border-strip-fix\n" in (ROOT / "layout/DEBIAN/control").read_text()
    assert hashlib.sha256(SB.read_bytes()).hexdigest() == "076a9bc1c1cc0424e4bd79e79306b5791da90bfd66f5c973ddbb86c1215f3806"
    print("PASS: v7.348 leaves the inherited SpringBoard/cold-launch source byte-identical")



if __name__ == "__main__":
    main()
