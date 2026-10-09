# AmazonDark v7.610 — validation and limits

## Probe evidence
- v7.605 VIEWPORT r6 is the native **Shopping as** screen. Captures `UIWindow > AMSModalLayoutOverlay > sheet-view > sheet-inset-view > profile-picker-close-bottomsheet-button`, `profile-picker-list-profile-item-row-0-account-holder`, `Profile_Hub_Ai_Mode_Ingress`, and `Switch_Accounts_Ingress`. This proves why the prior `AppCXWindow`-only painter failed.
- v7.605 VIEWPORT r7 is **not** the notifications feed despite the screenshot; it contains the underlying React Alexa navigation hierarchy, 0 WebViews. It cannot identify notification list owners, missing thumbnail source data, or any image-hiding code. No real on-device notification-image rendering success is claimed. The optional fallback is controller-class-gated and must be verified with a correct probe.

## Completed PASS
- `python tests/test_v7610_updated_profile_native_notifications.py`
- `python tests/test_v7606_climate_pledge_full_probe.py`
- `python tests/test_v7601_full_scan_partial_diagnostics.py`
- `python tests/test_v7593_reviews_business_theme.py`
- `bash scripts/lint-logos.sh`
- `python -m compileall -q tests src`
- Source ZIP CRC and identity checks.

## Not completed
- The historical `sh scripts/validate.sh` sweep started and progressed through early historical tests but reached the environment execution limit; it was **terminated**, not a PASS. See `AmazonDark-v7.610-validation.log`.
- Full Theos build / CI and device visual verification are pending. No remote Git push performed.

## UI/efficiency guards
- No recurring DOM walker, observer, timer, synthetic notifications/thumbnail request, or media fetch.
- Preserves authored teal/blue action and notification text; leaves sprite geometry unchanged.
