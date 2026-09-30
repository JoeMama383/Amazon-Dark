# AmazonDark v7.524 commands

Save `AmazonDark-v7.524-returns-thumbnail-render-geometry-revert-source.zip` on the phone first.

## Push source to GitHub
```sh
ZIP=$(find /var/mobile -type f -name 'AmazonDark-v7.524-returns-thumbnail-render-geometry-revert-source*.zip' 2>/dev/null | head -n 1) && \
STAGE=$(mktemp -d) && unzip -q "$ZIP" -d "$STAGE" && cd "$STAGE" && \
grep -qx 'Version: 7.524~returns-thumbnail-render-geometry-revert' layout/DEBIAN/control && \
rm -rf .git && git init && git remote add origin git@github.com:JoeMama383/Amazon-Dark.git && \
git checkout -b main && git add . && git commit -m "v7.524: keep Returns thumbnail lane rendered and preserve authored geometry" && \
git branch -M main && git push -uf origin main
```

## Validate locally
```sh
sh scripts/validate.sh
```

## FULL — v7.524
```sh
sh scripts/ui-probe.sh full
```

## VIEWPORT — v7.524 ARM
```sh
sh scripts/ui-probe.sh viewport-arm
```

## VIEWPORT — v7.524 EXPORT
```sh
sh scripts/ui-probe.sh viewport-export
```

## TRANSITION — v7.524 ARM
```sh
sh scripts/skeleton-probe.sh arm
```

## TRANSITION — v7.524 EXPORT
```sh
sh scripts/skeleton-probe.sh export
```
