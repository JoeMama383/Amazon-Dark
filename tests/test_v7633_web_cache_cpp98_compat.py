"""v7.633: C++98 cache fixture and real Objective-C++ checkout gate both survive."""
from pathlib import Path
import runpy,re
R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
shared=s.split('static WKUserScript *ADSharedUserScript7387(',1)[1].split('static void ADAttachScriptsToUCC710(',1)[0]
# The Foundation-only guard is active when Logos compiles Objective-C++, while
# the C++98 fixture still exercises the exact cache invalidation logic.
assert '#if defined(__OBJC__)' in shared
objc=shared.split('#if defined(__OBJC__)',1)[1].split('#else',1)[0]
cpp=shared.split('#else',1)[1].split('#endif',1)[0]
assert 'NSString *program=source();' in objc
assert 'if(slot==4 || slot==5 || slot==6)' in objc
assert 'NSString *routeGate=' in objc
assert 'program=[NSString stringWithFormat:' in objc
assert 'NSString' not in cpp and 'long program=0;' in cpp
assert shared.count('initWithSource:program')==1
assert shared.count('scripts[slot]=')==1
# Crucially exercise the actual historical C++98 fixture, not a mock assertion.
runpy.run_path(str(R/'tests/test_v7596_web_cache.py'))
# Keep the real JavaScript route behavior and instrumentation contract tested.
runpy.run_path(str(R/'tests/test_v7631_search_pdp_fastpath_and_perf_pull.py'))
print('PASS: Objective-C++ checkout gate retained; real v7.596 gnu++98 cache fixture compiles and executes; Search/PDP route contract passes')
