# Xiaomi xqdatacenter upload arbitrary file write to hotplug RCE

## Summary

This package documents an authenticated arbitrary file write vulnerability in Xiaomi router firmware `luci.controller.api.xqdatacenter.upload`.

The `/api/xqdatacenter/upload` handler trusts the request-controlled `target` parameter and multipart file metadata filename. The handler writes upload content to `/userdisk/upload.tmp`, creates the supplied `target` directory, and moves the temporary file to `target .. filename` without constraining the destination to user storage paths.

When the destination is `/etc/hotplug.d/iface/`, the uploaded file is later sourced by `/sbin/hotplug-call` during interface hotplug handling. Because hotplug sources files with `. $script`, executable file mode is not required. This provides an authenticated root command execution chain after a hotplug event is triggered.

## Affected Firmware Tested

- Xiaomi AX3000T rd03, firmware `1.0.64`
- Xiaomi AX3000T rd03v2, firmware `2.0.12`
- Xiaomi BE3600 rn01, firmware `1.0.74`
- Xiaomi BE10000 rp04, firmware `1.0.89`

## Impact

- Vulnerability class: authenticated arbitrary file write leading to root command execution
- Root cause: external control of destination path and filename
- Suggested CWE: CWE-73, CWE-434
- Suggested CVSS v3.1: 7.2 High, `AV:N/AC:L/PR:H/UI:N/S:U/C:H/I:H/A:H`

## Evidence Boundary

This package includes static evidence and qemu-user harness validation against the original firmware Lua bytecode. The harness directly loads and executes the real `xqdatacenter.lua` bytecode from each rootfs, with minimal stubs for LuCI request handling. It then validates the hotplug execution sink using the firmware's own BusyBox shell.

Real device HTTP multipart validation has not yet been performed.

## Package Contents

- `technical_report.md`: vulnerability analysis and impact.
- `poc_reproduction.md`: local reproduction steps.
- `qemu_feasibility_assessment.md`: validation boundary and emulator notes.
- `duplicate_check.md`: public duplicate-risk assessment.
- `cve_submission_draft.md`: CVE submission draft.
- `email_body.txt`: disclosure email draft.
- `evidence_index.md`: evidence file index.
- `evidence/`: hashes, static evidence, and validation logs.
- `poc/`: local qemu-user validation scripts.
