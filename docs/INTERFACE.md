# Interfaces with the kernel and values

## Command line

The kernel takes on most targets a command line for passing options and values
for the kernel, here they are all documented.

* `init=path`: Full path to run once the kernel is loaded, if any.
* `root=path`: Full path of the kernel resources, by default none.

## Syscall interface

Here are documented the syscall interfaces for all the kernel targets and how
to realize them, they should also be used inside the kernel for internal use.

| Syscall | Number | Kernel function name | File             |
| ------- | -------| -------------------- | ---------------- |
| `open`  | 0      | `open`               | `storage/file.d` |
| `close` | 1      | `close`              | `storage/file.d` |
| `read`  | 2      | `read`               | `storage/file.d` |
| `write` | 3      | `write`              | `storage/file.d` |
