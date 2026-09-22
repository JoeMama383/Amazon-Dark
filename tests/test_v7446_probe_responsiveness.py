from pathlib import Path
import subprocess
R=Path(__file__).resolve().parents[1]
subprocess.run(['node',str(R/'tests/probe_responsiveness7446.cjs'),str(R)],check=True)
s=(R/'src/ADUniversalUIProbe7362.inc').read_text()
assert 'scrollEnabled=NO' not in s
assert 'scroll-owner-stalled' in s and 'gADUIProbeDeadline7446' in s
assert 'frameCompleteness=unverified' in s
print('PASS: v7.446 bounded diagnostic capture and explicit incomplete coverage')
