# Technical Report

## Vulnerability

The Xiaomi LuCI controller `luci.controller.api.xqdatacenter` exposes `/api/xqdatacenter/upload` when the xqdatacenter feature is enabled. The node is protected by Xiaomi's admin JSON authentication, so the issue is post-authentication.

The `upload` handler accepts a request parameter named `target` and a multipart file field. The actual bytecode dataflow is:

1. Open `/userdisk/upload.tmp` and write multipart content.
2. Read `target` from `luci.http.formvalue("target")`.
3. Append `/` if needed.
4. Call `luci.fs.mkdir(target, true)`.
5. Use multipart metadata `a0.file` as the final filename after URL decoding and CRLF normalization.
6. Call `luci.fs.rename("/userdisk/upload.tmp", target .. filename)`.

No validation was found to ensure that `target` is under `/userdisk`, `/mnt`, or another intended data directory. No path traversal or absolute-path filtering was found before directory creation or rename.

## RCE Chain

OpenWrt/Xiaomi hotplug execution is implemented by `/sbin/hotplug-call`. The script iterates over `/etc/hotplug.d/<type>/*` and sources each regular file with `. $script`.

Therefore, an authenticated attacker who can call `/api/xqdatacenter/upload` can write a shell fragment to:

`/etc/hotplug.d/iface/99-xqdatacenter-upload-rce`

The payload is executed as root during a later `iface` hotplug event. Executable permissions are not required because the file is sourced by the shell.

## Affected Samples

| Model | Firmware | Architecture | Controller hash |
| --- | --- | --- | --- |
| AX3000T rd03 | 1.0.64 | aarch64 | `83ade4205b67721331ab568e6f9a1b3d5cf0ea864efe014bcd97c3f40f00515e` |
| AX3000T rd03v2 | 2.0.12 | arm | `83ade4205b67721331ab568e6f9a1b3d5cf0ea864efe014bcd97c3f40f00515e` |
| BE3600 rn01 | 1.0.74 | armhf | `83ade4205b67721331ab568e6f9a1b3d5cf0ea864efe014bcd97c3f40f00515e` |
| BE10000 rp04 | 1.0.89 | aarch64 | `53ef12eb0a5c3251c9a933d4f7ba944a03180a904f26e3566381e8949644de73` |

## Static Evidence

Route registration:

- `entry({"api", "xqdatacenter", "upload"}, call("upload"), _(""), 304, 16)`

Observed in:

- AX3000T rd03 `xqdatacenter.lua:31-32`
- AX3000T rd03v2 `xqdatacenter.lua:31-32`
- BE3600 `xqdatacenter.lua:31-32`
- BE10000 `xqdatacenter.lua:31-32`

Bytecode evidence shows `formvalue("target")`, `mkdir`, and `rename` in the upload function. Multipart metadata `a0.file` is copied into the filename variable before the final rename.

See:

- `evidence/static_route_and_upload_sinks.txt`
- `evidence/bytecode_upload_dataflow.txt`
- `evidence/hotplug_call_source_behavior.txt`

## Dynamic Validation

The qemu-user harness directly loads the original `xqdatacenter.lua` bytecode from each rootfs and invokes `upload()` with minimal LuCI stubs. The harness simulates multipart metadata and content, redirects `/userdisk/upload.tmp` to an isolated `/tmp` path, then validates that the written hotplug script is executed by the firmware BusyBox shell.

Validation output:

`evidence/verify_xqdatacenter_upload_bytecode_output.txt`

All four firmware samples produced:

`real xqdatacenter.upload bytecode wrote a hotplug payload that executed`

## Limitations

The current validation is local qemu-user validation, not real-device validation. It verifies the vulnerable controller bytecode and the hotplug execution sink, but it does not prove a live HTTP multipart request through uhttpd/nginx on a physical device.
