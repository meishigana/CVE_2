# CVE Submission Draft

## Vulnerability Title

Authenticated arbitrary file write leading to root command execution in Xiaomi router `xqdatacenter` upload API

## Vulnerability Type

Authenticated arbitrary file write leading to command execution.

Suggested CWE:

- CWE-73: External Control of File Name or Path
- CWE-434: Unrestricted Upload of File with Dangerous Type

## Affected Products

Confirmed in local firmware analysis:

- Xiaomi AX3000T rd03 firmware 1.0.64
- Xiaomi AX3000T rd03v2 firmware 2.0.12
- Xiaomi BE3600 rn01 firmware 1.0.74
- Xiaomi BE10000 rp04 firmware 1.0.89

Other firmware versions sharing the same `xqdatacenter.lua` controller may also be affected.

## Description

The Xiaomi router LuCI controller `luci.controller.api.xqdatacenter` exposes an authenticated upload endpoint at `/api/xqdatacenter/upload`. The handler uses the request-controlled `target` parameter as the destination directory and the multipart file metadata filename as the destination file name. It creates the supplied directory and moves `/userdisk/upload.tmp` to `target .. filename` without constraining the target path to an intended user-storage directory.

An authenticated attacker can write a shell fragment under `/etc/hotplug.d/iface/`. Xiaomi/OpenWrt hotplug handling sources regular files in that directory with `. $script`, so the uploaded file can execute commands as root when an interface hotplug event occurs.

## Attack Preconditions

- Attacker has a valid administrator session/token for the router web interface.
- The `xqdatacenter` feature and route are enabled.
- A hotplug event or equivalent trigger occurs after the upload.

## Impact

Successful exploitation can allow root-level command execution, persistent modification of system scripts, and compromise of router confidentiality, integrity, and availability.

Suggested CVSS v3.1:

`AV:N/AC:L/PR:H/UI:N/S:U/C:H/I:H/A:H` = 7.2 High

## Evidence

The package contains:

- Static route and bytecode dataflow evidence.
- Original firmware controller bytecode hashes.
- qemu-user validation output against four firmware images.
- Local PoC harness that executes original firmware bytecode and validates hotplug execution behavior.

## Validation Boundary

The current proof is local qemu-user validation, not physical-device HTTP validation. The harness invokes the real firmware Lua bytecode and validates the hotplug execution sink with firmware BusyBox, but full uhttpd/nginx and LuCI session handling were not booted.
