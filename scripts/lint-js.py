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
    for name in ['ADPharmGateJS', 'ADPharmForceJS', 'ADProbeWebJS', 'ADCardBorderFixJS']:
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

    print("  --- regression gates ---")
    ok &= check_full_payload(src)
    ok &= check_silhouette_guards(src)
    ok &= check_ovr_scope(src)
    ok &= check_format_specifiers(src)
    ok &= check_objc_decl_order(src)

    print("lint-js: " + ("OK" if ok else "FAILED"))
    return 0 if ok else 1



# ─────────────────────────────────────────────────────────────────────────────
# REGRESSION GATES. Each of these encodes a bug that actually shipped, cost
# multiple builds to find, and would not have been caught by a parse check.
# ─────────────────────────────────────────────────────────────────────────────

GUARD_PATTERNS = ('artChk(', 'isProdArt(', 'isPhoto(', 'holdsArt(',
                  'width>48', 'height>48', 'naturalWidth', '>64)continue')


def check_silhouette_guards(src):
    """Every inline silhouette write must be GUARDED BEFORE and MARKED AFTER.

    The bug: at two sites the product-art guard sat BELOW the write, so a photo was
    silhouetted and only then asked whether it was a photo -- and the guard's
    `continue` skipped the marking line, making the offender invisible to every
    by= audit. Grepping for isProdArt showed those sites as guarded. It took ten
    builds to find. A guard in the wrong ORDER is far harder to spot than a
    missing one, so order is what this checks.
    """
    lines = src.split('\n')
    ok = True
    sites = 0
    for i, line in enumerate(lines):
        if "setProperty('filter','brightness(0) invert(1)'" not in line:
            continue
        sites += 1
        before = '\n'.join(lines[max(0, i - 8):i])
        after = '\n'.join(lines[i:i + 5])
        guarded = any(g in before for g in GUARD_PATTERNS)
        marked = '__adBy' in after
        if not guarded or not marked:
            ok = False
            why = []
            if not guarded:
                why.append('NO GUARD in the 8 preceding lines')
            if not marked:
                why.append('NO __adBy mark in the 5 following lines')
            print(f"  FAIL     line {i+1}: {'; '.join(why)}")
            print(f"           {line.strip()[:100]}")
    if ok:
        print(f"  OK       all {sites} silhouette sites guarded-before and marked-after")
    return ok


def check_ovr_scope(src):
    """ovr() is defined inside the pass function; calling it elsewhere throws.

    The bug: a mechanical edit added the time budget to 32 loops, four of which
    were in ADPharmForceJS and ADDarkReaderReapply -- separate payloads with no
    ovr() in scope. A ReferenceError there kills the whole script silently.

    Two passes, because JS hoists function declarations: a call may legitimately
    appear textually above the definition within the same function.
    """
    lines = src.split('\n')

    def owner(idx):
        cur = None
        for j in range(idx + 1):
            m = re.match(r'static NSString \*(\w+)\(', lines[j])
            if m:
                cur = m.group(1)
        return cur

    definers = {owner(i) for i, l in enumerate(lines) if 'function ovr()' in l}
    bad = [(i + 1, owner(i)) for i, l in enumerate(lines)
           if '!ovr()' in l and 'function ovr()' not in l and owner(i) not in definers]
    if bad:
        for ln, fn in bad:
            print(f"  FAIL     line {ln}: ovr() called in {fn}, which does not define it")
        return False
    print(f"  OK       every ovr() call is inside {sorted(d for d in definers if d)}")
    return True


def check_format_specifiers(src):
    """A lone % inside a stringWithFormat literal garbles the emitted JS.

    The bug: a /%/ regex in a formatted literal. Must be written /%%/. Counts
    %% as one escaped literal rather than flagging its second character, which
    my ad-hoc grep got wrong.
    """
    ok = True
    for name in ['ADDarkReaderBootstrapBuild', 'ADFixesLiteral', 'ADThemeLiteral']:
        m = re.search(r'static NSString \*' + name + r'\([^)]*\)\{(.*?)\n\}', src, re.S)
        if not m:
            continue
        body = strip_comments(m.group(1))
        lits = ''.join(re.findall(r'@?"((?:[^"\\]|\\.)*)"', body))
        stripped = lits.replace('%%', '')
        bad = re.findall(r'%(?![@dsfl]|ld|lu|zu)', stripped)
        if bad:
            ok = False
            print(f"  FAIL     {name}: {len(bad)} unescaped % (write %% for a literal percent)")
        else:
            print(f"  OK       {name}: no unescaped %")
    return ok


