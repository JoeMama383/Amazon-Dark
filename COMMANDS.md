# AmazonDark v7.477 commands

## PUSH

The release ZIP is flat-rooted; `src/`, `layout/`, `scripts/`, and `Makefile` extract directly into the staging directory.

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7477.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.477-pdp-ad-ui-repair-source.zip" -d "$AD_STAGE" &&
test -f "$AD_STAGE/src/Tweak.xm" &&
test -f "$AD_STAGE/scripts/validate.sh" &&
test -f "$AD_STAGE/Makefile" &&
cp -a "$AD_STAGE/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.477: repair PDP standalone ads and nav artifacts"; fi &&
git push origin main
```

## FULL — v7.477
Take one screenshot on the target PDP and leave Amazon foregrounded until FULL finishes.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.477

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to the exact affected scene. For the sticky `Top` row, leave **Top / Details / Explore / Reviews** visible. Then background Amazon once.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.477

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Reproduce the transition once, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
