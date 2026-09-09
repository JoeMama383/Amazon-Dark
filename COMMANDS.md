# AmazonDark v7.379 commands

# PHONE PUSH — established dependency-free workflow.
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7379 && mkdir -p /var/mobile/t7379 && unzip -q "$D/AmazonDark-v7.379-teal-transition-forensics-claude-audit-source.zip" -d /var/mobile/t7379 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7379/AmazonDark-v7.379-teal-transition-forensics-claude-audit-source/. . && bash scripts/lint-logos.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.379: deepen teal transition forensics and lock Claude audits" && git push origin main

# VIEWPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL: take an iOS screenshot with target state open.

# UI EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

# TRANSITION / APP-SWITCHER TRACE
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

# TRANSITION EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
