# Takao

![forthebadge](https://forthebadge.com/images/badges/contains-cat-gifs.svg)

A kernel, written in D with tons of love and cat pics.

## Building the source code

Make sure you have installed:

* `ldc`, a LLVM based D compiler.
* `lld`, the LLVM project linker.
* `nasm`.
* `make`.

To build the kernel, it is enough with a simple `make`, add flags as needed, for
a release build its recommended to do `make DFLAGS="-release -O"`, for debug
builds, `make DFLAGS="-d-debug"`
To test, run `make test`.
