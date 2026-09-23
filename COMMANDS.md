# AmazonDark v7.461 commands

## Push
```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7461.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.461-home-hero-pill-variants-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.461-home-hero-pill-variants-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.461: cover both Home hero Sponsored pill variants"; fi &&
git push origin main
```

## FULL
Take one screenshot on the target screen, then:
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
Return to Amazon, leave the exact target scene visible, background Amazon once, then:
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```
Reproduce the transition once, then:
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
