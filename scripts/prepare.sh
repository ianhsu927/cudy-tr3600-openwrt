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
# Pin custom plugins, so firmware includes the verified fan lock fix.
# Fetch into a scratch directory and keep only package files in the build tree.
custom_sources="$ROOT/output/custom-plugin-sources.txt"
: > "$custom_sources"
add_custom_package() {
  local repo=$1 revision=$2 subdir=$3 name=$4 source
  source="$ROOT/custom-plugins/$name"
  mkdir -p "$source"
  git -C "$source" init -q
  git -C "$source" remote add origin "https://github.com/ianhsu927/$repo.git"
  git -C "$source" fetch --depth 1 origin "$revision"
  git -C "$source" checkout --detach FETCH_HEAD
  test "$(git -C "$source" rev-parse HEAD)" = "$revision"
  test -f "$source/$subdir/Makefile"
  mkdir -p "package/$name"
  tar -C "$source/$subdir" --exclude=.git -cf - . | tar -C "package/$name" -xf -
  printf '%s: %s (%s)\n' "$name" "$revision" "$repo" >> "$custom_sources"
}
add_custom_package luci-app-usb-tethering a752832a17261a6ccf2474defa6b3e5d7848427b luci-app-usb-tethering luci-app-usb-tethering
add_custom_package luci-app-tr3600-manager 979e4560a7e07fd974bae18a6db5d286b7eb1776 . luci-app-tr3600-manager
add_custom_package luci-app-net-doctor be42a485885ae112759702556d9961228559103c . luci-app-net-doctor
# One owner for tr3600.led: the manager already includes LED control.
test ! -d package/luci-app-tr3600-led
for backend in tr3600.manager tr3600.fan tr3600.led; do
  test -x "package/luci-app-tr3600-manager/root/usr/libexec/rpcd/$backend"
done
test -x package/luci-app-tr3600-manager/root/etc/init.d/tr3600-fan
test -x package/luci-app-tr3600-manager/root/usr/sbin/tr3600-fan-guard
test -f package/luci-app-tr3600-manager/root/etc/config/tr3600_fan
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
  cat "$custom_sources"
  ./scripts/feeds list -s
} > "$ROOT/output/sources.txt"
cp .config "$ROOT/output/build.config"
