# v7.454 phone commands

```sh
cd /var/mobile/Amazon-Dark-phone
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh
sh scripts/validate.sh
git add -A
git commit -m "v7.454: fix PDP carousel and start FULL walk first"
git push origin main
```

Do not use `AD_STRICT_VALIDATE=1` on the phone unless Python 3 is installed; GitHub CI supplies the Python regression stage.

FULL: take one screenshot in Amazon and keep Amazon foregrounded until the automatic scrolling stops and returns to the starting offset. Then run status and export full.
