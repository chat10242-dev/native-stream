; NativeStream ASM Android/ARM64 target
; Minimal AArch64 Linux ELF skeleton for host/client executable selection.
; This is intended for Android/ARM64 Linux environments with aarch64-linux-gnu-as.

    .global _start
    .text

_start:
    mov x0, #0
    mov x8, #93
    svc #0

    ; This file intentionally keeps the ARM64 target as a minimal native prototype.
    ; The x86_64 Linux version in main.asm remains the verified production binary.
