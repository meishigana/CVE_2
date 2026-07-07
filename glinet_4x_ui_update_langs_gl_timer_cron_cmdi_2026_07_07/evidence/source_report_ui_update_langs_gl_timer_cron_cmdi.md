# GL.iNet ui.update_langs gl_timer cron command injection

## Summary

Authenticated JSON-RPC access to `ui.update_langs` can persist attacker-controlled newline and tab characters into `gl_timer.langs.week`. `/etc/init.d/gl_timer` later writes this value into the root crontab without field validation, allowing injection of an additional cron entry and command execution as root.

This is a different method and sink from the previously packaged `plugins.install_package` command injection.

## Affected targets observed

- `GL-MT6000` firmware `4.9.0`: static source-to-sink confirmed; QEMU/rootfs cron-generation proof confirmed.
- `GL-MT3000` firmware `4.8.1`: same `ui.update_langs` strings and `gl_timer` sink observed statically.
- `GL-X3000` firmware `4.8.3`: same `ui.update_langs` strings and `gl_timer` sink observed statically.

`GL-AR300M16` firmware `4.3.27` has the `gl_timer` sink, but the reviewed `ui` RPC does not expose `update_langs`; this target is not currently claimed for this finding.

## RPC validator evidence

`usr/share/gl-validator.d/ui.lua` only defines method-specific validation for `init`; no `update_langs` rule exists.

`usr/lib/lua/oui/rpc.lua` falls back to this default pattern for unvalidated strings:

```lua
vt = vt or '^[%w%.%s%-_:#/]-$'
```

The default permits whitespace, including newline and tab, plus digits, letters, `-`, `_`, `:`, `#`, and `/`. A cron-injection payload can be built entirely from those characters:

```text
1\n0-59\t0-23\t1-31\t1-12\t0-6\ttouch\t/tmp/glinet_ui_timer_pwn\t#
```

## Source-to-sink

`usr/lib/oui-httpd/rpc/ui` method `update_langs` stores caller-controlled scheduling fields:

```text
gl_timer.langs.enable = 1
gl_timer.langs.hour   = args.hour
gl_timer.langs.min    = args.min
gl_timer.langs.week   = table.concat(args.week, " ")
```

It then commits configuration and restarts `/etc/init.d/gl_timer`.

`/etc/init.d/gl_timer` builds the `langs` cron entry as:

```sh
local week=`uci -q get gl_timer.$1.week | sed 's/ /,/g'`
echo "$min $hour * * $week gl_timer_control_langs 1 $week $hour $min" >> /tmp/gl_crontabs/crontabs.d/langs
```

The sanitizer only converts ASCII spaces to commas. It does not remove newlines or tabs. A newline in `week` starts a second cron line, and tab characters remain valid cron/shell separators.

## Dynamic evidence

Probe script:

```text
analysis/GL.iNet/scratch/probe_ui_update_langs_timer.sh
```

Captured output:

```text
analysis/GL.iNet/scratch/probe_ui_update_langs_timer_output.txt
```

The probe uses the firmware `uci` binary under QEMU to persist the malicious `week` value, reproduces the vulnerable `gl_timer` cron generation, and executes the injected cron command line as cron would. The final marker is:

```text
MARKER_CREATED=/tmp/glinet_ui_timer_pwn
```

## Status

This is a high-value candidate for a new CVE submission. Remaining work before packaging:

- Run a full `/rpc` or `/cgi-bin/glc` harness request for `ui.update_langs` if practical.
- Preserve the current QEMU/rootfs cron evidence and add static excerpts for the validator, `ui.update_langs`, and `/etc/init.d/gl_timer`.
- Re-run public duplicate search immediately before submission.
