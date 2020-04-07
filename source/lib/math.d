module lib.math;

ulong divRoundUp(ulong a, ulong b) {
    return (a + (b - 1)) / b;
}
