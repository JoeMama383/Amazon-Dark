# AmazonDark v7.525 commands

## Push

Save `AmazonDark-v7.525-returns-thumbnail-handoff-regression-repair-source.zip` on the phone first. This command finds the downloaded archive; phone validation permits missing Python, while GitHub CI remains strict.

```sh
cd /var/mobile/Amazon-Dark-phone &&
ZIP=$(find /var/mobile -type f -name 'AmazonDark-v7.525-returns-thumbnail-handoff-regression-repair-source*.zip' 2>/dev/null | head -n 1) &&
[ -n "$ZIP" ] &&
STAGE=$(mktemp -d /var/mobile/ad7525.XXXXXX) &&
unzip -q "$ZIP" -d "$STAGE" &&
grep -qx 'Version: 7.525~returns-thumbnail-handoff-regression-repair' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.525: restore AmazonDark handoff contract" &&
git push origin main
```

## FULL — v7.525

Take one screenshot on the target Amazon screen. Keep Amazon open until the walk finishes, then switch to NewTerm and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.525 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

After arming, open Amazon at the target scene, then switch back to NewTerm.

## VIEWPORT — v7.525 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.525 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

After arming, reproduce the transition in Amazon, then return to NewTerm.

## TRANSITION — v7.525 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
