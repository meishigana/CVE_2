# Evidence Index

- `evidence/firmware_hashes.txt`: SHA256 hashes of the four analyzed firmware images.
- `evidence/xqdatacenter_controller_hashes.txt`: SHA256 hashes of the affected controller bytecode files.
- `evidence/static_route_and_upload_sinks.txt`: decompiled route and upload sink evidence.
- `evidence/bytecode_upload_dataflow.txt`: bytecode-level upload dataflow evidence.
- `evidence/hotplug_call_source_behavior.txt`: affected firmware `/sbin/hotplug-call` source behavior.
- `evidence/verify_xqdatacenter_upload_bytecode_output.txt`: qemu-user validation output.
- `poc/verify_xiaomi_xqdatacenter_upload_hotplug_rce_2026_07_07.sh`: primary bytecode harness.
- `poc/verify_xiaomi_hotplug_sink_2026_07_07.sh`: smaller hotplug sink validation helper.
