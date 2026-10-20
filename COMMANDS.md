# AmazonDark v7.644 — stylesheet separation and production cleanup

Download `AmazonDark-v7.644-static-style-delivery-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.644-static-style-delivery-source*.zip`.

## PUSH — v7.644 existing clone

Save the ZIP in your shared build Documents folder, then run these short commands:

```sh
cd /private/var/mobile/Containers/Shared/AppGroup/9CA31931-B51F-4CBA-8A0E-8A9F62D94B33/Documents
unzip -q -o AmazonDark-v7.644-static-style-delivery-source.zip
sh ad7644/scripts/push-source.sh
```

The helper copies the extracted source into the existing clone. Inside that clone it removes the two obsolete scanner files, validates before committing, and pushes the existing branch:

```sh
cd /var/mobile/Amazon-Dark-phone
cp -a "$STAGE/." .
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
# Commit only when the staged source changed.
git push origin main
```

This block documents the helper; the three short commands above run the whole workflow, including the copy and commit.

## BUILD — GitHub Actions

The push triggers `.github/workflows/build.yml`. Install the `.deb` from the passing Actions run. Then close Amazon completely once and reopen. This is a production change: Search/product stylesheet delivery avoids live DOM style nodes, the review observer is removed, and unrelated menu classifiers no longer run on these pages. Editable stylesheet sources are separated from runtime templates. The phone latency improvement is not yet verified.

The ZIP is source, not an installable binary. Local tests cannot establish that the phone's delay is cured. Use normal `arm` below, not `arm styles`: style-cost trials deliberately force expensive recalculation. Arm one probe at a time, return to Amazon to reproduce, then return to NewTerm to export. FULL must remain foreground until its sweep completes; backgrounding it can produce a legitimate partial capture.

## STARTUP ISOLATION — v7.644 ARM

Use normal PERFORMANCE capture below first. For an optional `isolate-css` comparison, arm while Amazon is in the background, return to Home, then open a fresh Search result and a fresh product page and swipe its gallery. Already-loaded documents are deliberately excluded. Keep Amazon visible for 30–60 seconds while reproducing the same interaction, then background and export. Selected theme CSS is temporarily absent; incomplete styling in this mode is expected. A simple black root floor remains. Normal mode keeps the full theme.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm isolate-css
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

This optional diagnostic is retained for comparison, not needed to enable the production changes. The report records the requested mode, whether each fresh document qualified, withheld style count/bytes, residual rules and restoration results. A late or incomplete capture must not be treated as successful CSS isolation. It does not disable native theme hooks or JavaScript. v7.644 also counts constructed theme sheets and preserves complete CSS and sheet order on restoration. Export before arming the next run.

Further partitions, if needed: `arm isolate-core` omits the two base Search/product stylesheets; `arm isolate-followups` omits the remaining intercepted sheets. These are deliberately armed alternatives, never automatic experiments.

## PERFORMANCE — v7.644 ARM

Use this normal capture first: open fresh Search results, open a product, then swipe its photos for 30–60 seconds with Amazon foregrounded. The theme stays enabled.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.644 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## FULL — v7.644 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

A screenshot inside Amazon also triggers FULL. Let the sweep finish before exporting.

## FULL — v7.644 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.644 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.644 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.644 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.644 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