def check_full_payload(src):
    """Parse the ENTIRE emitted pass, not a fragment.

    The bug: hand-inserted statements landed mid-expression twice. A fragment
    extracted around the edit parsed fine; the assembled payload did not.
    """
    m = re.search(r'static NSString \*ADDarkReaderBootstrapBuild\([^)]*\)\{(.*?)\n\}', src, re.S)
    if not m:
        print("  SKIP     ADDarkReaderBootstrapBuild not found")
        return True
    js = literals_in(m.group(1))
    if len(js) < 30000:
        print(f"  FAIL     payload extraction only {len(js)} chars - extractor is broken")
        return False
    return check('full injected pass', 'function W(){' + js + '}')




def check_objc_decl_order(src):
    """Every static C function must be DECLARED before its first use.

    Two builds reached CI with 'use of undeclared identifier' because a probe was
    inserted above the function it calls. Logos compiles one translation unit, so
    ordering matters and the compiler is the only thing that was catching it --
    after a push, a CI run and a wasted cycle each time.
    """
    # Blank string literals as well as comments, and preserve line numbering: a
    # function name mentioned inside an injected-JS literal is not a C call, and
    # collapsing /* */ blocks shifts every line number after them.
    txt = strip_comments(src)
    txt = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', txt)
    lines = txt.split('\n')
    defs, fwds = {}, {}
    for i, l in enumerate(lines):
        m = re.match(r'\s*static\s+(?:inline\s+)?[A-Za-z_][\w\s\*]*?\b(\w+)\s*\([^;{]*\)\s*\{', l)
        if m:
            defs.setdefault(m.group(1), i)
        m2 = re.match(r'\s*static\s+(?:inline\s+)?[A-Za-z_][\w\s\*]*?\b(\w+)\s*\([^;{]*\)\s*;', l)
        if m2:
            fwds.setdefault(m2.group(1), i)
    ok = True
    for name, dline in defs.items():
        # Usable from whichever comes first -- the definition or a forward
        # declaration. Taking the forward decl alone flagged functions that are
        # simply defined above it, which is legal and common here.
        first = min(dline, fwds.get(name, dline))
        for i, l in enumerate(lines):
            if i >= first:
                break
            # Skip the definition/declaration lines themselves: they contain the
            # name followed by '(' and are not calls.
            if re.match(r'\s*static\b', l) and name in l:
                continue
            if re.search(r'\b' + re.escape(name) + r'\s*\(', l):
                print(f"  FAIL     {name}() used at line {i+1}, first declared at {first+1}")
                ok = False
                break
    if ok:
        print(f"  OK       all {len(defs)} static functions declared before use")
    return ok


if __name__ == '__main__':
    sys.exit(main())# ── ObjC STRING LITERAL BALANCE ────────────────────────────────────────────────
# v5.470: lint-js extracts JS from inside the ObjC literals, so it passed a file
# whose literals were unbalanced -- an edit split "/*MARKER*/" across lines and left
# a dangling quote; clang caught it, we did not.
# The count must be escape-aware: a backslash escapes the next character, so lines
# like .replace(/[\"']/g,'') contain a quote that is NOT a literal delimiter.
def _unescaped_quotes(line):
    n = 0
    i = 0
    while i < len(line):
        c = line[i]
        if c == '\\':
            i += 2
            continue
        if c == '"':
            n += 1
        i += 1
    return n

_bal_path = str(SRC) if 'SRC' in dir() else (sys.argv[1] if len(sys.argv) > 1 else 'src/Tweak.xm')
_bal = [(n, l.strip()[:90]) for n, l in enumerate(open(_bal_path, encoding='utf-8').read().split('\n'), 1)
        if not l.strip().startswith('//') and _unescaped_quotes(l) % 2]
if _bal:
    print("  FAIL     unbalanced ObjC string literal (will not compile)")
    for n, txt in _bal[:5]:
        print(f"           line {n}: {txt}")
    print("lint-js: FAILED")
    sys.exit(1)
else:
    print("  OK       all ObjC string literals balanced")


