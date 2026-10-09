"""Viewport captures should complete when main renderers finish, even if child-frame bookkeeping is only best-effort."""
from pathlib import Path
src=(Path(__file__).resolve().parents[1]/'src/ADUniversalUIProbe7362.inc').read_text()
assert 'BOOL complete=viewportOnly&&success&&completedWebs==webs.count;' in src
assert 'childFrameCoverage=%@\\n================ END RUN ================' in src and '@"best-effort"' in src
assert 'NSTimeInterval flushDelay=viewportOnly?0.55:1.15;' in src
assert 'if(!viewportOnly&&((gADUIExpectedFrames7446&&gADUIFramePayloads7446==0)||gADUIFrameBatches7446.count>0||gADUniversalUIBridge7433.pending.count>0))gADUIProbePartial7446=YES;' in src
assert 'frameCompleteness=%@\\n' in src and 'viewportOnly?@"best-effort":@"unverified"' in src
print('PASS: viewport probe completion no longer downgrades complete captures solely for deferred child-frame accounting, while FULL retains the strict cross-frame partial gate')
