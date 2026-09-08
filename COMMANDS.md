# AmazonDark v7.363 commands

## Push

Once this source is in `/var/mobile/Amazon-Dark-phone`:

```zsh
cd /var/mobile/Amazon-Dark-phone
git add -A
git commit -m "v7.363: fix Search pane media, related searches, and Cart claimed coupon"
git push origin main
```

## FULL universal probe

Leave the problem visible and **take one screenshot**.

Output family:

`AmazonDark-v7.363-ui-full-probe-...txt`

## VIEWPORT universal probe

Leave the problem visible and run:

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

Output family:

`AmazonDark-v7.363-ui-viewport-probe-...txt`

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
