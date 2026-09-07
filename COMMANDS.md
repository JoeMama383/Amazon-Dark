AmazonDark v7.355 — Cart Same-Day + Search title-strip workflow

SOURCE ZIP
  AmazonDark-v7.355-cart-same-day-search-strip-fix-source.zip

SPLIT PUSH

1) Stage
  D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
  T=/var/mobile/t7355
  cd /var/mobile/Amazon-Dark-phone
  git checkout -q main
  git fetch origin main
  git merge --ff-only origin/main
  grep -qx 'Version: 7.354~search-carousel-store-spotlight-fix' layout/DEBIAN/control
  rm -rf "$T"
  mkdir -p "$T"
  unzip -q "$D/AmazonDark-v7.355-cart-same-day-search-strip-fix-source.zip" -d "$T"
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -a "$T/AmazonDark-v7.355-cart-same-day-search-strip-fix-source/." .

2) Verify
  cd /var/mobile/Amazon-Dark-phone
  grep -qx 'Version: 7.355~cart-same-day-search-strip-fix' layout/DEBIAN/control
  grep -q '#define AD_VERSION "v7.355-cart-same-day-search-strip-fix"' src/Tweak.xm
  grep -q '#ssd-ca-buy-box' src/Tweak.xm
  grep -q 'dex-basket-building-bottom-sheet-link' src/Tweak.xm
  grep -q 'cards_carousel_widget-sug-im' src/Tweak.xm
  grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm
  git diff --check
  git status --short

3) Commit/push
  cd /var/mobile/Amazon-Dark-phone
  git add -A
  git commit -m 'v7.355: theme Cart Same-Day and Search title strip'
  git push origin main

PROBES

Trigger:
  PID=$(pgrep -x Amazon | head -n 1)
  kill -USR2 "$PID"

Search export:
  D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
  files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-menu-ui-probe-*.txt(N.om[1]))
  if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No Search/Menu screenshot probe found."; fi

Cart export:
  D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
  files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-cart-ui-probe-*.txt(N.om[1]))
  if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No Cart screenshot probe found."; fi
