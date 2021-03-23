# Takao

![forthebadge](https://forthebadge.com/images/badges/contains-cat-gifs.svg)

A kernel, written in D with tons of love and cat pics.

## Building the source code

Make sure you have installed:

* `ldc`, a LLVM based D compiler.
* `lld`, the LLVM project linker.
* `nasm`.
* `make`.

To build the kernel, it is enough with a simple `make`, add flags as needed.

For a release build it's recommended to do `make DFLAGS="-release -O"`, this will
ensure the best performance at the expense of compilation time, extra checks, and
debug info.

For a debug build, do `make DFLAGS="-d-debug"`, this will enable the fastest
compilation times, debug messages, and extra checks by the kernel, at the expense
of performance and binary size.

To test in a qemu VM, run `make test`.
