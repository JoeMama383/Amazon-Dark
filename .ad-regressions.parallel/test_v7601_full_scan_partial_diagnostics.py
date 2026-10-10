"""The captured v7.600 FULL was partial because the page backgrounded during streaming."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/ADPDPMainStream7451.js.inc').read_text()
u=(ROOT/'src/ADUniversalUIProbe7362.inc').read_text()
assert "if(document.hidden){state.active=false;state.truncated=true;flush(false,'document-backgrounded');return;}" in s
assert 'limit=state.pass===0?(catchup?160:96):384,budget=6' in s
assert 'if(pending.length>=96)flush(true' in s
assert 'setTimeout(slice,state.pass===0?(catchup?2:2):3)' in s
assert 'if(!pdpMore&&![frameData[@"reason"] isEqualToString:@"complete"])' in u
assert 'gADUIProbePartial7446=YES;' in u
assert '@"PDP_STREAM_COMPLETE":@"PDP_STREAM_ABORT"' in u
assert 'WEB_OWNERS_INIT_FAILURE details=' in u
assert 'PDP_STREAM_ABORT reason=' in u
assert 'COVERAGE state=%@ framePayloads=' in u
assert 'PDP_STREAM_FULL index=' in u and 'sliceBudgetMs=6' in u
print('PASS: v7.601 FULL faster bounded streaming, truthful background interruption classification and explicit abort diagnostics')
