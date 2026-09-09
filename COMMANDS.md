# AmazonDark v7.376 commands

# PHONE PUSH — established dependency-free workflow.
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7376 && mkdir -p /var/mobile/t7376 && unzip -q "$D/AmazonDark-v7.376-warm-switcher-noninterference-source.zip" -d /var/mobile/t7376 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7376/AmazonDark-v7.376-warm-switcher-noninterference-source/. . && bash scripts/lint-logos.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.376: restore warm switcher noninterference" && git push origin main

# VIEWPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL
# Take a screenshot with the target state open.

# Export
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
