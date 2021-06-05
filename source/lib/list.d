/// Structure for holding a list of items.
module lib.list;

import memory.alloc: allocate, resizeAllocationAbs, free;

/// A list.
struct List(T) {
    private T*     storage;
    private size_t elementCount;
    private size_t capacity;

    /// Create the list.
    /// Params:
    ///     initialSize = Size to preallocate.
    this(size_t initialSize) {
        storage      = allocate!(T)(initialSize);
        elementCount = 0;
        capacity     = initialSize;
    }

    ~this() {
        if (storage != null) {
            foreach (i; 0..elementCount) {
                storage[i].destroy();
            }
            free(storage);
        }
    }

    /// Length of the list in items.
    size_t length() {
        return elementCount;
    }

    /// Add an item to the list at the end.
    size_t push(T elem) {
        if (capacity <= elementCount) {
            capacity = capacity * 2 + 1;
            resizeAllocationAbs!(T)(&storage, capacity);
        }
        storage[elementCount] = elem;
        return elementCount++;
    }

    /// Remove an index of the list.
    void remove(size_t index) {
        assert(index < elementCount);
        foreach (i; index + 1..elementCount) {
            storage[i - 1] = storage[i];
        }
        elementCount--;
    }

    /// Swap 2 items without calling either's constructors or destructors.
    void swap(size_t source, size_t destination) {
        assert(source < elementCount && destination < elementCount);
        import std.algorithm.mutation: swap;
        swap(storage[source], storage[destination]);
    }

    /// Get an index of the list, if the index is not used, this function will
    /// return bogus data.
    ref T opIndex(size_t index) {
        assert(index < elementCount);
        return storage[index];
    }
}
