# AmazonDark v7.475 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7475.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.475-pdp-offsite-nav-separators-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.475-pdp-offsite-nav-separators-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.475: harden PDP offsite card family and nav separators"; fi &&
git push origin main
```

## FULL — v7.475
Take one screenshot on the target PDP and leave Amazon foregrounded until the FULL walk finishes.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.475
Arm one VIEWPORT capture first.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to the exact target scene, leave it visible, then background Amazon once.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.475
Arm one transition capture.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Reproduce the transition once, then check/export it.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
