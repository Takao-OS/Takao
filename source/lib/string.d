/// Functions to go from D to C strings, and functions to build strings, mix
/// them, and viceversa.
module lib.string;

private size_t cstrlen(const char* s) {
    assert(s != null);
    size_t len;
    for (len = 0; s[len] != '\0'; len++) {}
    return len;
}

/// Go from C 0-terminated string to D string.
/// Params:
///     str = String to convert.
/// Returns: D string or null if passed null.
string fromCString(const char* str) {
    return str ? cast(string)str[0..cstrlen(str)] : null;
}

/// Go from C length delimited string to D string.
/// Params:
///     str = String to convert.
///     len = Length of the string.
/// Returns: D string or null if passed null.
string fromCString(const char* str, size_t len) {
    return str ? cast(string)str[0..len] : null;
}

/// Find the index of the first occurence of a string inside another.
/// Params:
///     haystack = String to search in.
///     needle  = String to search.
///     start   = Index to start searching from.
/// Returns: Found index, or the length of haystack if failed.
size_t findString(string haystack, string needle, size_t start = 0) {
    assert(haystack != null && needle != null);

    if (needle.length == 0 || start >= haystack.length) {
        return haystack.length;
    }

    size_t i = start;
    while (i < haystack.length) {
        if (haystack[i] == needle[0]) {
            int j = 0;
            for (; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    break;
                }
            }
            if (j == needle.length) {
                return i;
            }
        }
        i++;
    }
    return i;
}

/// Transform a string into an integer.
/// Params:
///     str = String to convert to integer.
/// Return: Integer representation of the string, no error checking is provided.
// TODO: Support non decimal integers.
size_t intFromString(string str) {
    assert(str != null);

    size_t ret = 0;
    foreach (i; 0..str.length) {
        ret = ret * 10 + str[i] - '0';
    }
    return ret;
}

/// Builds a string and allocates it using the arguments.
/// Params:
///     args = Arguments to use to construct the string.
/// Returns: A D string allocated with `allocate`, never `null`.
string buildString(T...)(T args) {
    import memory.alloc: allocate;
    import lib.panic:    panic;

    auto result = allocate!char(64); // TODO: Make varlength.
    if (result == null) {
        panic("buildString got null");
    }

    auto length = buildStringInPlace(result, 64, args);
    return fromCString(result, length);
}

/// Builds a string in the passed array using the arguments.
///     result = A non null pointer to write the string to.
///     args   = Arguments to use to construct the string.
/// Returns: The total characters written to the result.
size_t buildStringInPlace(T...)(char* result, size_t limit, T args) {
    assert(result != null);

    size_t currIndex = 0;
    foreach (item; args) {
        currIndex += addItem(result, item, currIndex, limit);
        if (currIndex >= limit) {
            break;
        }
    }

    return currIndex;
}

private size_t addItem(char* result, bool item, size_t index, size_t limit) {
    return addItem(result, item ? "true" : "false", index, limit);
}

private size_t addItem(char* result, char item, size_t index, size_t limit) {
    if (index + 1 < limit) {
        result[index] = item;
        return 1;
    }

    return 0;
}

private size_t addItem(char* result, void* ptr, size_t index, size_t limit) {
    assert(result != null);

    immutable conversionTable = "0123456789abcdef";
    auto item = cast(ulong)ptr;
    if (item == 0 && index < limit) {
        result[index] = '0';
        return 1;
    } else if (index + 16 < limit) {
        char[16] buff;
        int i = 0;
        int written = 0;
        for (i = 15; item; i--) {
            buff[i] = conversionTable[item % 16];
            item /= 16;
            written++;
        }
        foreach (j; 0..written) {
            result[index + j] = buff[buff.length - written + j];
        }
        return written;
    } else {
        return 0;
    }
}

private size_t addItem(char* result, ulong item, size_t index, size_t limit) {
    assert(result != null);

    immutable conversionTable = "0123456789";
    if (item == 0 && index < limit) {
        result[index] = '0';
        return 1;
    } else if (index + 20 < limit) {
        char[20] buff;
        int i = 0;
        int written = 0;
        for (i = 19; item; i--) {
            buff[i] = conversionTable[item % 10];
            item /= 10;
            written++;
        }
        foreach (j; 0..written) {
            result[index + j] = buff[buff.length - written + j];
        }
        return written;
    } else {
        return 0;
    }
}

private size_t addItem(char* result, string item, size_t index, size_t limit) {
    assert(result != null);

    if (item == null) {
        return addItem(result, "null", index, limit);
    } else {
        size_t ret;
        foreach (c; item) {
            const a = addItem(result, c, index++, limit);
            if (a == 0) {
                break;
            } else {
                ret += a;
            }
        }
        return ret;
    }
}
