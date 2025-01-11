; For main BIOS -- set the migration script loader to target 0xF9000
STUB_LOADER_SEGMENT equ 0xF7

; For main BIOS, set V40 timings to most conservative
WAIT_STATE_CONFIG equ 0x00

; For migration script, set the loader to begin copying from 0xF9100
MIGRATION_SEGMENT equ 0xF710
