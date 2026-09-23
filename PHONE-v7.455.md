# AmazonDark v7.455 phone verification

## Product Detail FULL

1. Open a Product Detail page near the top.
2. Take one screenshot to trigger FULL.
3. The page should remain responsive and **must not auto-scroll**.
4. Manually scroll downward. Pause briefly at target/problem areas; the probe records after scroll idle.
5. Continue to the bottom. The final bottom checkpoint should end the PDP FULL session automatically.
6. Go to NewTerm and run `sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status`.
7. Export with `sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full`.

Expected trace markers include `pdpWebPolicy=manual-checkpoint-no-scroll-mutation`, `PDP_MANUAL_TRACKER_ACK`, `PDP_MANUAL_SIGNAL`, `PDP_MANUAL_VIEWPORT_*`, and `PDP_MANUAL_END ... reachedBottom=1 ... programmaticScrollWrites=0`.

## Cart/Search/non-PDP FULL

Take one screenshot and do not manually drive the page. Automatic scrolling should behave as in the good R3 Cart capture and restore the original offset afterward.

## Failure indicators

- Any PDP `WEB_OWNER_STEP kind=root` / generic PDP walk means route isolation failed.
- Any PDP freeze that requires backgrounding means the bounded checkpoint path still needs device-side refinement.
- `PDP_MANUAL_BACKGROUND_STOP` means the user left the PDP before reaching the bottom; export is intentionally partial but remains usable.
