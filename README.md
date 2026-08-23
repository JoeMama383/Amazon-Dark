# AmazonDark v7.0.19~probe

Workflow:
1. Open Amazon Home and position the below-carousel cards/floors you want inspected.
2. Background Amazon once.
3. Wait 2–3 seconds.
4. The report is automatically relayed to the normal shared Documents/push folder:
   AmazonDark-home-floor-bottomnav-probe-7019.txt

Probe scope:
- current visible Home viewport only, excluding hero/carousel ancestry;
- bottom ~140 pt native navigation stack only;
- no document walk, MutationObserver, recurring timer, RAF, or scroll listener.

Production nav change remains background-only; no icon/symbology/tint behavior is intentionally changed.
