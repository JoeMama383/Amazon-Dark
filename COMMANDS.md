# AmazonDark v7.455 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7455.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.455-pdp-manual-full-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.455-pdp-manual-full-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.455: isolate PDP FULL to manual read-only checkpoints" &&
git push origin main
```

`sh scripts/validate.sh` is intentionally non-strict on the phone; Python regressions run in CI when Python is unavailable on iOS.

## FULL — non-PDP

Take one screenshot in Amazon and leave it foregrounded while the automatic walk runs. Then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## FULL — Product Detail

Start near the top, take one screenshot, then manually scroll through the page to the bottom. Pause briefly at important areas. PDP does not auto-scroll in v7.455. Then:

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
