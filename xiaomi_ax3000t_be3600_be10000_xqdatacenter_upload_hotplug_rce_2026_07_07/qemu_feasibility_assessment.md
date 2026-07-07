# QEMU Feasibility Assessment

## What Was Verified

The validation harness verifies two parts of the exploit chain:

1. The original firmware `xqdatacenter.lua` bytecode accepts request-controlled `target` and multipart filename values, then writes the uploaded payload to the selected destination.
2. The firmware hotplug mechanism sources files under `/etc/hotplug.d/iface/` using the firmware BusyBox shell.

This was verified with qemu-user on:

- BE3600 armhf
- BE10000 aarch64
- AX3000T rd03 aarch64
- AX3000T rd03v2 arm

## Why This Is Stronger Than Decompiled-Only Evidence

The harness does not reimplement the vulnerable Lua function. It loads the original bytecode from:

`/usr/lib/lua/luci/controller/api/xqdatacenter.lua`

Only the LuCI request environment is stubbed. The upload handler itself is the firmware code.

## Remaining Gap

Full-system validation was not completed because uhttpd/nginx, LuCI dispatch, token generation, and device service state are not fully booted in the current qemu-user environment.

Real-device validation should confirm:

- Successful authenticated multipart HTTP request.
- File creation under `/etc/hotplug.d/iface/`.
- Trigger through a non-destructive interface hotplug event.
