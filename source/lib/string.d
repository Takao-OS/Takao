/// Utilities for building, managing, and translating strings.
module lib.string;

private size_t cstrlen(const char* s) {
    size_t len;
    for (len = 0; s[len] != '\0'; len++) {}
    return len;
}

/// Transform a C-style string into a D string.
/// Params:
///     str = C-style string to convert.
/// Returns: A D string or null, if the passed string is null.
string fromCString(const char* str) {
    return str ? cast(string)str[0..cstrlen(str)] : null;
}

/// Transform a C-style string into a D string.
/// Params:
///     str = C-style string to convert.
///     len = Length to use for the C string.
/// Returns: A D string or null, if the passed string is null.
string fromCString(const char* str, size_t len) {
    return str ? cast(string)str[0..len] : null;
}

/// Builds a string and allocates it using the arguments.
/// Params:
///     args = Arguments to use to construct the string.
/// Returns: A D string allocated with `newArray`, never `null`.
string buildString(T...)(T args) {
    import lib.alloc: newArray;
    import lib.panic: panic;

    auto result = newArray!char(64); // TODO: Make varlength.
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
        const auto advance = addItem(result, item, currIndex, limit);
        currIndex += advance;
        if (currIndex >= limit) {
            break;
        }
    }

    return currIndex;
}

private size_t addItem(char* result, char item, size_t index, size_t limit) {
    if (index + 1 < limit) {
        result[index] = item;
        return 1;
    }

    return 0;
}

private size_t addItem(char* result, ubyte item, size_t index, size_t limit) {
    return addItem(result, cast(ulong)item, index, limit);
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

    if (item == null && index + 4 < limit) {
        result[index]     = 'n';
        result[index + 1] = 'u';
        result[index + 2] = 'l';
        result[index + 3] = 'l';
        return 4;
    } else if (index + item.length < limit) {
        foreach (i; 0..item.length) {
            result[index + i] = item[i];
        }
        return item.length;
    } else {
        return 0;
    }
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
