# AmazonDark v7.447 commands

## Push source

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7447.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.447-probe-responsiveness-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.447-probe-responsiveness-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
git add -A &&
git commit -m "v7.447: background-safe viewport and unified TAR probes" &&
git push origin main
```

CI runs the regression gates. Local validation: `sh scripts/validate.sh`.

## FULL

Take one screenshot in Amazon and let the finite FULL sweep finish. Then switch to NewTerm and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

With Amazon already on the target screen, switch to NewTerm and arm:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon. Leave the exact target scene visible, then background Amazon once by switching back to NewTerm. That background transition captures the last foreground scene. Export while Amazon stays backgrounded:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Force-close and reopen Amazon within five minutes, reproduce Search → Product within the recording window, then export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```

FULL, VIEWPORT, and TRANSITION each export separately to Shared Documents as plain `.tar`. No exporter bundles the other probe modes, and TRANSITION does not bundle historical recordings.
