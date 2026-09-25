# AmazonDark v7.495 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7495.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.495-orders-followup-r3-source.zip" -d "$AD_STAGE" &&
test -f "$AD_STAGE/src/Tweak.xm" &&
test -f "$AD_STAGE/scripts/validate.sh" &&
test -f "$AD_STAGE/Makefile" &&
rm -rf src scripts tests layout prefs .github .ad-regressions.* .ad-regressions-manual &&
cp -a "$AD_STAGE/src" "$AD_STAGE/scripts" "$AD_STAGE/tests" "$AD_STAGE/layout" "$AD_STAGE/prefs" "$AD_STAGE/.github" . &&
cp -f "$AD_STAGE/Makefile" . &&
for f in control README.md THIRD_PARTY_NOTICES.md; do [ ! -e "$AD_STAGE/$f" ] || cp -f "$AD_STAGE/$f" .; done &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh scripts/validate.sh &&
test ! -e tests/test_v7490_your_orders_theme.py &&
test ! -e tests/test_v7491_your_orders_followup.py &&
test ! -e tests/test_v7492_ci_handoff_repair.py &&
test ! -e tests/test_v7493_orders_endtext_ci_repair.py &&
test ! -e tests/test_v7494_orders_exact_fix.py &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
if ! git diff --cached --quiet; then git commit -m "v7.495: fix Orders search underline geometry, raster top seam, centered qty badge, and prime tile taming"; fi &&
git push origin main
```

## FULL — v7.495

### Export

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.495

### Arm

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

### Export

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.495

### Arm

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

### Export

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
