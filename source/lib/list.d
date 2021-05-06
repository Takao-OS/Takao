/// Structure for holding a list of items.
module lib.list;

import memory.alloc: allocate, resizeAllocation, free;

private struct ListItem(T) {
    bool isPresent;
    T    inner;
}

/// List of items, the items in this list will always keep the same
/// location in memory for its items and indexes, and removed indexes
/// will be freed for other items, its kind of a conservative list of sorts.
/// This is better suited for kernel environments where code resiliency is more
/// important than performance in my opinion.
struct List(T) {
    private bool          isInit;
    private ListItem!(T)* storage;
    private size_t        elementCount;

    /// Create the list.
    /// Params:
    ///     initialSize = Size to preallocate.
    this(size_t initialSize) {
        storage      = allocate!(ListItem!T)(initialSize);
        elementCount = initialSize;
        isInit       = true;
    }

    ~this() {
        if (isInit) {
            foreach (i; 0..elementCount) {
                if (storage[i].isPresent) {
                    storage[i].inner.destroy();
                }
            }
            free(storage);
        }
    }

    /// Length of the list in items.
    size_t length() {
        return elementCount;
    }

    /// Count of present items.
    size_t count() {
        size_t ret;
        foreach (i; 0..elementCount) {
            if (storage[i].isPresent) {
                ret += 1;
            }
        }
        return ret;
    }

    /// Add an item to the list, it might be at the end or not.
    size_t push(T elem) {
        foreach (i; 0..elementCount) {
            if (!storage[i].isPresent) {
                storage[i].isPresent = true;
                storage[i].inner     = elem;
                return i; 
            }
        }
        resizeAllocation!(ListItem!T)(&storage, 1);
        storage[elementCount].isPresent = true;
        storage[elementCount].inner     = elem;
        return elementCount++;
    }

    /// Remove an index of the list, if any, trying to remove an item bigger
    /// than the length of the array can cause memory corruption.
    void remove(size_t index) {
        assert(index < elementCount);
        storage[index].isPresent = false;
    }

    /// Swap 2 items without calling either's constructors or destructors.
    void swapIndexes(size_t source, size_t destination) {
        assert(source < elementCount && destination < elementCount);
        import std.algorithm.mutation: swap;
        swap(storage[source], storage[destination]);
    }

    /// Returns whether the passed index holds an item or is an empty index.
    bool isPresent(size_t index) {
        assert(index < elementCount);
        return storage[index].isPresent;
    }

    /// Get an index of the list, if the index is not used, this function will
    /// return bogus data.
    ref T opIndex(size_t index) {
        assert(index < elementCount);
        return storage[index].inner;
    }
}
