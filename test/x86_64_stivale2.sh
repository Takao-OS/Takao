#!/bin/bash

set -e

IMAGE=takao.hdd
KERNEL=../takao
LIMINE_URL="https://github.com/limine-bootloader/limine.git"
LIMINE_DIR="limine"
LIMINE_VERS="v1.0"

rm -f config $IMAGE

cat > config << EOF
TIMEOUT=0
:Takao
KERNEL_PATH=boot:///takao
PROTOCOL=stivale2
KERNEL_CMDLINE=useInit=false
EOF

[ -d $LIMINE_DIR ] || \
    git clone --depth=1 --branch=$LIMINE_VERS $LIMINE_URL $LIMINE_DIR

dd if=/dev/zero bs=1M count=0 seek=64 of=$IMAGE
parted -s $IMAGE mklabel msdos
parted -s $IMAGE mkpart primary 1 100%
echfs-utils -m -p0 $IMAGE quick-format 512
echfs-utils -m -p0 $IMAGE import $KERNEL takao
echfs-utils -m -p0 $IMAGE import config  limine.cfg
make -C $LIMINE_DIR limine-install
$LIMINE_DIR/limine-install $IMAGE

qemu-system-x86_64 -m 1G -smp 4 -debugcon stdio -enable-kvm -cpu host -hda $IMAGE

