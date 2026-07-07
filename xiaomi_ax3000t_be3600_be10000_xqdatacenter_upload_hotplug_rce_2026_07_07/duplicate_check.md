# Duplicate Check

## Search Keywords

- `"xqdatacenter" "upload.tmp"`
- `"/api/xqdatacenter/upload"`
- `"luci.controller.api.xqdatacenter"`
- `"Xiaomi" "xqdatacenter" "upload" "vulnerability"`
- `"Xiaomi router" "arbitrary file write" CVE`
- `"Xiaomi router" "hotplug" "CVE"`

## Findings

Public materials were found for Xiaomi router post-authentication command injection vulnerabilities involving `xqdatacenter/request`, especially CVE-2023-26315 and CVE-2024-45348. Those reports are centered on command injection through the datacenter request/backend handling path.

Relevant public references:

- NVD CVE-2023-26315: https://nvd.nist.gov/vuln/detail/CVE-2023-26315
- CVE record CVE-2023-26315: https://www.cve.org/CVERecord?id=CVE-2023-26315
- Xiaomi advisory listing for CVE-2023-26315: https://trust.mi.com/misrc/bulletins/advisory?cveId=546
- NVD CVE-2024-45348: https://nvd.nist.gov/vuln/detail/CVE-2024-45348
- Xiaomi security bulletins: https://trust.mi.com/misrc/bulletins
- Example public analysis of `xqdatacenter/request`: https://www.iotsec-zone.com/article/495

## Difference From Known Issues

This candidate is not based on `/api/xqdatacenter/request` or datacenter backend command injection. It is based on `/api/xqdatacenter/upload`, where `target` and multipart filename control the destination path of an uploaded file.

The exploit primitive is arbitrary file write. The RCE chain uses OpenWrt hotplug script sourcing under `/etc/hotplug.d/iface/`.

No public report was found that documents the exact `/api/xqdatacenter/upload -> target-controlled arbitrary file write -> hotplug sourced RCE` chain.

## Assessment

Duplicate risk is lower than the previously excluded NFC quote-injection issue. There is still adjacent prior art in Xiaomi router authenticated RCE research, so the final submission should emphasize:

- Different endpoint: `/api/xqdatacenter/upload`, not `/api/xqdatacenter/request`.
- Different primitive: arbitrary file write, not command injection.
- Different sink: hotplug script source execution.
- Different affected models/firmware in this package.
