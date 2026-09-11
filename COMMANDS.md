# AmazonDark v7.404 commands

## Push

```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents

rm -rf /var/mobile/t7404 && mkdir -p /var/mobile/t7404
unzip -q "$D/AmazonDark-v7.404-product-scroll-video-alexa-polish-source.zip" -d /var/mobile/t7404
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7404/AmazonDark-v7.404-product-scroll-video-alexa-polish-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.404: polish Product Search video borders and Alexa control"
git push origin main
```

## Universal FULL probe

Leave the target screen visible and take an iOS screenshot. Then:

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## Universal VIEWPORT probe

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Show/reproduce the target screen, then:

```zsh
sh scripts/ui-probe.sh export
```

## Transition / lifecycle probe

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Reproduce the transition within roughly 120 seconds, then:

```zsh
sh scripts/skeleton-probe.sh export
```
