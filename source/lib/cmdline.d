/// Parsing commandline options.
module lib.cmdline;

/// Gets an option from the commandline.
/// Params:
///     cmdline = Commandline to search from, not null.
///     option  = Option to search, not null.
/// Returns: Value of the option or null if not found.
string getCmdlineOption(string cmdline, string option) {
    import lib.string: findString;

    assert(cmdline != null && option != null);

    // Find index of the option.
    const foundIndex = findString(cmdline, option) + option.length + 1;
    if (foundIndex >= cmdline.length) {
        return null;
    }

    return cmdline[foundIndex..findString(cmdline, " ", foundIndex)];
}
