module lib.bit;

extern (C) int bt(size_t* bitmap, size_t index) {
    asm {
        naked;

        xor EAX, EAX;
        bt [RDI], ESI;
        setc AL;

        ret;
    }
}

extern (C) int btInt(uint var, size_t index) {
    asm {
        naked;

        xor EAX, EAX;
        bt EDI, ESI;
        setc AL;

        ret;
    }
}


extern (C) int bts(size_t* bitmap, size_t index) {
    asm {
        naked;

        xor EAX, EAX;
        bts [RDI], ESI;
        setc AL;

        ret;
    }
}

extern (C) int btr(size_t* bitmap, size_t index) {
    asm {
        naked;

        xor EAX, EAX;
        btr [RDI], ESI;
        setc AL;

        ret;
    }
}
