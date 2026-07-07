# PoC Reproduction

## Environment

Tested from WSL with extracted Xiaomi rootfs under:

`/home/su/xiaomi_rootfs`

Required tools:

- `qemu-aarch64`
- `qemu-arm`
- Bash

## Local Bytecode Harness

Run:

```bash
cd /mnt/e/competition/new_project_for_find_bug
package/xiaomi_ax3000t_be3600_be10000_xqdatacenter_upload_hotplug_rce_2026_07_07/poc/verify_xiaomi_xqdatacenter_upload_hotplug_rce_2026_07_07.sh
```

Expected result:

```text
[ok] BE3600 rn01 1.0.74 real xqdatacenter.upload bytecode wrote a hotplug payload that executed
[ok] BE10000 rp04 1.0.89 real xqdatacenter.upload bytecode wrote a hotplug payload that executed
[ok] AX3000T rd03 1.0.64 real xqdatacenter.upload bytecode wrote a hotplug payload that executed
[ok] AX3000T rd03v2 2.0.12 real xqdatacenter.upload bytecode wrote a hotplug payload that executed
```

## Authenticated Request Shape

The vulnerable route is:

`POST /cgi-bin/luci/;stok=<token>/api/xqdatacenter/upload?target=/etc/hotplug.d/iface/`

The request must be authenticated as router admin. The multipart `file` field content becomes the file body. The multipart metadata filename becomes the destination filename after URL decoding and CRLF normalization.

For validation, use a harmless payload that writes a marker file, for example:

```sh
echo XQDATACENTER_UPLOAD_MARKER > /tmp/xqdatacenter_upload_marker
```

After upload, a later interface hotplug event sources the written file as root.

## Safety Notes

The included PoC scripts do not contact a real router and do not modify the extracted firmware rootfs. They create isolated temporary directories under `/tmp` and use marker-file payloads only.
