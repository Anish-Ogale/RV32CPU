ENTRY(_start)
MEMORY {
    IMEM (rx) : ORIGIN = 0, LENGTH = 1024
    DMEM (rw) : ORIGIN = 0, LENGTH = 1024
}
SECTIONS {
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
        . = ALIGN(4);
    } > IMEM
    .unsupported : {
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.* .sdata .sdata.*)
        *(.got .got.*)
    } > IMEM
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM
    /DISCARD/ : { *(.comment .note* .eh_frame*) }
}
ASSERT(SIZEOF(.unsupported) == 0,
       "UART loads code only: avoid string literals, constant tables and initialized global/static data")
ASSERT(__bss_end <= 512, "Reserve at least 512 bytes for the stack")
