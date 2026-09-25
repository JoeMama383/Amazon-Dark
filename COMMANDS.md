# AmazonDark v7.491 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7491.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.491-orders-followup-source.zip" -d "$AD_STAGE" &&
test -f "$AD_STAGE/src/Tweak.xm" &&
test -f "$AD_STAGE/scripts/validate.sh" &&
test -f "$AD_STAGE/Makefile" &&
cp -a "$AD_STAGE/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.491: follow up Your Orders blue tiles, search seam, and quantity bubble"; fi &&
git push origin main
```

## FULL — v7.491

Take one screenshot while the target Amazon screen is visible and let the automatic walk finish, then run:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.491

Arm VIEWPORT first, return to Amazon, leave the target scene visible, then background Amazon once. After that run:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.491

Arm TRANSITION, reproduce the flow, then export the current armed capture:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh status
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
