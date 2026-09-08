# AmazonDark v7.371 commands

D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.371

cd /var/mobile/Amazon-Dark-phone
git checkout -q main
git fetch origin main
git merge --ff-only origin/main
grep -qx 'Version: 7.370~checkout-script-reinstall-theme' layout/DEBIAN/control
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.371-checkout-residual-ui-fix-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.371-checkout-residual-ui-fix-source/." .
grep -qx 'Version: 7.371~checkout-residual-ui-fix' layout/DEBIAN/control
git diff --check
git add -A
git status --short
git commit -m "v7.371: finish checkout and BYG residual UI"
git push origin main

# VIEWPORT capture with target screen open:
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL capture: take a screenshot with the target screen open.

# Export:
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
