#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
git clone --depth 1 --branch openwrt-25.12 https://github.com/openwrt/openwrt.git "$ROOT/openwrt"
cd "$ROOT/openwrt"
# Keep the stable branch checked out; apply only the device support backport.
mkdir -p "$ROOT/output"
device_support_revision=046aec0dccd90f5a156cb8e9725c121c81955dd3
curl --fail --location --retry 3 \
  "https://github.com/openwrt/openwrt/commit/$device_support_revision.patch" \
  -o "$ROOT/output/device-support.patch"
if git apply --reverse --check "$ROOT/output/device-support.patch" 2>/dev/null; then
  echo 'Device support is already present in the stable branch'
else
  git apply --check "$ROOT/output/device-support.patch"
  git apply "$ROOT/output/device-support.patch"
fi
git clone --depth 1 https://github.com/hyqhyq3/openwrt-cudy-tr3600.git "$ROOT/device-fixes"
git apply --check "$ROOT/device-fixes/cudy-tr3600-v1-fixes.patch"
git apply "$ROOT/device-fixes/cudy-tr3600-v1-fixes.patch"
# Generate defaults only for new TR3600 radios; retained wireless UCI stays intact.
git apply --check "$ROOT/scripts/patches/tr3600-wireless-defaults.patch"
git apply "$ROOT/scripts/patches/tr3600-wireless-defaults.patch"
cp "$ROOT/scripts/patches/tr3600-wireless-defaults.patch" "$ROOT/output/"
./scripts/feeds update -a
./scripts/feeds install -a
git clone --depth 1 https://github.com/vernesong/OpenClash.git "$ROOT/OpenClash"
cp -a "$ROOT/OpenClash/luci-app-openclash" package/
# Use Argon's upstream package, including its OpenWrt APK support.
./scripts/feeds uninstall luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
./scripts/feeds uninstall luci-app-argon-config
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
# The USB tethering repository contains the package in a subdirectory.
git clone --depth 1 https://github.com/ianhsu927/luci-app-usb-tethering.git "$ROOT/usb-tethering"
cp -a "$ROOT/usb-tethering/luci-app-usb-tethering" package/
# Bundle the same ARM64 Meta core distributed by OpenClash. Resolve the
# branch once so the downloaded binary and recorded revision stay aligned.
mkdir -p "$ROOT/output" files/etc/openclash/core
core_revision=$(git ls-remote https://github.com/vernesong/OpenClash.git refs/heads/core | awk '{print $1}')
[[ "$core_revision" =~ ^[0-9a-f]{40}$ ]] || { echo 'Cannot resolve OpenClash core revision'; exit 1; }
core_url="https://raw.githubusercontent.com/vernesong/OpenClash/$core_revision/master/meta/clash-linux-arm64.tar.gz"
curl --fail --location --retry 3 "$core_url" -o "$ROOT/output/openclash-core.tar.gz"
tar -xOzf "$ROOT/output/openclash-core.tar.gz" clash > files/etc/openclash/core/clash_meta
test -s files/etc/openclash/core/clash_meta
file files/etc/openclash/core/clash_meta | grep -q 'ELF 64-bit.*ARM aarch64'
chmod 0755 files/etc/openclash/core/clash_meta
{
  printf 'OpenClash core revision: %s\n' "$core_revision"
  printf 'OpenClash core URL: %s\n' "$core_url"
  sha256sum "$ROOT/output/openclash-core.tar.gz" files/etc/openclash/core/clash_meta
} > "$ROOT/output/openclash-core.txt"
rm "$ROOT/output/openclash-core.tar.gz"
cp "$ROOT/config.seed" .config
mkdir -p "$ROOT/output"
make defconfig
cp .config "$ROOT/output/build.config"
# Do not silently build a different device or drop required packages.
missing=0
while IFS= read -r setting; do
  case "$setting" in CONFIG_*=y) grep -Fxq "$setting" .config || { echo "Missing required setting: $setting" | tee -a "$ROOT/output/missing-settings.txt"; missing=1; };; esac
done < "$ROOT/config.seed"
(( missing == 0 )) || exit 1
mkdir -p "$ROOT/output"
{
  printf 'OpenWrt: '; git rev-parse HEAD
  printf 'OpenWrt branch: '; git branch --show-current
  printf 'Device support backport: %s\n' "$device_support_revision"
  printf 'Device fixes: '; git -C "$ROOT/device-fixes" rev-parse HEAD
  printf 'OpenClash: '; git -C "$ROOT/OpenClash" rev-parse HEAD
  printf 'Argon: '; git -C package/luci-theme-argon rev-parse HEAD
  printf 'Argon config: '; git -C package/luci-app-argon-config rev-parse HEAD
  printf 'USB tethering: '; git -C "$ROOT/usb-tethering" rev-parse HEAD
  ./scripts/feeds list -s
} > "$ROOT/output/sources.txt"
cp .config "$ROOT/output/build.config"
