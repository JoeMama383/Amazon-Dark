# AmazonDark v7.446 commands

Save the source ZIP into Shared Documents. This copies the release into the existing phone checkout. It does not build or install the tweak.

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7446.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.446-probe-responsiveness-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.446-probe-responsiveness-source/." . &&
rm -f tests/test_v7441_pdp_site_isolated_frames.py tests/test_v7442_user_style_ad_ownership.py tests/test_v7443_core_concat_validation_fix.py &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
git add -A &&
git commit -m "v7.446: bounded UI probes and isolated ZIP exports" &&
git push origin main
```

CI runs the regression gates. Local validation command: `sh scripts/validate.sh`.
Install the successful v7.446 Actions build and reopen Amazon before capturing.

## FULL

Take one screenshot in Amazon. Keep Amazon foregrounded during the finite sweep (up to four minutes); then switch to NewTerm and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

Open the target screen first. In NewTerm run this, then return to Amazon within 30 seconds. No screenshot is needed:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

After capture, export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Force-close and reopen Amazon within five minutes. Reproduce Search → Product within the first two minutes. Do not trigger FULL or VIEWPORT while recording the transition; either UI capture ends the active transition recorder.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```

Each export goes to Shared Documents as a separate ZIP. `ui-probe.sh status` and `skeleton-probe.sh status` show capture state. Partial UI captures can be exported and include coverage limitations; send them rather than discarding them.
