# AmazonDark v7.444 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
rm -rf /var/mobile/t7444 &&
mkdir -p /var/mobile/t7444 &&
unzip -oq "$D/AmazonDark-v7.444-pdp-proven-media-source.zip" -d /var/mobile/t7444 &&
cp -a /var/mobile/t7444/AmazonDark-v7.444-pdp-proven-media-source/. . &&
rm -f tests/test_v7441_pdp_site_isolated_frames.py tests/test_v7442_user_style_ad_ownership.py tests/test_v7443_core_concat_validation_fix.py &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.444: restore bundle images and tame brand artwork" &&
git push origin main
```

## FULL
Take the screenshot that triggers FULL, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```
With the target UI visible, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```
Reproduce the transition, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
