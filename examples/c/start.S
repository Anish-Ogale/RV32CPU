.section .text.start,"ax",@progbits
.globl _start
_start:
    li sp, 1024
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
    lui t0, 0x10000
    sw a0, 0(t0)
    ebreak
3:
    j 3b
