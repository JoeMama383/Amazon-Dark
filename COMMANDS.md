# AmazonDark v7.501 commands

## PUSH

```sh
DOCS="/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents"; ZIP="$DOCS/AmazonDark-v7.501-orders-prime-filter-ad-followup-source.zip"; REPO="/var/mobile/Amazon-Dark-phone"; TMP="/var/mobile/AmazonDark-v7.501"; rm -rf "$TMP" && mkdir -p "$TMP" && unzip -q "$ZIP" -d "$TMP" && cd "$REPO" && find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + && cp -a "$TMP/." . && grep '^Version:' layout/DEBIAN/control && AD_STRICT_VALIDATE=0 sh scripts/validate.sh && git add -A && git commit -m "v7.501: normalize Orders Prime cards and suppress sticky filter border" && git push origin main
```

## FULL — v7.501

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.501 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.501 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.501 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.501 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
