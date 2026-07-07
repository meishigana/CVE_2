# QEMU Feasibility Assessment

## What Was Verified

The included QEMU Lua RPC harness verifies:

- the real `ui.lua` validator has no `update_langs` method rule;
- the exact malicious `week` argument passes the fallback RPC string validator;
- the real `usr/lib/oui-httpd/rpc/ui` module's `update_langs` function accepts the argument;
- the firmware `uci` Lua module persists the malicious `gl_timer.langs.week` value;
- the generated cron content contains an injected second cron line;
- the injected command creates `/tmp/glinet_ui_rpc_timer_pwn`.

The secondary QEMU/rootfs harness verifies:

- the firmware `uci` binary accepts and persists a `gl_timer.langs.week` value containing newline and tab characters;
- the persisted value survives `uci get`;
- the vulnerable `/etc/init.d/gl_timer` cron-generation logic creates an additional attacker-controlled root cron line;
- the injected cron command line creates the marker file `/tmp/glinet_ui_timer_pwn`.

## What Was Not Verified

This package does not claim:

- unauthenticated exploitation;
- real-device exploitation;
- a full nginx `/rpc` login-session end-to-end run.

## Why The Evidence Is Still Useful

The remaining unverified part is the HTTP/nginx session transport. The RPC source path and validator behavior are now covered by the Lua RPC harness and static evidence:

- `ui.update_langs` exists in the reviewed `ui` RPC module on MT3000, MT6000, and X3000 firmware.
- `ui.lua` validator lacks an `update_langs` rule.
- the default validator allows the exact control characters needed by the PoC.
- the sink is a shell script that writes root cron content.

The dynamic proof validates the dangerous persistence and execution boundary without requiring a physical router.
