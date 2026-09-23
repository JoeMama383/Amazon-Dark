# AmazonDark v7.457 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7457.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.457-screenshot-share-diagnostic-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.457-screenshot-share-diagnostic-source/." . &&
rm -f src/ADPDPManualTracker7455.js.inc src/ADPDPManualSample7455.js.inc &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.457: temporary Share recovery and screenshot handler diagnostics"; fi &&
git push origin main
```

`sh scripts/validate.sh` is intentionally non-strict on the phone; Python regressions run in CI when Python is unavailable on iOS.

## FULL — non-PDP

Take one screenshot in Amazon and leave it foregrounded while the automatic walk runs. Then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## FULL — Product Detail

After installing the CI package, fully close and reopen Amazon once. Keep `Close Screenshot Share for FULL (Temporary)` ON. Send the exported TAR so screenshot observer registration evidence can identify a selective prevention target.

Take one screenshot and leave Amazon visible. The probe closes the screenshot Share sheet, waits for scrolling to unlock, and walks automatically. After completion, switch to the terminal. Export does not require Amazon to remain foregrounded. Then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon with the target scene visible, background once, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Reproduce the transition, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
