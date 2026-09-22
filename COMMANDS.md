# AmazonDark v7.445 commands

## PUSH

Copy the v7.445 source ZIP into the shared Documents folder, then run:

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
rm -rf /var/mobile/t7445 &&
mkdir -p /var/mobile/t7445 &&
unzip -oq "$D/AmazonDark-v7.445-probe-transition-hardening-source.zip" -d /var/mobile/t7445 &&
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + &&
cp -a /var/mobile/t7445/AmazonDark-v7.445-probe-transition-hardening-source/. . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.445: harden probes and fix PDP transition skeleton" &&
git push origin main
```

## FULL

Leave the target Amazon screen visible and take one iOS screenshot. Wait for the sweep to finish, then export only FULL:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export full
```

## VIEWPORT

Leave the target UI visible and arm one viewport capture:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Then export only VIEWPORT:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export viewport
```

## TRANSITION

Arm the lifecycle/transition recorder:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Reproduce the target transition, then export only the newest capture from that arm:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```

Each export is a separate ZIP. FULL, VIEWPORT, and TRANSITION do not re-export one another.
