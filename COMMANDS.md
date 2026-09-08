# AmazonDark v7.362 commands

## Push

Once the v7.362 source is in `/var/mobile/Amazon-Dark-phone`:

```zsh
cd /var/mobile/Amazon-Dark-phone
git add -A
git commit -m "v7.362: consolidate universal full and viewport UI probes"
git push origin main
```

## FULL universal probe

Leave the problem visible and **take one screenshot**.

That writes:

`AmazonDark-v7.362-ui-full-probe-...txt`

## VIEWPORT universal probe

Leave the problem visible and run:

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

That writes:

`AmazonDark-v7.362-ui-viewport-probe-...txt`

It captures the current screen only and does not scroll.

## Export newest FULL + VIEWPORT captures

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
```

## Probe status / disarm

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh status
```

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh disarm
```

## Existing transition/skeleton recorder

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
```

Export:

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```
