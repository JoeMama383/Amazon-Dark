from pathlib import Path
import json,re,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
s=(R/'src/ADNewMenus7482.js.inc').read_text()
js=''.join(json.loads(x) for x in s.splitlines() if x.strip())
css=js.split('/* Interests modal captured paint:',1)[1].split('`;',1)[0]
r='body:has(._bW9ia_prompt-bottom-sheet_1NiWU) ._bW9ia_prompt-bottom-sheet_1NiWU'
all_rules=re.findall(r'([^{}]+)\{([^{}]+)\}',css.split('*/',1)[1])
rules=[(selector,decl) for selector,decl in all_rules if selector.strip().startswith(r)]
assert len(rules)==7
for selector,decl in rules:
    for prop in ('width','height','position','margin','padding','border-width','border-radius','display','transform'):
        assert not re.search(r'(?:^|;)'+prop+r':',decl),prop
assert '._bW9ia_content-wrapper_3UjcO::after{background:transparent!important;background-image:none!important;}' in css
assert '._bW9ia_shapes-wrapper_9y3QA{visibility:hidden!important;}' in css
assert '._bW9ia_prompt_22rKh{background:#181a1b!important;outline:none!important;box-shadow:none!important;}' in css
assert ':is(textarea,._bW9ia_invisible-focus-input_3rA0M){color-scheme:dark!important;}' in css
assert '#intp-submit-btn{background:#000!important;background-color:#000!important;border-color:#747a7c!important;' in css
assert '#intp-submit-btn :is(.a-button-inner,.a-button-text){background:transparent!important;' in css
assert '_bW9ia_clear-btn' not in css and 'filter:' not in css
with tempfile.TemporaryDirectory() as d:
    p=Path(d)/'payload.js';p.write_text(js)
    subprocess.run(['node','--check',str(p)],check=True,capture_output=True)
print('PASS: modal fade/glow removed, stock geometry retained, one authored focus border, OLED Update and dark input scheme; emitted payload parses')
