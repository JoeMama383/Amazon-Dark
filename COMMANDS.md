# AmazonDark v7.507 commands

## PUSH

```sh
DOCS="/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents"; ZIP="$DOCS/AmazonDark-v7.507-probe-identity-sync-repair-source.zip"; REPO="/var/mobile/Amazon-Dark-phone"; TMP="/var/mobile/AmazonDark-v7.507"; rm -rf "$TMP" && mkdir -p "$TMP" && unzip -q "$ZIP" -d "$TMP" && cd "$REPO" && find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + && cp -a "$TMP/." . && grep '^Version:' layout/DEBIAN/control && AD_STRICT_VALIDATE=0 sh scripts/validate.sh && git add -A && git commit -m "v7.507: synchronize probe identities and retain Orders fixes" && git push origin main
```

## FULL — v7.507

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.507 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.507 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.507 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.507 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
