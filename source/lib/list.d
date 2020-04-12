module lib.list;

import lib.alloc;

struct List(T) {
    private T*     storage;
    private size_t size;
    private size_t elementCount;

    this(size_t initialSize) {
        this.storage      = newArray!T(initialSize);
        this.size         = initialSize;
        this.elementCount = 0;
    }

    size_t push(T elem) {
        if (this.elementCount >= size) {
            grow();
        }
        size_t idx = this.elementCount;
        this.storage[this.elementCount++] = elem;
        return idx;
    }

    void pop() {
        if (this.elementCount != 0) {
            this.elementCount--;
        }
    }

    void shrinkToFit() {
        resizeArrayAbs!T(&this.storage, this.elementCount * T.sizeof);
        this.size = this.elementCount;
    }

    ref T opIndex(size_t i) {
        return this.storage[i];
    }

    size_t len() {
        return this.elementCount;
    }

    private void grow() {
        resizeArrayAbs!T(&this.storage, this.size * 2);
        this.size = this.size * 2;
    }

    ~this() {
        delArray(this.storage);
    }
}

