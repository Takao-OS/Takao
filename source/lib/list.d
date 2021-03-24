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

struct List2(T) {
    private T*     storage;
    private size_t size;
    private size_t elementCount;

    @property size_t length() {
        return elementCount;
    }

    this(size_t initialSize) {
    import lib.panic;
        storage      = allocate2!T(initialSize);
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
