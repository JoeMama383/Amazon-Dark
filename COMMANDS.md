# AmazonDark v7.361 source handoff

Save `AmazonDark-v7.361-probed-renderer-paint-fix-source.zip` in the usual shared Documents folder.

Import the source in NewTerm:

```sh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
cd /var/mobile/Amazon-Dark-phone &&
git checkout -q main && git pull --ff-only origin main &&
unzip -oq "$D/AmazonDark-v7.361-probed-renderer-paint-fix-source.zip" -d /var/mobile/t7361 &&
cp -a /var/mobile/t7361/AmazonDark-v7.361-probed-renderer-paint-fix-source/. .
```

Commit and push:

```sh
git add -A &&
git commit -m 'v7.361: fix probed card, icon, coupon and carousel paint' &&
git push origin main
```

Install the resulting GitHub Actions package, then run `sbreload` as usual. Open Amazon again so the new injected styles load.

## Screenshot probes

Take one screenshot while each issue is visible inside Amazon. The Product Search probe records the visible area without scrolling; the Cart probe performs its existing finite scan. Keep Amazon foregrounded while Cart finishes.

Export the newest Product Search and completed Cart captures in NewTerm **zsh**:

```zsh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
for kind in product-scroll cart-ui; do
  files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-${kind}-probe-*.txt(N.om[1]))
  if (( ! ${#files} )); then echo "No $kind capture found."; continue; fi
  P=$files[1]
  if [[ $kind == cart-ui ]] && ! grep -q CART_PROBE_END "$P"; then
    echo 'Cart scan is still running. Keep Amazon foregrounded, then rerun export.'
    continue
  fi
  cp -f "$P" "$D/" && chmod 666 "$D/${P:t}" && ls -lh "$D/${P:t}"
done
```

The v7.309 filename is intentional. Check the second line for `version=v7.361-probed-renderer-paint-fix` before sending a new capture. No gzip is needed.

## Existing transition/skeleton probe

If needed, force-close Amazon, arm, then open it and reproduce:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
```

Export:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```

Use `arm home`, `arm cart`, or `arm both` for the existing skeleton capture modes.
