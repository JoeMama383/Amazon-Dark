from pathlib import Path
import hashlib,re,json
R=Path(__file__).resolve().parents[1]
T=(R/'src/Tweak.xm').read_text()
C=(R/'layout/DEBIAN/control').read_text()
CMD=(R/'COMMANDS.md').read_text()
assert 'Version: 7.503~ci-core-hash-repair' in C
assert '#define AD_VERSION "v7.503-ci-core-hash-repair"' in T
assert 'AmazonDark-v7.503-ci-core-hash-repair-source.zip' in CMD
assert 'AD_STRICT_VALIDATE=0 sh scripts/validate.sh' in CMD
# v7.501 PDP ad image background remains included, but not by altering ADCoreWebJS7271's composition.
assert 'static NSString *ADPDPAdImageBackgroundJS7501(void);' in T
assert 'stringByAppendingString:ADPDPAdImageBackgroundJS7501()' in T
assert '#include "ADPDPAdImageBackground7501.js.inc"' in T
st=T.index('static NSString *ADCoreWebJS7271')
b=T.index('{',st); d=0
for i in range(b,len(T)):
    if T[i]=='{': d+=1
    elif T[i]=='}':
        d-=1
        if d==0:
            core=T[st:i+1]; break
else: raise AssertionError('ADCoreWebJS7271')
assert 'ADPDPAdImageBackgroundJS7501' not in core
# Exact historical shared-core normalization used by v7.369/v7.370 must still hash identically.
core_n=core.replace('] stringByAppendingString:ADNewMenusJS7482()',']').replace('=[[NSString','= [NSString').replace('()]];','()];').replace('= [NSString','=[NSString').replace('@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@"','@"%@%@%@%@"').replace(',ADProductShareThemeJS7403(),\n        ADProductShareTWBJS7403(),ADShareProbeSuppressJS7403(),ADProductScrollPolishJS7404(),\n        ADProductScrollVideoBorderJS7405(),ADPDPGridCarouselFix7454(),ADPDPCompletionJS7405(),ADPDPSafeFrameJS7432(),ADPDPCompletionTWBJS7405(),ADPDPUICompletionJS7439(),ADPDPMainResidualJS7440(),ADPDPProbeBackedFixesJS7458(),ADFrameOwnerTriggerJS7440(),ADAddressManagementJS7412()','')
assert hashlib.sha256(core_n.encode()).hexdigest()=='41ce925c9bad5362bf65204d4eb9778d016c2015b41b427704943df363b6d30c'
assert (R/'src/Tweak.xm').stat().st_size < 856000
print('PASS: v7.503 keeps the v7.501 PDP ad fix outside the historically hash-locked ADCoreWebJS7271 composition')
