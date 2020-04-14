# Some useful constants.
KERNEL    := takao.elf
IMAGE     := takao.hdd
CMAGENTA  := $(shell tput setaf 5)
CRESET    := $(shell tput sgr0)
SOURCEDIR := source
BUILDDIR  := build

# Compilers, several programs and their flags.
DC   = ldc2
AS   = nasm
LD   = ld.lld
QEMU = qemu-system-x86_64

DFLAGS    = -O -g -de
ASFLAGS   = -O2
LDFLAGS   = -gc-sections
QEMUFLAGS = -m 8G -smp 4 -debugcon stdio -enable-kvm -cpu host -no-reboot -no-shutdown -d int

DHARDFLAGS := ${DFLAGS} -mtriple=amd64-unknown-elf -relocation-model=static \
	-code-model=kernel -mattr=-sse,-sse2,-sse3,-ssse3 -disable-red-zone     \
	-betterC -op
ASHARDFLAGS   := ${ASFLAGS} -felf64
LDHARDFLAGS   := ${LDFLAGS} --oformat elf_amd64 --nostdlib
QEMUHARDFLAGS := ${QEMUFLAGS}

# Source to compile.
DSOURCE   := $(shell find ${SOURCEDIR} -type f -name '*.d')
ASMSOURCE := $(shell find ${SOURCEDIR} -type f -name '*.asm')
OBJ       := $(DSOURCE:.d=.o) $(ASMSOURCE:.asm=.o)

# Where the fun begins!
.PHONY: all hdd test clean distclean

all: ${KERNEL}

${KERNEL}: ${OBJ}
	@echo "${CMAGENTA}${LD}${CRESET} '$@'"
	@${LD} ${LDHARDFLAGS} ${OBJ} -T ${BUILDDIR}/linker.ld -o $@

%.o: %.d
	@echo "${CMAGENTA}${DC}${CRESET} '$@'"
	@${DC} ${DHARDFLAGS} -I=${SOURCEDIR} -c $< -of=$@

%.o: %.asm
	@echo "${CMAGENTA}${AS}${CRESET} '$@'"
	@${AS} ${ASHARDFLAGS} -I${SOURCEDIR} $< -o $@

hdd: ${IMAGE}

${IMAGE}: qloader2 ${KERNEL}
	@dd if=/dev/zero bs=1M count=0 seek=64 of=${IMAGE}
	@parted -s ${IMAGE} mklabel msdos
	@parted -s ${IMAGE} mkpart primary 1 100%
	@echfs-utils -m -p0 ${IMAGE} quick-format 32768
	@echfs-utils -m -p0 ${IMAGE} import ${KERNEL} ${KERNEL}
	@echfs-utils -m -p0 ${IMAGE} import ${BUILDDIR}/qloader2.cfg qloader2.cfg
	@qloader2/qloader2-install qloader2/qloader2.bin ${IMAGE}

qloader2:
	@git clone https://github.com/qword-os/qloader2.git

test: hdd
	@${QEMU} ${QEMUHARDFLAGS} -hda ${IMAGE}

clean:
	@rm -rf ${OBJ} ${KERNEL} ${IMAGE}

distclean: clean
	@rm -rf qloader2
