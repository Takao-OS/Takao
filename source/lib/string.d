module lib.string;

private size_t cstrlen(const char* s) {
    size_t len;
    for (len = 0; s[len] != '\0'; len++) {}
    return len;
}

string fromCString(const char* str) {
    return str ? cast(string)str[0..cstrlen(str)] : "";
}

string fromCString(const char* str, size_t len) {
    return str ? cast(string)str[0..len] : "";
}
