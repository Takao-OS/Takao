# Takao's project coding guidelines

This is a small document to help with coding style for present and future
code contributions.

Generally the project follows [The D Style](https://dlang.org/dstyle.html) along
with the phobos guidelines, with little variations, which are the following:
- Inline brackets instead of a new line for brackets: `void main() {`.
- `__gshared` over `shared`, since we already have our own locking systems.
- Default constructor calls are prefered over per field struct initialisation.

```d
struct A {
    int a;
    int b;
}

auto a = A(1, 2); // Perfect.
A a; // Gross.
a.a = 1;
a.b = 2; 
```

As an optional measure that we do appreciate, we suggest printing out a copy of
the GNU coding standards, and NOT read it. Burn them, it’s a great symbolic
gesture.
