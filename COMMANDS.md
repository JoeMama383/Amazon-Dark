# AmazonDark v7.450 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7450.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.450-pdp-readonly-full-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.450-pdp-readonly-full-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.450: make PDP FULL capture read-only" &&
git push origin main
```

## FULL

Leave the target visible and take one screenshot. On Product Detail, FULL is read-only and should not auto-scroll or move the interface. On other menus, the inherited finite FULL sweep remains unchanged.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon with the target scene visible, then background Amazon once and export from NewTerm:

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

FULL, VIEWPORT, and TRANSITION remain isolated plain `.tar` exports.
