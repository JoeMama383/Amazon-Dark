# AmazonDark v7.452 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7451.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.452-probe-recovery-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.452-probe-recovery-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.452: stream PDP FULL without WebKit continuation churn" &&
git push origin main
```

## FULL

Leave the target visible and take one screenshot. On Product Detail, FULL remains read-only and now streams the full mounted DOM in finite page-side slices rather than repeatedly calling WebKit for each tiny continuation. Do not background Amazon until the capture finishes.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon with the target scene visible, then background Amazon once and export from NewTerm:

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

FULL, VIEWPORT, and TRANSITION remain isolated plain `.tar` exports.
