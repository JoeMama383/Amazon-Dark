from pathlib import Path
import json, shutil, subprocess, tempfile
R=Path(__file__).resolve().parents[1]
INC=R/'src/ADNewMenus7482.js.inc'
lines=[line for line in INC.read_text().splitlines() if line.strip()]
parts=[]
for n,line in enumerate(lines,1):
    try:
        parts.append(json.loads(line))
    except Exception as e:
        raise AssertionError(f'ADNewMenus include line {n} is not a valid encoded string: {e}')
js=''.join(parts)
assert "content:'\\22EE'" not in js, 'invalid legacy/octal escape must never ship inside the JS template literal'
assert "content:'⋮'!important" in js, 'contextual menu replacement glyph must use a JS-safe literal'
node=shutil.which('node')
assert node, 'Node is required by AmazonDark JS syntax regressions'
with tempfile.TemporaryDirectory() as td:
    p=Path(td)/'ADNewMenus7482.js'
    p.write_text(js)
    cp=subprocess.run([node,'--check',str(p)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    assert cp.returncode==0, cp.stderr
print('PASS: v7.533 reconstructs and parses the shipped ADNewMenus WebKit payload; malformed CSS escapes cannot blank the web theme')
