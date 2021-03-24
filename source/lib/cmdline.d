/// Parsing commandline options.
module lib.cmdline;

/// Options come in the following format:
/// "option1=value1 option2=value2"

/// Gets an option from the commandline.
/// Params:
///     cmdline = Commandline to search from, not null.
///     option  = Option to search, not null.
/// Returns: Value of the option or null if not found.
string getCmdlineOption(string cmdline, string option) {
    import lib.string: findString;

    assert(cmdline != null && option != null);

    // Find index of the option.
    auto foundIndex = findString(cmdline, option);
    foundIndex += option.length + 1;
    if (foundIndex >= cmdline.length) {
        return null;
    }

    const auto endOfOption = findString(cmdline, " ", foundIndex);
    return cmdline[foundIndex..endOfOption];
}
