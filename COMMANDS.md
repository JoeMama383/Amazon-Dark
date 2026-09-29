# AmazonDark v7.518 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
test -z "$(git status --porcelain)" &&
DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
STAGE=$(mktemp -d /var/mobile/ad7518.XXXXXX) &&
unzip -q "$DOCS/AmazonDark-v7.518-person-probe-foreground-repair-source.zip" -d "$STAGE" &&
grep -qx 'Version: 7.518~person-probe-foreground-repair' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
rm -f tests/test_v7517_person_returns_probe_rollback.py &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.518: repair foreground probe routing and Returns contours" &&
git push origin main
```

## FULL — v7.518

Open the Person menu, take one screenshot, and leave Amazon foregrounded while it walks. Then switch to NewTerm to export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.518 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Open Amazon to the target screen after arming, then switch back to NewTerm.

## VIEWPORT — v7.518 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.518 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.518 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
