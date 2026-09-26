# AmazonDark v7.503 commands

## PUSH

```sh
DOCS="/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents"; ZIP="$DOCS/AmazonDark-v7.503-ci-core-hash-repair-source.zip"; REPO="/var/mobile/Amazon-Dark-phone"; TMP="/var/mobile/AmazonDark-v7.503"; rm -rf "$TMP" && mkdir -p "$TMP" && unzip -q "$ZIP" -d "$TMP" && cd "$REPO" && find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + && cp -a "$TMP/." . && grep '^Version:' layout/DEBIAN/control && AD_STRICT_VALIDATE=0 sh scripts/validate.sh && git add -A && git commit -m "v7.503: restore stable core hash and retain PDP ad background fix" && git push origin main
```

## FULL — v7.503

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.503 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.503 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.503 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.503 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
