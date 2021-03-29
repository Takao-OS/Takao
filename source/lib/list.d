module lib.list;

import memory.alloc;

struct List(T) {
    private T*     storage;
    private size_t size;
    private size_t elementCount;

    @property size_t length() {
        return elementCount;
    }

    this(size_t initialSize) {
        storage      = allocate!T(initialSize);
        size         = initialSize;
        elementCount = 0;
    }

    size_t push(T elem) {
        if (elementCount >= size) {
            grow();
        }
        storage[elementCount] = elem;
        return elementCount++;
    }

    void remove(size_t index) {
        if (index >= elementCount) {
            return;
        }
        for (size_t i = elementCount - 1; i > index; i--) {
            storage[i - 1] = storage[i];
        }
    }
    void pop() {
        if (elementCount != 0) {
            elementCount--;
        }
    }

    ref T opIndex(size_t i) {
        return storage[i];
    }

    void shrinkToFit() {
        resizeAllocationAbs!T(&storage, elementCount);
        size = elementCount;
    }

    private void grow() {
        resizeAllocationAbs!T(&storage, size * 2);
        size *= 2;
    }

    ~this() {
        return;
    }
}
