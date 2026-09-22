# v7.453 phone commands

After extracting this source folder into /var/mobile/Amazon-Dark-phone:

```sh
cd /var/mobile/Amazon-Dark-phone
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
```

After validation succeeds:

```sh
git add -A
git commit -m "v7.453: isolate probe transport, restore guarded full walks, tame newer-model image"
git push origin main
```

FULL — screenshot in Amazon, wait for the walk, then return to NewTerm:

```sh
sh scripts/ui-probe.sh status
sh scripts/ui-probe.sh export full
```

VIEWPORT — arm, view scene in Amazon, then background to NewTerm:

```sh
sh scripts/ui-probe.sh arm
```

```sh
sh scripts/ui-probe.sh export viewport
```

TRANSITION — arm, reproduce in Amazon, export:

```sh
sh scripts/skeleton-probe.sh arm transition
```

```sh
sh scripts/skeleton-probe.sh export
```
