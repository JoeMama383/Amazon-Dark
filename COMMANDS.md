# AmazonDark v7.458 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7458.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.458-probe-backed-pdp-ui-screenshot-disable-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.458-probe-backed-pdp-ui-screenshot-disable-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.458: probe-backed PDP fixes and selective screenshot Share suppression"; fi &&
git push origin main
```

## FULL

For Product Detail scans, enable **Hide Share Sheet for Probes**, take one screenshot, leave Amazon foregrounded until the finite walk completes, then:

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

Return to Amazon with the target scene visible, background once, then:

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
