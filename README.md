# Takao

![Banner](banner.png)

A kernel, written in D with tons of love and cat pics.

You can follow the development and meet the team at
[the official discord server](https://discord.gg/uTughVXwbd) (We have more seal
pictures).

## Building the source code

Make sure you have installed:

* `ldc`, a LLVM based D compiler.
* `lld`, the LLVM project linker.
* `nasm`.
* `make`.

To build the kernel, it is enough with a simple `make`, add flags as needed.
To test, run `make test`.

An example for a release build some appropiate flags would be
`make DFLAGS='-O -release -inline'`, while the default flags are suited for
debug/development builds, architecture target can also be chosen with the
`ARCH` variable.

## Projects and documents used as reference and help

* [qword-os](https://github.com/qword-os/qword).
* [The stivale specifications](https://github.com/stivale/stivale).
