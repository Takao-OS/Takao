# Takao

![forthebadge](https://forthebadge.com/images/badges/contains-cat-gifs.svg)

A kernel, written in D with tons of love and cat pics.

## Building the source code

Make sure you have installed:

* `git`.
* `ldc`, a LLVM based D compiler.
* `lld`, the LLVM project linker.
* `clang`.
* `make`.

With all of that covered, just clone the source with `git` if you don't
have it already with:

```bash
git clone https://github.com/Takao-OS/Takao.git
cd Takao
```

To build the kernel, it is enough with a simple `make`, add flags as needed.
To test, run `make test`.
