# AmazonDark v7.377 commands

# PHONE PUSH — established dependency-free workflow.
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7377 && mkdir -p /var/mobile/t7377 && unzip -q "$D/AmazonDark-v7.377-byg-stepper-hydration-switcher-source-fix-source.zip" -d /var/mobile/t7377 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7377/AmazonDark-v7.377-byg-stepper-hydration-switcher-source-fix-source/. . && bash scripts/lint-logos.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.377: fix BYG controls hydration and switcher source ownership" && git push origin main

# VIEWPORT — arm once, then capture current screen without scrolling.
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL — take an iOS screenshot with the target state open.

# UI EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

# TRANSITION / APP-SWITCHER TRACE
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

# TRANSITION EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
