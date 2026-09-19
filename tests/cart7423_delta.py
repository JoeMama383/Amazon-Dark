# Normalize only the reviewed v7.424 Cart CSS when comparing historical golden payloads.
import hashlib
def strip_cart7423(source):
    start='        // v7.423: probe-proven Cart message banner.'; end='        // v7.245: Cart-probe-backed first-paint ownership.'
    assert source.count(start)==1
    a=source.index(start); b=source.index(end,a)
    assert hashlib.sha256(source[a:b].encode()).hexdigest()=='fdabfba3502c43e29d6fb5682ea73d2436982eb2e007ed0a3685332880ba998a', 'v7.426 Cart CSS delta changed'
    return source[:a]+source[b:]

def strip_byg7423(source):
    start='        // v7.423: speed-carousel detail floors'
    end='        // v7.370: preserve authored link descendants generally, then target the probe-proven black'
    assert source.count(start)==1
    a=source.index(start); b=source.index(end,a)
    assert hashlib.sha256(source[a:b].encode()).hexdigest()=='93f5533da14c68328e8cde4b73ec7e8eaf17fc8864717397244929b3f9d10a16', 'v7.426 BYG CSS delta changed'
    return source[:a]+source[b:]
