"""Prove v7.347 changes only armed diagnostics relative to exact v7.346 Tweak.xm."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
PARENT_SHA="47043edbaae3a5bfd3c285ca830f13659c8c08134410224f8c407f3a5422a97a"

def main():
    s=(ROOT/"src/Tweak.xm").read_text()
    s=s.replace(" * AmazonDark v7.347 — v7.346 visuals + Cart strip owner/gate forensics", " * AmazonDark v7.346 — exact v7.344 base + Cart loading-strip and buying-options paint",1)
    s=s.replace('#define AD_VERSION "v7.347-cart-strip-owner-forensics"', '#define AD_VERSION "v7.346-v7344-cart-strip-button"',1)
    fwd="\n// v7.347 probe-only forward declaration. This records late-loaded AWLoadingIndicatorBarView\n// mounts from the already-existing global UIView lifecycle hook; it does not paint them.\nstatic void ADCartStripGlobalMountDiag7347(UIView *v);\n"
    assert fwd in s; s=s.replace(fwd,"",1)
    witness="    // v7.347 probe-only late-load witness. If the exact AWLoadingIndicatorBarView Logos\n    // hook was unavailable when %init ran, this inherited UIView hook can still prove the\n    // class mounted. No production paint or state change occurs here.\n    if(ADSkelActive7339()&&ADClassNameIs7183(self,\"AWLoadingIndicatorBarView\"))ADCartStripGlobalMountDiag7347(self);\n"
    assert witness in s; s=s.replace(witness,"",1)
    a=s.index("// v7.345 production behavior retained byte-for-byte in intent:")
    b=s.index("%hook AWLoadingIndicatorWidgets_LoadingText",a)
    parent=(ROOT/"tests/fixtures/v7346-cart-strip-block.txt").read_text()
    s=s[:a]+parent+s[b:]
    got=hashlib.sha256(s.encode()).hexdigest()
    assert got==PARENT_SHA,(got,PARENT_SHA)
    live=(ROOT/"src/Tweak.xm").read_text()
    assert "CART_STRIP_OWNER" in live
    assert live.count("ADSkelActive7339()") > (ROOT/"tests/fixtures/v7346-cart-strip-block.txt").read_text().count("ADSkelActive7339()")
    print("PASS: normalized v7.347 Tweak.xm is byte-for-byte exact v7.346")

if __name__=="__main__": main()
