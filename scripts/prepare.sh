#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
git clone --depth 1 --branch openwrt-25.12 https://github.com/openwrt/openwrt.git "$ROOT/openwrt"
cd "$ROOT/openwrt"
# Device support is not in the stable branch: use the device author's 25.12 PR.
git fetch --depth 1 origin pull/24596/head
git checkout --detach FETCH_HEAD
git clone --depth 1 https://github.com/hyqhyq3/openwrt-cudy-tr3600.git "$ROOT/device-fixes"
git apply --check "$ROOT/device-fixes/cudy-tr3600-v1-fixes.patch"
git apply "$ROOT/device-fixes/cudy-tr3600-v1-fixes.patch"
./scripts/feeds update -a
./scripts/feeds install -a
git clone --depth 1 https://github.com/vernesong/OpenClash.git "$ROOT/OpenClash"
cp -a "$ROOT/OpenClash/luci-app-openclash" package/
cp "$ROOT/config.seed" .config
make defconfig
# Do not silently build a different device or drop required packages.
while IFS= read -r setting; do
  case "$setting" in CONFIG_*=y) grep -Fxq "$setting" .config || { echo "Missing required setting: $setting"; exit 1; };; esac
done < "$ROOT/config.seed"
mkdir -p "$ROOT/output"
{
  printf 'OpenWrt: '; git rev-parse HEAD
  printf 'Device fixes: '; git -C "$ROOT/device-fixes" rev-parse HEAD
  printf 'OpenClash: '; git -C "$ROOT/OpenClash" rev-parse HEAD
  ./scripts/feeds list -s
} > "$ROOT/output/sources.txt"
cp .config "$ROOT/output/build.config"
