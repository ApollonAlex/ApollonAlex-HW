# Default: bare-metal GNU RISC-V toolchain. Override CC/OBJCOPY if needed.
CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
CFLAGS = -march=rv32i -mabi=ilp32 -O2 -ffreestanding -fno-builtin -nostdlib
LDFLAGS = -Wl,-T,link.ld -Wl,--no-relax

all: firmware.hex

firmware.elf: start.S main.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) start.S main.c -o $@

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware.hex: firmware.bin bin_to_hex.py
	python3 bin_to_hex.py firmware.bin firmware.hex

clean:
	rm -f firmware.elf firmware.bin firmware.hex
