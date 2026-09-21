# AmazonDark v7.435 commands

## Push

```sh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7435
mkdir -p /var/mobile/t7435
unzip -oq "$D/AmazonDark-v7.435-probe-backed-pdp-search-fixes-source.zip" -d /var/mobile/t7435
cp -a /var/mobile/t7435/AmazonDark-v7.435-probe-backed-pdp-search-fixes-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.435: fix probe-backed PDP and search surfaces"
git push origin main
```

## FULL

Take an iOS screenshot on the target screen, wait for the finite sweep, then:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Then export:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

After reproducing:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
