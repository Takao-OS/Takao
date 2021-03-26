# Some useful constants.
KERNEL    := takao
IMAGE     := takao.hdd
CMAGENTA  := $(shell tput setaf 5)
CRESET    := $(shell tput sgr0)
SOURCEDIR := source
BUILDDIR  := build
TESTDIR   := test

# Compilers, several programs and user flags.
ARCH    = x86_64_stivale2
DC      = ldmd2
AS      = nasm
LD      = ld.lld
DESTDIR =
PREFIX  = /boot
DFLAGS  = -d-debug
ASFLAGS =
LDFLAGS =

# Hardflags and directories.
ARCHDIR     := $(SOURCEDIR)/arch
SARCHDIR    := $(ARCHDIR)/$(ARCH)
DHARDFLAGS  := $(DFLAGS)  -relocation-model=pic -betterC -op -version=$(ARCH)
ASHARDFLAGS := $(ASFLAGS) -felf64
LDHARDFLAGS := $(LDFLAGS) --nostdlib -pie

# Modify flags for the target.
ifeq ($(ARCH), x86_64_stivale2)
DHARDFLAGS := $(DHARDFLAGS) -mtriple=amd64-unknown-elf -code-model=kernel \
	-mattr=-sse,-sse2,-sse3,-ssse3 -disable-red-zone
ASHARDFLAGS := $(ASHARDFLAGS) -felf64
LDHARDFLAGS := $(LDHARDFLAGS) --oformat elf_amd64
endif

# Source to compile.
ARCHDSOURCE   := $(shell find $(SARCHDIR)  -type f -name '*.d')
ARCHASMSOURCE := $(shell find $(SARCHDIR)  -type f -name '*.asm')
DSOURCE       := $(shell find $(SOURCEDIR) -type f -name '*.d' -not -path "$(ARCHDIR)/*")
OBJ           := $(ARCHDSOURCE:.d=.o) $(ARCHASMSOURCE:.asm=.o) $(DSOURCE:.d=.o)

# Where the fun begins!
.PHONY: all test clean install

all: $(KERNEL)

$(KERNEL): $(OBJ)
	@echo "$(CMAGENTA)$(LD)$(CRESET) $@"
	@$(LD) $(LDHARDFLAGS) $(OBJ) -T $(SARCHDIR)/linker.ld -o $@

%.o: %.d
	@echo "$(CMAGENTA)$(DC)$(CRESET) $@"
	@$(DC) $(DHARDFLAGS) -I=$(SOURCEDIR) -c $< -of=$@

%.o: %.asm
	@echo "$(CMAGENTA)$(AS)$(CRESET) $@"
	@$(AS) $(ASHARDFLAGS) -I$(SOURCEDIR) $< -o $@

test: $(KERNEL)
	@cd $(TESTDIR) && ./$(ARCH).sh

clean:
	@rm -rf $(OBJ) $(KERNEL)

install: $(KERNEL)
	@install -d "$(DESTDIR)$(PREFIX)"
	@install $(KERNEL) "$(DESTDIR)$(PREFIX)"
