# AmazonDark v7.370 commands

Source: `AmazonDark-v7.370-checkout-script-reinstall-theme-source.zip`

## Stage + push from current v7.369 main

```zsh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.370
cd /var/mobile/Amazon-Dark-phone
git checkout -q main
git fetch origin main
git merge --ff-only origin/main
grep -qx 'Version: 7.369~checkout-isolated-theme' layout/DEBIAN/control
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.370-checkout-script-reinstall-theme-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.370-checkout-script-reinstall-theme-source/." .
grep -qx 'Version: 7.370~checkout-script-reinstall-theme' layout/DEBIAN/control
git diff --check
git add -A
git status --short
git commit -m "v7.370: reliably reinstall and finish checkout theming"
git push origin main
```

## Universal probes

VIEWPORT (target screen open):
```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

FULL: take a screenshot with the target menu open.

Export newest completed FULL + VIEWPORT:
```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
```
