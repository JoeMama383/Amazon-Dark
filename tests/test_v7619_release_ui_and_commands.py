"""Release guard: v7.605+ retained UI modules and three independent probe handoffs."""
from pathlib import Path
import json, re
R=Path(__file__).resolve().parents[1]
s=(R/'src/Tweak.xm').read_text()
pkg=(R/'layout/DEBIAN/control').read_text()
cmd=(R/'COMMANDS.md').read_text()
assert 'Version: 7.619~handoff-regression-repair' in pkg
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in s
for heading in ('## FULL — v7.619', '## VIEWPORT — v7.619 ARM',
                '## VIEWPORT — v7.619 EXPORT', '## TRANSITION — v7.619 ARM',
                '## TRANSITION — v7.619 EXPORT'):
    assert heading in cmd,heading
for block in ('scripts/ui-probe.sh export full','scripts/ui-probe.sh arm',
              'scripts/ui-probe.sh export viewport','scripts/skeleton-probe.sh arm transition',
              'scripts/skeleton-probe.sh export'):
    assert block in cmd,block
assert cmd.count('AmazonDark-v7.619-handoff-regression-repair-source.zip')>=2
modules=('ADSustainabilityBorder7605','ADClimatePledge7606','ADPDPLastMile7607',
         'ADReviewFilterMenu7608','ADReviewSortPopover7609','ADYourSaves7611','ADKeepShopping7613')
locations=[]
for module in modules:
    inc='#include "'+module+'.js.inc"'
    assert s.count(inc)==1,inc
    locations.append(s.index(inc))
    js=(R/'src'/ (module+'.js')).read_text()
    cpp=(R/'src'/(module+'.js.inc')).read_text()
    assert js==''.join(json.loads(line) for line in cpp.splitlines()),module
assert locations==sorted(locations),'new UI injectors moved out of commit order'
for marker in ('ADProfilePickerRepaint7610','ADNotificationsController7610','ADLiveTitlePlate7612',
               'ADLiveFollowPill7612','ADLiveOwnVideo7612','ADLiveOwnVector7612',
               'ADLiveTextOwner7612','ADLiveThemeTextStorage7612','%hook AmazonIvsView'):
    assert marker in s,marker
print('PASS: v7.619 handoff commands & source preservation: seven later OLED menus, native profile/notifications/live, three independent probes')
