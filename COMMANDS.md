# AmazonDark v7.427 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
mkdir -p /var/mobile/t7427
unzip -oq "$D/AmazonDark-v7.427-native-ai-results-oled-source.zip" -d /var/mobile/t7427
cp -a /var/mobile/t7427/AmazonDark-v7.427-native-ai-results-oled-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.427: theme native Alexa AI results"
git push origin main
```

## FULL — TRIGGER

Leave the exact target visible and take an iOS screenshot.

## FULL — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT — ARM

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

## VIEWPORT — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION — ARM

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

## TRANSITION — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
