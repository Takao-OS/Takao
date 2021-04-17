# Some useful constants.
KERNEL    := takao
IMAGE     := takao.hdd
CMAGENTA  := $(shell tput setaf 5)
CRESET    := $(shell tput sgr0)
SOURCEDIR := source
BUILDDIR  := build
TESTDIR   := test

# Compilers, several programs and user flags.
ARCH ?= x86_64_stivale2
DC = ldmd2
AS = clang
LD = ld.lld
DESTDIR ?=
PREFIX  ?= /boot
DFLAGS  ?= -d-debug
ASFLAGS ?=
LDFLAGS ?=

# Hardflags and directories.
ARCHDIR     := $(SOURCEDIR)/arch
SARCHDIR    := $(ARCHDIR)/$(ARCH)
DHARDFLAGS  := $(DFLAGS)  -relocation-model=pic -betterC -version=$(ARCH)
ASHARDFLAGS := $(ASFLAGS) -ffreestanding -fpic
LDHARDFLAGS := $(LDFLAGS) --nostdlib -pie

# Modify flags for the target.
ifeq ($(ARCH), x86_64_stivale2)
DHARDFLAGS  := $(DHARDFLAGS)  -mtriple=x86_64-unknown-elf -mattr=-sse,-sse2 -disable-red-zone
ASHARDFLAGS := $(ASHARDFLAGS) --target=x86_64-unknown-elf
LDHARDFLAGS := $(LDHARDFLAGS) --oformat elf_amd64
endif

# Source to compile.
ARCHDSOURCE   := $(shell find $(SARCHDIR)  -type f -name '*.d')
ARCHASMSOURCE := $(shell find $(SARCHDIR)  -type f -name '*.S')
DSOURCE       := $(shell find $(SOURCEDIR) -type f -name '*.d' -not -path "$(ARCHDIR)/*")
OBJ           := $(ARCHDSOURCE:.d=.o) $(ARCHASMSOURCE:.S=.o) $(DSOURCE:.d=.o)

# Where the fun begins!
.PHONY: all test clean install

all: $(KERNEL)

$(KERNEL): $(OBJ)
	@echo "$(CMAGENTA)$(LD)$(CRESET) $@"
	@$(LD) $(LDHARDFLAGS) $(OBJ) -T $(SARCHDIR)/linker.ld -o $@

%.o: %.d
	@echo "$(CMAGENTA)$(DC)$(CRESET) $@"
	@$(DC) $(DHARDFLAGS) -I=$(SOURCEDIR) -c $< -of=$@

%.o: %.S
	@echo "$(CMAGENTA)$(AS)$(CRESET) $@"
	@$(AS) $(ASHARDFLAGS) -I$(SOURCEDIR) -c $< -o $@

test: $(KERNEL)
	@cd $(TESTDIR) && ./$(ARCH).sh

clean:
	@rm -rf $(OBJ) $(KERNEL)

install: $(KERNEL)
	@install -d "$(DESTDIR)$(PREFIX)"
	@install $(KERNEL) "$(DESTDIR)$(PREFIX)"
