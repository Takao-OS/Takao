module lib.list;

import lib.alloc;

struct List(T) {
    private T*     storage;
    private size_t size;
    private size_t elementCount;

    @property size_t length() {
        return elementCount;
    }

    this(size_t initialSize) {
        storage      = newArray!T(initialSize);
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

    T opIndex(size_t i) {
        return storage[i];
    }

    void shrinkToFit() {
        resizeArrayAbs!T(&storage, elementCount);
        size = elementCount;
    }

    private void grow() {
        resizeArrayAbs!T(&storage, size * 2);
        size *= 2;
    }

    ~this() {
        delArray(storage);
    }
}
