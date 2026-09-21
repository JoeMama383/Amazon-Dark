# AmazonDark v7.437 commands

## Push source to GitHub

```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7437
mkdir -p /var/mobile/t7437
unzip -oq "$D/AmazonDark-v7.437-pdp-standalone-ad-treatment-source.zip" -d /var/mobile/t7437
cp -a /var/mobile/t7437/AmazonDark-v7.437-pdp-standalone-ad-treatment-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.437: standardize PDP standalone ad treatment"
git push origin main
```

## FULL
Take the target screenshot, allow the finite sweep to finish, then:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Then reproduce/leave the target visible and export:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Then reproduce and export:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
