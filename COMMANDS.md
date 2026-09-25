# AmazonDark v7.485 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7485.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.485-ci-validator-identity-repair-source.zip" -d "$AD_STAGE" &&
test -f "$AD_STAGE/src/Tweak.xm" &&
test -f "$AD_STAGE/scripts/validate.sh" &&
test -f "$AD_STAGE/Makefile" &&
cp -a "$AD_STAGE/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.485: repair validator identity normalization"; fi &&
git push origin main
```

## FULL — v7.485

Take one screenshot on the target menu, let the FULL sweep finish, then export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.485

Arm VIEWPORT:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Show the exact target scene and background Amazon once, then export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.485

Arm TRANSITION:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Reproduce the transition once, then export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
