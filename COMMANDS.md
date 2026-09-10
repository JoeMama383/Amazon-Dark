# AmazonDark v7.391 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7391 && mkdir -p /var/mobile/t7391
unzip -q "$D/AmazonDark-v7.391-ui-completion-audit-fix-source.zip" -d /var/mobile/t7391
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7391/AmazonDark-v7.391-ui-completion-audit-fix-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.391: close probe-audit UI gaps"
git push origin main
```

## FULL PROBE
Open the target Amazon UI and take one iOS screenshot. The finite universal native + WebUI
sweep runs from the screenshot trigger.

## VIEWPORT PROBE
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

## VIEWPORT/FULL EXPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION PROBE
Force-close Amazon first, arm, launch fresh, and reproduce within 120 seconds:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

## TRANSITION EXPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
