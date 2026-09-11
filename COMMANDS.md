# AmazonDark v7.403 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7403 && mkdir -p /var/mobile/t7403
unzip -q "$D/AmazonDark-v7.403-product-share-sheet-probe-control-source.zip" -d /var/mobile/t7403
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7403/AmazonDark-v7.403-product-share-sheet-probe-control-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.403: complete Product Share sheet and add probe control"
git push origin main
```

## FULL PROBE
Open the target Amazon UI and take one iOS screenshot. The universal native + WebUI full sweep runs from the screenshot trigger. Then export:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT PROBE
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```
Show the target screen, then export:
```zsh
sh scripts/ui-probe.sh export
```

## TRANSITION PROBE
Force-close Amazon, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```
Reproduce within about 120 seconds, return to Amazon, then:
```zsh
sh scripts/skeleton-probe.sh export
```

## SCREENSHOT-SHARE TESTING CONTROL
Settings → AmazonDark → Probe Testing → **Hide Share Sheet for Probes** → Respring. Enable only while collecting screenshot-triggered FULL probes; disable afterward to restore normal Share.
