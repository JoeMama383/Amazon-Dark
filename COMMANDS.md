AmazonDark v7.360 — Search Tiles media + Cart coupon parity
============================================================

SOURCE ZIP
==========
AmazonDark-v7.360-search-tiles-cart-coupon-fix-source.zip

1) STAGE
========
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/t7360

cd /var/mobile/Amazon-Dark-phone
git checkout -q main
git fetch origin main
git merge --ff-only origin/main
BASE=$(sed -n 's/^Version: //p' layout/DEBIAN/control | head -n 1)
case "$BASE" in
  7.358~search-row-shop-style-leaf-fix|7.359~product-mab-controls-menu-fix) ;;
  *) echo "Unexpected AmazonDark base: $BASE"; exit 1 ;;
esac

rm -rf "$T"
mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.360-search-tiles-cart-coupon-fix-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.360-search-tiles-cart-coupon-fix-source/." .

2) VERIFY
=========
cd /var/mobile/Amazon-Dark-phone
grep -qx 'Version: 7.360~search-tiles-cart-coupon-fix' layout/DEBIAN/control
grep -q '#define AD_VERSION "v7.360-search-tiles-cart-coupon-fix"' src/Tweak.xm
grep -q 'data-component-type=s-tiles-carousel-component] .scx-stt-image-container' src/Tweak.xm
grep -q 'data-csa-c-painter=cart-coupon' src/Tweak.xm
grep -q 'puis-mab-overlay' src/Tweak.xm
grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm
git diff --check
git status --short

3) COMMIT / PUSH
================
cd /var/mobile/Amazon-Dark-phone
git add -A
git commit -m 'v7.360: tame Search Tiles media and restore Cart coupon styling'
git push origin main

AFTER INSTALL
=============
sbreload

PRODUCT SEARCH SCREENSHOT PROBE
===============================
# Put the Search Tiles / Researched-by-Alexa carousel on screen, then trigger once.
PID=$(pgrep -x Amazon | head -n 1); test -n "$PID" || { echo "Amazon process not found."; exit 1; }; kill -USR2 "$PID"

# Export newest product-scroll capture.
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-product-scroll-probe-*.txt(N.om[1]))
if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No product-scroll screenshot probe found."; fi

CART UI SCREENSHOT PROBE
========================
# Put the coupon price button on screen, then trigger once.
PID=$(pgrep -x Amazon | head -n 1); test -n "$PID" || { echo "Amazon process not found."; exit 1; }; kill -USR2 "$PID"

# Export newest completed Cart capture.
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-cart-ui-probe-*.txt(N.om[1]))
if (( ${#files} )); then P=$files[1]; if grep -q 'CART_PROBE_END' "$P" 2>/dev/null; then cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "Newest Cart probe is still scanning. Keep Amazon foregrounded and rerun only this export block."; fi; else echo "No Cart screenshot probe found."; fi

SKELETON / TRANSITION PROBE
===========================
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
