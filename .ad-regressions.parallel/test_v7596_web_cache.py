"""Exercise actual cache guards across preference changes and verify no module is dropped."""
from pathlib import Path
import re,shutil,subprocess,tempfile
R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
core=s.split('static NSString *ADCoreWebJS7271(void){',1)[1].split('\n}',1)[0]
shared=s.split('static WKUserScript *ADSharedUserScript7387(',1)[1].split('\n}',1)[0].split('{',1)[1]
fmt,args=re.search(r'stringWithFormat:@"([%@]+)",(.*?)\] stringByAppendingString:',core,re.S).groups()
modules=re.findall(r'\b(AD\w+)\(\)',args)
assert fmt.count('%@')==len(modules)==18,(len(modules),fmt)
assert modules[-1]=='ADAddressManagementJS7412'
assert len(set(modules))==len(modules)
# Replace only Foundation construction with a serial number; execute both production cache guards.
core=re.sub(r'gADCoreWebJSCached7271=\[\[NSString.*?stringByAppendingString:ADNewMenusJS7482\(\)\];','gADCoreWebJSCached7271=++builds;',core,flags=re.S)
shared=shared.replace('static WKUserScript *scripts[8]={nil};','static long scripts[8]={0};')
shared=re.sub(r'scripts\[slot\]=\[\[WKUserScript alloc\].*?;', 'source(); scripts[slot]=++scriptBuilds;',shared)
program='''#include <cassert>
#include <algorithm>
#define MAX std::max
#define MIN std::min
struct Prefs { int whiteTameStrength; bool whiteTame; } gP;
long gADCoreWebJSStrength7271=-1,gADCoreWebJSCached7271=0,builds=0,scriptBuilds=0;
long core(){'''+core+'''}
long shared(unsigned slot,long(*source)(),bool mainOnly,bool strengthDependent){'''+shared+'''}
int main(){
 gP.whiteTameStrength=45;gP.whiteTame=true;
 long a=shared(0,core,false,true);assert(builds==1&&scriptBuilds==1);
 for(int i=0;i<100;i++)assert(shared(0,core,false,true)==a);
 assert(builds==1&&scriptBuilds==1);
 gP.whiteTame=false;long b=shared(0,core,false,true);assert(b!=a&&builds==2);
 gP.whiteTame=true;assert(shared(0,core,false,true)!=b&&builds==3);
 gP.whiteTameStrength=101;long c=shared(0,core,false,true);assert(builds==4);
 gP.whiteTameStrength=999;assert(shared(0,core,false,true)==c&&builds==4);
 gP.whiteTameStrength=-1;long d=shared(0,core,false,true);assert(builds==5);
 gP.whiteTameStrength=-99;assert(shared(0,core,false,true)==d&&builds==5);
 long fixed=shared(4,core,false,false);gP.whiteTame=false;gP.whiteTameStrength=50;
 assert(shared(4,core,false,false)==fixed);
}
'''
compiler=shutil.which('clang++') or shutil.which('g++')
assert compiler,'C++ compiler required'
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'test.cpp').write_text(program)
 subprocess.run([compiler,'-std=gnu++98',str(p/'test.cpp'),'-o',str(p/'test')],check=True,capture_output=True,text=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: every core module is emitted and both cache layers reuse unchanged preferences and refresh strength/toggle changes')
