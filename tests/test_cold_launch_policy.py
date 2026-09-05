"""Exercise the production cold-launch decision without UIKit.

Enforce v7.307 UI/warm behavior with only the explicit launch-handoff removals. This is a host
regression test, not proof of device rendering or private-selector invocation.
Run from a Git checkout containing base 4bbbbd9, or use SOURCE-BASELINE.json.
"""
import ctypes as c
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = "4bbbbd9ae7c5dc0a9d4dc1455235da3feeb706f7"
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
    assert "Version: 7.338~v7307-constructor-safe-artwork\n" in (ROOT / "layout/DEBIAN/control").read_text()
    try:
        baseline = subprocess.check_output(
            ["git", "show", f"{BASE}:src/Tweak.xm"], cwd=ROOT,
            stderr=subprocess.DEVNULL).decode()
    except subprocess.CalledProcessError:
        baseline = None
    if baseline:
        assert hashlib.sha256(baseline.encode()).hexdigest() == (
            "d2c5a71fe41bf5542447c1bd3f2a0e32c3642964691a4c8724451203078f1686")
        assert tweak == expected_app(baseline), "Unexpected change to v7.307 UI/warm behavior"
        for path in [".github/workflows/build.yml", "Makefile",
                     "AmazonDark.plist", "AmazonDarkSB.plist",
                     "layout/DEBIAN/postinst", "prefs/ADPrefsController.xm"]:
            assert (ROOT / path).read_bytes() == subprocess.check_output(
                ["git", "show", f"{BASE}:{path}"], cwd=ROOT), path
    manifest = json.loads((ROOT / "SOURCE-BASELINE.json").read_text())
    previous = tweak.replace("v7.338 —", "v7.337 —").replace(
        '"v7.338-v7307-constructor-safe-artwork"', '"v7.337-v7307-stock-timing-cold-artwork"')
    assert hashlib.sha256(previous.encode()).hexdigest() == manifest["parent_tweak_sha256"], "App runtime changed in hotfix"
    for path in manifest["unchanged_files"]:
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == manifest["baseline_sha256"][path], path
    for path, digest in manifest["delivery_sha256"].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    print("PASS: exact v7.307 UI/warm behavior outside explicit launch removals")
    print("PASS: no SB presentation hooks, hard cap, ready listener, or snapshot purge")
    print("PASS: source identity and unchanged build/push wiring")
    print("PASS: v7.337 app runtime unchanged by startup hotfix")


def expected_app(base):
    """Only permitted runtime edits are removal of the obsolete handoff/purge.
    The full-file comparison catches ALL other changes, including UI/geometry.
    """
    result = base
    replacements = {
        " * AmazonDark v7.307 — v7.301 baseline + warm-resume splash bypass + Alexa mic centering":
            " * AmazonDark v7.338 — v7.307 UI / warm behavior, iOS-owned cold-launch timing",
        '"v7.307-warm-resume-bypass-mic-center"':
            '"v7.338-v7307-constructor-safe-artwork"',
        "// from an actual scene reconstruction inside the same process. SpringBoard remains the\n"
        "// exact v7.301 cold-launch implementation; warm behavior is owned inside Amazon only.":
            "// from an actual scene reconstruction inside the same process. Keep this approved\n"
            "// warm behavior unchanged; SpringBoard now supplies cold-launch artwork only.",
        "// own its earliest floor dark. v7.301 SpringBoard still supplies the cold logo cover.":
            "// own its earliest floor dark. Amazon/iOS retain presentation and dismissal.",
        "static void ADPostReadyOnce(void);\n": "",
        "static void ADConsiderLaunchReady706(void);\n": "",
        "- (void)didMoveToWindow {\n    %orig;\n"
        "    if(gP.enabled && self.window)ADConsiderLaunchReady706();\n}\n": "",
        "        if(ADPrimaryAmazonController713(self))ADConsiderLaunchReady706();\n": "",
        "    ADConsiderLaunchReady706();\n": "",
        "        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{ ADPurgeSplashSnapshots7271(); });\n": "",
    }
    for old, new in replacements.items():
        assert old in result, old
        result = result.replace(old, new)
    start = result.index("// -----------------------------------------------------------------------------\n// Launch transition handoff.")
    last = result.index("static void ADConsiderLaunchReady706(void){", start)
    end = result.index("\n}", last) + 2
    result = result[:start] + (
        "// Launch artwork is supplied at the system image source. No app-side readiness\n"
        "// polling or cross-process handoff is needed; Amazon/iOS own presentation timing."
    ) + result[end:]
    start = result.index("static void ADPurgeSplashSnapshots7271(void){")
    end = result.index("\n}", start) + 3
    result = result[:start] + result[end:]
    return result


if __name__ == "__main__":
    main()
