# CVE Submission Draft

## Title

GL.iNet 4.x `ui.update_langs` authenticated cron command injection via `gl_timer.langs.week`

## Vulnerability Type

CWE-78: Improper Neutralization of Special Elements used in an OS Command  
CWE-20: Improper Input Validation

## Affected Products

Locally reviewed affected firmware:

- GL.iNet GL-MT3000 firmware `4.8.1`
- GL.iNet GL-MT6000 firmware `4.9.0`
- GL.iNet GL-X3000 firmware `4.8.3`

## Description

GL.iNet 4.x firmware contains an authenticated command injection vulnerability in the `ui.update_langs` JSON-RPC method. The method stores attacker-controlled language-update schedule fields into UCI configuration. The `week` value is later read by `/etc/init.d/gl_timer` and written into the root crontab without removing newline or tab characters.

An authenticated administrator can supply a `week` value containing a newline followed by a tab-separated cron expression and command. When `gl_timer` regenerates cron files, the injected second cron line executes as root.

## Attack Vector

Authenticated web-management JSON-RPC request:

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

## Impact

Successful exploitation allows root command execution through the generated system crontab. This can lead to full compromise of router confidentiality, integrity, and availability.

## Evidence

The attached package includes:

- static source-to-sink report;
- QEMU Lua RPC proof that the malicious argument passes validation and reaches the real `ui.update_langs` method;
- QEMU/rootfs proof that the firmware `uci` binary persists the malicious schedule value;
- generated cron output showing the injected cron line;
- marker-file proof of command execution.

## Suggested CVSS

```text
CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:H/I:H/A:H = 7.2 High
```

If the management interface is scored as adjacent-network only, use `AV:A`.

## Suggested Remediation

- Add strict method-specific validation for `ui.update_langs`.
- Restrict `week` to integers `0..6`.
- Restrict `hour` to `0..23` and `min` to `0..59`.
- Reject newline, tab, and other control characters.
- Generate crontab entries from parsed numeric values only.
