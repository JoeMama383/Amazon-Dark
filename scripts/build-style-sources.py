#!/usr/bin/env python3
"""Build-only expansion of editable stylesheet/runtime templates.

The committed outputs let Theos and the phone push helper work without Python.
Nothing in this module is installed in, injected into, or executed by Amazon.
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CSS = re.compile(r'@@AD_CSS:([A-Za-z0-9_./-]+)@@')
PAYLOAD = re.compile(r'/\* @AD_PAYLOAD:([A-Za-z0-9_./-]+)@ \*/')


def expand(text):
    return CSS.sub(lambda m: (ROOT / 'styles' / m[1]).read_text(), text)


def outputs():
    manifest = json.loads((ROOT / 'styles/manifest.json').read_text())
    native = (ROOT / 'runtime/Tweak.xm.in').read_text()
    payloads = manifest['nativePayloads']

    def payload(match):
        name = match[1]
        spec = payloads[name]
        text = expand((ROOT / 'runtime/payloads' / name).read_text())
        # Retain the previous C-literal boundaries for a reviewable generated
        # diff. New text beyond those boundaries belongs to the last literal.
        chunks, offset = [], 0
        for index, part in enumerate(spec):
            end = offset + part['length'] if index + 1 < len(spec) else len(text)
            chunks.append(part['before'] + part['prefix'] +
                          json.dumps(text[offset:end], ensure_ascii=part['ascii']))
            offset = end
        return ''.join(chunks)

    yield 'src/Tweak.xm', PAYLOAD.sub(payload, native)
    for spec in manifest['modules']:
        text = expand((ROOT / 'runtime' / spec['template']).read_text())
        if spec['source']:
            yield 'src/' + spec['source'], text
        yield 'src/' + spec['include'], ''.join(
            json.dumps(line, ensure_ascii=False) + '\n' for line in text.splitlines(True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail on stale generated files')
    args = parser.parse_args()
    stale = []
    for name, text in outputs():
        target = ROOT / name
        if args.check:
            if not target.exists() or target.read_text() != text:
                stale.append(name)
        else:
            target.write_text(text)
    if stale:
        print('Stale generated sources: ' + ', '.join(stale), file=sys.stderr)
        print('Run python3 scripts/build-style-sources.py', file=sys.stderr)
        return 1
    print('Stylesheet sources: ' + ('verified' if args.check else 'generated'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
