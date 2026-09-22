# Phone handoff

Save AmazonDark-v7.452-probe-recovery-source.zip into your shared Documents folder.
This is source for GitHub Actions, not an installable deb. Do not run probes until
Actions has passed and the resulting v7.452 package is installed.

```sh
mkdir -p /var/mobile/AmazonDark-v7.452-source
unzip -o /private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents/AmazonDark-v7.452-probe-recovery-source.zip -d /var/mobile/AmazonDark-v7.452-source
cp -a /var/mobile/AmazonDark-v7.452-source/AmazonDark-v7.452-probe-recovery-source/. /var/mobile/Amazon-Dark-phone/
cd /var/mobile/Amazon-Dark-phone
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
```

Strict validation requires Python and compiler tools; Actions provides the build
environment. Review the diff, then push from the phone as usual:

```sh
cd /var/mobile/Amazon-Dark-phone
git add -A && git commit -m "v7.452: repair full probe bridge and preserve DOM evidence" && git push origin main
```

## FULL
After installing, open the target page and take one screenshot. Leave Amazon active
while the finite capture runs. Product pages inventory offscreen mounted DOM without
auto-scrolling; search pages also attempt a scroll sweep. Then switch to NewTerm:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh status
sh scripts/ui-probe.sh export full
```

## VIEWPORT
Arm in NewTerm, return to Amazon, show the desired scene, then switch back to NewTerm.
The background boundary captures that last scene. No screenshot is necessary.

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

After returning from Amazon:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export viewport
```

## TRANSITION

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Reproduce the transition in Amazon, then return to NewTerm:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```

All probe exports remain plain TAR. A partial receipt is not proof of complete
coverage. See AUDIT-v7.452.md for the known on-device verification limits.
