# AmazonDark v7.478 commands

## PUSH

The source ZIP is flat-rooted; `src/`, `layout/`, `scripts/`, and `Makefile` extract directly into the staging directory.

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7478.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.478-home-pdp-six-fix-source.zip" -d "$AD_STAGE" &&
test -f "$AD_STAGE/src/Tweak.xm" &&
test -f "$AD_STAGE/scripts/validate.sh" &&
test -f "$AD_STAGE/Makefile" &&
cp -a "$AD_STAGE/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.478: fix six Home and PDP UI owners"; fi &&
git push origin main
```

## FULL — v7.478

Open the target page in Amazon and take **one screenshot**. Leave Amazon foregrounded until the FULL run finishes.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.478

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to the exact affected scene, leave it visible, then background Amazon once.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.478

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Force-close/reopen Amazon within five minutes and reproduce the transition once.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
