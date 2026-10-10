from pathlib import Path
import subprocess,tempfile,json
R=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'pixels.c';out=Path(d)/'pixels'
 p.write_text('''#include "ADServiceRaster7565.h"
#include <assert.h>
int main(void){
 unsigned char rim[]={8,8,8,8},pale[]={210,220,219,255},teal[]={0,110,112,255},bright[]={0,220,180,255},clear[]={0,0,0,0};
 ADServiceBannerPixel7565(rim);assert(rim[0]==0&&rim[1]==0&&rim[2]==0&&rim[3]==8);
 ADServiceBannerPixel7565(pale);assert(pale[0]==0&&pale[1]==0&&pale[2]==0);
 ADServiceBannerPixel7565(teal);assert(teal[0]==0&&teal[1]>=185&&teal[2]==191&&teal[3]==255);
 ADServiceBannerPixel7565(bright);assert(bright[1]==220&&bright[2]==180);
 ADServiceBannerPixel7565(clear);assert(clear[3]==0);
 return 0;}
''')
 subprocess.run(['cc','-I',str(R/'src'),str(p),'-o',str(out)],check=True)
 subprocess.run([str(out)],check=True)
J=''.join(json.loads(l) for l in (R/'src/ADNewMenus7482.js.inc').read_text().splitlines() if l.strip())
assert '.aplf-searchbar-icon #Shape{stroke:#fff!important;}' in J
rule=J[J.index('#aplf-map-container-mobile .mapboxgl-ctrl.mapboxgl-ctrl-attrib,#'):].split('}',1)[0]
assert 'background-color:transparent!important' in rule
assert 'background:' not in rule and 'background-image' not in rule # preserve black information artwork
print('PASS: Health raster pale/low-alpha edge cleanup, cyan contrast and alpha/bright-color preservation; map ring stroke and transparent attribution background')
