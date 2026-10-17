ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K }
SECTIONS {
  . = ORIGIN(RAM);
  .text : { KEEP(*(.text.init)) *(.text .text.*) *(.rodata .rodata.*) } > RAM
  .data : { *(.data .data.*) } > RAM
  .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) } > RAM
  . = ALIGN(16);
  __stack_top = ORIGIN(RAM) + LENGTH(RAM) - 16;
}
