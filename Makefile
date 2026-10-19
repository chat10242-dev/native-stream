NASM = nasm
LD = ld
AARCH64_AS = aarch64-linux-gnu-as
AARCH64_LD = aarch64-linux-gnu-ld

CFLAGS = -f elf64
LDFLAGS = -s -z noexecstack

all: linux gui

linux: main

gui:
	$(MAKE) -C cpp_ui

main: main.o
	$(LD) $(LDFLAGS) -o $@ $^

main.o: main.asm
	$(NASM) $(CFLAGS) -o $@ $<

android: android_main

android_main: android_aarch64.o
	@if command -v $(AARCH64_LD) >/dev/null 2>&1; then \
		$(AARCH64_LD) -s -o $@ $<; \
	else \
		echo "Android target requires aarch64-linux-gnu-* toolchain."; \
		echo "Install binutils-aarch64-linux-gnu and try again."; \
		false; \
	fi

android_aarch64.o: android_aarch64.asm
	@if command -v $(AARCH64_AS) >/dev/null 2>&1; then \
		$(AARCH64_AS) -o $@ $<; \
	else \
		echo "Android target requires aarch64-linux-gnu-as."; \
		false; \
	fi

deb: main gui
	./build_deb.sh

clean:
	rm -f main main.o android_main android_aarch64.o
	$(MAKE) -C cpp_ui clean

.PHONY: all clean linux android gui deb
