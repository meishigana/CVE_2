# Duplicate Check

Date: 2026-07-07

## Result

Public duplicate risk is currently assessed as low to medium. The reviewed public records did not identify the specific `ui.update_langs` -> `gl_timer.langs.week` -> root crontab injection chain.

Public references reviewed:

- NVD CVE-2025-2851 for `plugins.so` buffer overflow: `https://nvd.nist.gov/vuln/detail/CVE-2025-2851`
- OpenCVE GL.iNet vendor listing: `https://app.opencve.io/cve/?vendor=gl-inet`
- GL.iNet security updates page: `https://www.gl-inet.com/en-us/blogs/security-updates`
- GL.iNet public CVE issue repository examples: `https://github.com/gl-inet/CVE-issues`
- Public GL.iNet package-name command-injection writeups, including CVE-2023-46454 discussions

## Search Terms Used

Representative searches:

```text
GL.iNet ui.update_langs gl_timer command injection CVE
GL.iNet gl_timer update_langs cron command injection
GL.iNet gl_timer_control_langs vulnerability
NVD GL.iNet gl_timer command injection CVE
```

## Non-Duplicate Assessment

### CVE-2025-67089 / plugins.install_package family

This submission is not the previously found `plugins.install_package` issue. The root cause, RPC method, and sink differ:

```text
plugins.install_package -> opkg preflight shell command
ui.update_langs       -> gl_timer root crontab generation
```

### CVE-2025-2851 / plugins.so buffer overflow

NVD describes CVE-2025-2851 as a buffer overflow in `plugins.so`. This submission is an input-validation and cron command-injection issue in `ui.update_langs` and `/etc/init.d/gl_timer`, so it is not a duplicate.

### Older GL.iNet command-injection CVEs

Several public GL.iNet records describe command injection in other components, including package-name handling, network tools, OpenVPN import workflows, minidlna, NAS, and LuCI JSON-RPC handlers. None of the reviewed public summaries identified `ui.update_langs`, `gl_timer.langs.week`, or `gl_timer_control_langs` as the vulnerable path.

## Caveat

GL.iNet has broad advisory pages that sometimes group multiple authenticated command-injection vulnerabilities without public method-level detail. A vendor/CNA could still merge this into an internal umbrella issue. Based on public information available during this review, the specific chain appears distinct and suitable for a new CVE request.
