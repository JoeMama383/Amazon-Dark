# AmazonDark v7.433 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
mkdir -p /var/mobile/t7433 &&
unzip -oq "$D/AmazonDark-v7.433-universal-crossframe-probe-source.zip" -d /var/mobile/t7433 &&
cp -a /var/mobile/t7433/AmazonDark-v7.433-universal-crossframe-probe-source/. . &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.433: expand universal UI probe across SafeFrames" &&
git push origin main
```

## FULL — TRIGGER

Leave the exact target visible and take an iOS screenshot. FULL now captures the main Web document, every injected child/SafeFrame document, and the native hierarchy, then performs the existing finite Web/native sweeps.

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

VIEWPORT now includes visible child/SafeFrame DOM paint state in addition to main-frame Web and native UI.

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
