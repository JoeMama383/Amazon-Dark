from pathlib import Path
import subprocess,tempfile
R=Path(__file__).resolve().parents[1]
h=(R/'src/ADKeyboardTrace7538.h').read_text()
t=(R/'src/Tweak.xm').read_text()
assert 'static __thread BOOL reading=NO' in h and '@finally { reading=NO; }' in h
assert h.index('if([seen[key] isEqual:state])')<h.index('if(!ADKeyboardBudgetTake7539')
assert 'seen.count>=256' in h and 'duplicatesSuppressed' in h and 'budgetDropped' in h
assert 'count>=512)return' not in h
block=t.split('%hook UITextInputTraits',1)[1].split('%end',1)[0]
assert 'UIKeyboardAppearance a=%orig;' in block and 'return a;' in block and '@"legacy.read",a,a' in block
assert '%orig;' in block and '@"legacy.write",a,a' in block
assert 'UIKeyboardAppearanceDark' not in block
assert t.count('if(ADSkelTransition7339&&ADSkelActive7339())ADKeyboardTrace7538(traits,[NSString stringWithFormat:@"owner:%p",self],-1,-1);')==3
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'budget.cpp';exe=Path(d)/'budget'
 p.write_text('''#include "ADKeyboardTraceBudget7539.h"
#include <assert.h>
int main(){ADKeyboardBudget7539 b={0,0,0};
for(int i=0;i<512;i++)assert(ADKeyboardBudgetTake7539(&b,1));
for(int i=0;i<10000;i++)assert(!ADKeyboardBudgetTake7539(&b,2));
assert(b.dropped==10000);
assert(ADKeyboardBudgetTake7539(&b,9.78));
assert(b.count==1);
assert(ADKeyboardBudgetTake7539(&b,15.26));
assert(ADKeyboardBudgetTake7539(&b,15.54));
assert(b.count==2);
return 0;}
''')
 subprocess.run(['g++','-std=c++98','-Wall','-Wextra','-Werror','-I',str(R/'src'),str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS: bounded keyboard budget recovers after burst/background; legacy getter preserves original value and diagnostic recursion is guarded')
