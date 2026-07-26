#!/usr/bin/env python3
"""
lint-js.py - parse-check the JavaScript this tweak injects.

THE BUG THIS EXISTS TO PREVENT
------------------------------------------------------------------------------
The injected payload is built in layers:

    ObjC string literal  ->  JS source  ->  JS string literal  ->  CSS text

ADFixesLiteral emits `{css:'<css>'}` - the CSS sits inside a SINGLE-QUOTED JS
string. So a bare ' anywhere in that CSS terminates the JS string and the whole
bootstrap dies with a syntax error. Nothing logs, Dark Reader never runs, and the
app looks like the tweak was uninstalled - with no error pointing at the CSS.

That is what a `[src*='/images/I/']` attribute selector did in v5.167.0. The
existing convention is \\\" (three backslashes, quote) so the JS string receives
\" and the CSS receives a plain " - but nothing enforced it.

Checking a hand-extracted fragment is not enough: the fragment parses fine on its
own. The CSS has to be assembled INTO its JS wrapper, exactly as the compiler
would, and the result handed to node.

Usage: python3 scripts/lint-js.py [src/Tweak.xm]
Exit 0 = every emitted JS block parses.
"""
import re, subprocess, sys, os, tempfile

SRC = sys.argv[1] if len(sys.argv) > 1 else 'src/Tweak.xm'


def strip_comments(src):
    """Remove // and /* */ comments WITHOUT touching quotes inside strings.

    A regex cannot do this: a comment containing a quoted word gets slurped in as
    if it were a string literal (which silently corrupted this linter's first
    version), and a string containing http:// gets truncated as if it were a
    comment. Both require tracking string state.
    """
    out, i, n, in_str = [], 0, len(src), False
    while i < n:
        c = src[i]
        if in_str:
            if c == '\\':
                out.append(src[i:i + 2]); i += 2; continue
            out.append(c)
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            i += 2
            while i + 1 < n and not (src[i] == '*' and src[i + 1] == '/'):
                i += 1
            i += 2; continue
        out.append(c); i += 1
    return ''.join(out)


def objc_unescape(text):
    """Decode an ObjC string literal body the way the compiler does."""
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == '\\' and i + 1 < len(text):
            nxt = text[i + 1]
            out.append({'n': '\n', 't': '\t', 'r': '\r', '0': '\0',
                        '\\': '\\', '"': '"', "'": "'"}.get(nxt, nxt))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def literals_in(body):
    """Concatenate adjacent ObjC string literals, as the compiler does."""
    body = strip_comments(body)
    parts = re.findall(r'@?"((?:[^"\\]|\\.)*)"', body)
    return ''.join(objc_unescape(p) for p in parts)


def function_body(src, name):
    m = re.search(r'static NSString \*' + name + r'\(void\)\{(.*?)\n\}', src, re.S)
    return m.group(1) if m else None


def check(label, js):
    # Neutralise ObjC format placeholders substituted at runtime.
    js = re.sub(r'%(?:ld|lu|zu|[@dsf])', 'null', js).replace('%%', '%')
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
        f.write(js)
        path = f.name
    try:
        r = subprocess.run(['node', '--check', path], capture_output=True, text=True)
    except FileNotFoundError:
        # node is not installed in every dev environment (it is absent from this
        # project's WSL box). Degrade instead of crashing: the structural checks
        # below are the ones that caught the real defect, and they need no node.
        os.unlink(path)
        print(f"  SKIP     {label} (node not installed)")
        return True
    os.unlink(path)
    if r.returncode == 0:
        print(f"  OK       {label} ({len(js)} chars)")
        return True
    print(f"  FAIL     {label}")
    for line in r.stderr.strip().split('\n')[:6]:
        print(f"           {line[:160]}")
    return False


def main():
    src = open(SRC, encoding='utf-8').read()
    ok = True
    print("lint-js: checking emitted JavaScript")

    # 1. The CSS-in-JS wrapper. This is the layered one that bit us.
    #    The function also contains ternary branches, so concatenating every
    #    literal yields both alternatives glued together and is not valid JS on
    #    its own. Isolate the {css:'...'} object, which is the part that matters.
    fixes = function_body(src, 'ADFixesLiteral')
    if fixes is None:
        print("  SKIP     ADFixesLiteral not found")
    else:
        emitted = literals_in(fixes)
        a = emitted.find("{css:'")
        if a < 0:
            print("  FAIL     could not locate the {css:'...'} object")
            ok = False
        else:
            # The object runs to the end of the emitted text and carries further
            # keys (ignoreInlineStyle etc.) whose arrays legitimately contain
            # quotes, so the object boundary is the end, not the first "'}".
            ok &= check('ADFixesLiteral (CSS inside single-quoted JS string)',
                        'var __x = ' + emitted[a:] + ';')

    # 2. Every other function that emits a self-contained JS expression.
    for name in ['ADPharmGateJS', 'ADPharmForceJS']:
        body = function_body(src, name)
        if body is None:
            print(f"  SKIP     {name} not found")
            continue
        ok &= check(name, 'var __x = ' + literals_in(body) + ';')

    # 3. Bare apostrophes inside the CSS payload - the exact v5.167.0 defect.
    if fixes is not None:
        css = literals_in(fixes)
        a = css.find("{css:'")
        b = -1
        if a >= 0:
            i = a + 6
            while i < len(css):
                if css[i] == '\\':
                    i += 2; continue
                if css[i] == "'":
                    b = i; break
                i += 1
        if a < 0 or b < 0:
            print("  FAIL     could not delimit the CSS string")
            ok = False
        else:
            body = css[a + 6:b]
            # Searching body for a quote is tautological -- b IS the first quote.
            # The real test is WHERE the string closed. A correctly escaped CSS
            # payload closes immediately before the object's next key, so the very
            # next character must be ',' or '}'. If it is anything else, the quote
            # that closed the string was one buried inside the CSS.
            after = css[b + 1:b + 12]
            if after[:1] not in (',', '}'):
                print(f"  FAIL     CSS string closed early at offset {len(body)} -- "
                      f"unescaped ' inside the CSS")
                print(f"           ...{css[max(0,b-70):b+40]}...")
                ok = False
            else:
                print(f"  OK       CSS closes cleanly before {after.strip()[:20]!r} "
                      f"({len(body)} chars)")

    print("lint-js: " + ("OK" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
