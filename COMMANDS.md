# AmazonDark v7.439 commands

Use only `AmazonDark-v7.439-pdp-ui-completion-release-source.zip`. The unique filename and package-version preflight prevent an older archive from silently replacing this release.

## Push

```sh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
Z="$D/AmazonDark-v7.439-pdp-ui-completion-release-source.zip"
T=/var/mobile/t7439

[ -f "$Z" ] || { echo "ERROR: missing $Z"; exit 1; }
rm -rf "$T"
mkdir -p "$T"
unzip -oq "$Z" -d "$T"
SRC="$T/AmazonDark-v7.439-pdp-ui-completion-source"
[ -d "$SRC" ] || { echo "ERROR: wrong archive layout"; exit 1; }
grep -qx 'Version: 7.439~pdp-ui-completion' "$SRC/layout/DEBIAN/control" || { echo "ERROR: archive is not v7.439"; exit 1; }
grep -q '#define AD_VERSION "v7.439-pdp-ui-completion"' "$SRC/src/Tweak.xm" || { echo "ERROR: source identity mismatch"; exit 1; }

cp -a "$SRC"/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh

git status --short
git diff --quiet && git diff --cached --quiet && { echo "ERROR: no source diff after v7.439 handoff; stop instead of pushing"; exit 1; }
git add -A
git commit -m "v7.439: finish probe-backed PDP UI treatment"
git push origin main
```

## FULL

Leave the target UI visible and take an iOS screenshot. After the finite sweep completes:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Then export:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Reproduce the transition, then:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
