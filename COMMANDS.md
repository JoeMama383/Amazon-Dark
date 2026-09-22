# AmazonDark v7.449 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7449.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.449-full-probe-nonblocking-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.449-full-probe-nonblocking-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.449: make FULL probe cooperative and complete" &&
git push origin main
```

## FULL

Leave the target Product Detail screen visible and take one screenshot. FULL will cooperatively auto-scroll the root document, inventory the converged DOM, sweep nested overflow owners, catch newly mounted nodes, and restore its captured scroll positions. The screen may visibly scroll during the diagnostic, but it should not remain main-thread frozen.

After it finishes, switch to NewTerm and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

With Amazon on the target screen, switch to NewTerm and arm:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon, leave the exact target scene visible, then background Amazon once by switching back to NewTerm. Export while Amazon stays backgrounded:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION

Arm before the transition:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Force-close/reopen Amazon when the target transition requires a cold start, reproduce the transition in the recording window, then export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```

FULL, VIEWPORT, and TRANSITION remain isolated and export as plain `.tar` archives.
