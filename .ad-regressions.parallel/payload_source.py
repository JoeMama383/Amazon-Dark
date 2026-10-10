import re,json
from pathlib import Path
# C/ObjC lexer: ignore comments, preserve adjacent narrow/ObjC string literals.
TOKEN=re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|@?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
def block(src,name):
 m=re.search(r'(?m)^(?:static )?NSString \*'+re.escape(name)+r'\(void\)\s*\{',src)
 if not m: raise ValueError(name)
 tokens={x.start():x for x in TOKEN.finditer(src,m.end())}
 depth=1;i=m.end()
 while depth:
  if i in tokens:i=tokens[i].end();continue
  if src[i]=='{':depth+=1
  elif src[i]=='}':depth-=1
  i+=1
 return src[m.start():i]
def strings(src):
 return ''.join(json.loads(x.group()[1:] if x.group().startswith('@') else x.group()) for x in TOKEN.finditer(src) if x.group().startswith(('"','@"')))
def payload(src,name,strength=45):
 b=block(src,name)
 if name in ('ADStandalonePaintJS7104','ADTWBJS','ADCheckoutTWBJS7369'):
  fmt=b[b.index('[NSString stringWithFormat:')+len('[NSString stringWithFormat:'):]
  # End format is followed by factor/shade arguments; C literals only occur before that.
  js=strings(fmt)
  end=max(x.end() for x in TOKEN.finditer(fmt) if x.group().startswith(('"','@"')));tail=fmt[end:];tail=tail[:tail.index('];')]
  args=re.findall(r'\b(factor|shade)\b',tail)
  shade=.10+.48*max(0,min(100,strength))/100;factor=1-shade
  values=iter([factor if a=='factor' else shade for a in args])
  return re.sub(r'%%|%\.(\d+)f',lambda m:'%' if m.group()=='%%' else f'{next(values):.{m[1]}f}',js)
 return strings(b)
NAMES=['ADFloorJS','ADStandalonePaintJS7104','ADTWBJS','ADCheckoutFloorJS7369','ADCheckoutTWBJS7369','ADCheckoutBYGHydrateJS7378','ADPrivacyModeJS7117','ADTWBClearJS791','ADFullRasterHostBridgeJS7266','ADHomeFrameProbeBridgeJS7265','ADHomeAdShellFloorJS7381','ADPriceHistoryJS7380']
