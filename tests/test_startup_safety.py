"""Guard the v7.337 pre-UIKit constructor crash using the actual source call graph.

This checks source-level startup reachability, not on-device UIKit execution.
It deliberately rejects the precise old eager-load expression, even in a helper.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/AmazonDarkSB.xm"


def masked(source):
    # Preserve offsets/braces outside comments and string/character literals.
    pattern = r'//[^\n]*|/\*[\s\S]*?\*/|@?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    return re.sub(pattern, lambda m: "".join("\n" if c == "\n" else " " for c in m[0]), source)


def block(text, start):
    assert text[start] == "{"
    depth = 1
    for end in range(start + 1, len(text)):
        depth += (text[end] == "{") - (text[end] == "}")
        if depth == 0:
            return text[start + 1:end]
    raise AssertionError("Unclosed source block")


def reachable_ui_calls(source):
    text = masked(source)
    functions = {}
    for match in re.finditer(r"(?m)^static[^\n;{}]*?\b(AD\w+)\([^;{}]*\)\s*\{", text):
        functions[match[1]] = block(text, match.end() - 1)
    ctor = re.search(r"%ctor\s*\{", text)
    assert ctor
    functions["%ctor"] = block(text, ctor.end() - 1)
    pending, seen, hazards = ["%ctor"], set(), []
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        body = functions[name]
        ui = re.findall(r"\b(?:UIImage|UIScreen|UIView|UIWindow|UIApplication|UIGraphics\w*)\b", body)
        hazards.extend((name, symbol) for symbol in ui)
        for callee in re.findall(r"\b(AD\w+)\s*\(", body):
            assert callee in functions, f"Unresolved startup helper: {callee}"
            pending.append(callee)
    return hazards, seen


def main():
    source = SOURCE.read_text()
    hazards, reachable = reachable_ui_calls(source)
    assert not hazards, hazards
    assert "ADSplashImage7191" not in reachable
    assert "ADLaunchArtwork7337" not in reachable

    # Negative control: the exact expression responsible for the supplied crash.
    old = source.replace("%ctor {", "%ctor {\n    ADSplashImage7191()!=nil;", 1)
    assert any(name == "ADSplashImage7191" and symbol == "UIImage"
               for name, symbol in reachable_ui_calls(old)[0])

    # Also catch a future accidental eager load hidden inside the logger.
    indirect = source.replace(
        "static void ADLaunchLog7337(NSString *event,NSString *detail){",
        "static void ADLaunchLog7337(NSString *event,NSString *detail){\n"
        "    ADSplashImage7191();", 1)
    assert any(symbol == "UIImage" for _, symbol in reachable_ui_calls(indirect)[0])

    # The supplied stack terminates at dispatch's callout. A catch around the
    # caller does not contain that throw: the handler must be inside the block.
    text = masked(source)
    declaration = re.search(r"static UIImage \*ADSplashImage7191\(void\)\s*\{", text)
    loader = block(text, declaration.end() - 1)
    once = loader.index("dispatch_once")
    callout = block(loader, loader.index("{", once))
    guarded = block(callout, callout.index("{", callout.index("@try")))
    assert "imageWithContentsOfFile:" in guarded
    assert "@catch" in callout
    assert "image=nil;" in callout

    print("PASS: constructor and reachable helpers contain no UIKit image/screen work")
    print("PASS: guard rejects the actual v7.337 eager load and indirect logger regression")
    print("PASS: logo-load exception is contained inside the dispatch_once callback")


if __name__ == "__main__":
    main()
