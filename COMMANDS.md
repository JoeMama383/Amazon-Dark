# AmazonDark v7.508 commands

## PUSH

```sh
DOCS="/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents"; ZIP="$DOCS/AmazonDark-v7.508-orders-prime-bgimage-filter-floor-fix-source.zip"; REPO="/var/mobile/Amazon-Dark-phone"; TMP="/var/mobile/AmazonDark-v7.508"; rm -rf "$TMP" && mkdir -p "$TMP" && unzip -q "$ZIP" -d "$TMP" && cd "$REPO" && find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + && cp -a "$TMP/." . && grep '^Version:' layout/DEBIAN/control && AD_STRICT_VALIDATE=0 sh scripts/validate.sh && git add -A && git commit -m "v7.508: restore Prime background art and seal Orders filter floors" && git push origin main
```

## FULL — v7.508

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.508 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.508 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.508 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.508 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
