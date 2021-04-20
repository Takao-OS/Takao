/// File abstration over the main storage driver.
module storage.file;

import storage.driver: PartitionInfo, FSType, StorageDriver;
import main:           mainStorage;
import memory.alloc:   allocate, free, resizeAllocation;
debug import lib.debugtools: log, warn;

/// Posible permissions to open a file with.
enum FileMode {
    Read,      /// Read, opens file at beggining or fails.
    Write,     /// Write, opens file at beggining or creates.
    ReadWrite, /// Read and write, opens file at the beggining or creates.
    Append     /// Append only, opens file at end or creates.
}

alias FileDescriptor = int; /// File descriptor datatype.

// Information of the file.
private struct File {
    bool           isInUse;      // Whether the file is in use or vacant.
    PartitionInfo* partition;    // Partition containing the file.
    string         path;         // Path of the file inside the partition.
    FileMode       mode;         // Mode of the file.
    size_t         currLocation; // Current location in bytes.
    ubyte*         fileData;     // Data of the file, allocated with `newArray`.
    size_t         fileLength;   // Length in bytes of the allocated data.
}

private __gshared size_t fileCount;
private __gshared File*  files; // The index of the file is the file descriptor.

/// Open a file and return its file descriptor.
/// Params:
///     path = Absolute path to open the file.
///     mode = Mode to open the file with.
/// Returns: The file descriptor, or `-1` if failed. 
FileDescriptor open(string path, FileMode mode) {
    import lib.string:    intFromString, findString;
    import storage.echfs: echfsReadFile;

    assert(path != null);

    if (files == null) {
        fileCount = 0;
        files     = allocate!(File)(0);
    }

    // Resolve the path.
    auto driveEnd     = findString(path, ":");
    auto partitionEnd = findString(path, ":", driveEnd + 1);
    if (driveEnd == path.length || partitionEnd == path.length) {
        debug warn("file: Requested path is not absolute");
        return -1;
    }

    auto drivePath      = path[0..driveEnd];
    auto partitionIndex = intFromString(path[(driveEnd + 1)..partitionEnd]);
    auto filePath       = path[(partitionEnd + 1)..path.length];
    auto partition      = mainStorage.findPartition(drivePath, partitionIndex);
    if (partition == null) {
        debug warn("file: Requested partition does not really exist");
        return -1;
    }

    // Read the file with the according driver.
    ubyte* fileData;
    size_t fileLength;
    final switch (partition.fsType) {
        case FSType.ECHFS:
            if (!echfsReadFile(partition, filePath, fileData, fileLength)) {
                debug warn("file: Could not read echfs file");
                return -1;
            }
            break;
        case FSType.None:
            debug warn("file: Raw FSes dont support the concept of files");
            return -1;
    }

    // Build file and add.
    File file;
    file.isInUse    = true;
    file.partition  = partition;
    file.path       = filePath;
    file.mode       = mode;
    file.fileData   = fileData;
    file.fileLength = fileLength;
    final switch (file.mode) {
        case FileMode.Read:      file.currLocation = 0;          break;
        case FileMode.Write:     file.currLocation = 0;          break;
        case FileMode.ReadWrite: file.currLocation = 0;          break;
        case FileMode.Append:    file.currLocation = fileLength; break;
    }

    foreach (i; 0..fileCount) {
        if (!files[i].isInUse) {
            files[i] = file;
            return cast(int)i;
        }
    }

    resizeAllocation(&files, +1);
    files[fileCount] = file;
    return cast(int)fileCount++;
}

/// Close an open file descriptor.
/// Params:
///     fd = File descriptor to close.
/// Returns: Closed fd or `-1` if failed.
FileDescriptor close(FileDescriptor fd) {
    import storage.echfs: echfsWriteFile;

    assert(fd != -1);

    if (fd < 0 || fd > fileCount - 1) {
        return -1;
    }

    // Write data.
    auto f = &files[fd];
    final switch (f.partition.fsType) {
        case FSType.ECHFS:
            if (!echfsWriteFile(f.partition, f.path, f.fileData, f.fileLength)) {
                debug warn("file: Could not write file while closing");
                return -1;
            }
            break;
        case FSType.None:
            debug warn("file: No, there are no raw disk files");
            return -1;
    }

    // Delete files.
    free(files[fd].fileData);
    files[fd].isInUse = false;
    return fd;
}

/// Read data from a file, all file permissions can read.
/// Params:
///     fd     = File descriptor to read.
///     output = Where to write.
///     count  = Count of bytes to read.
/// Returns: Bytes that could be count, or `-1` if failed.
ptrdiff_t read(FileDescriptor fd, ubyte* output, size_t count) {
    assert(fd != -1);

    if (fd < 0 || fd > fileCount - 1) {
        return -1;
    }

    size_t i;
    for (i = 0; i < count; i++) {
        if (files[fd].currLocation >= files[fd].fileLength) {
            break;
        }
        output[i] = files[fd].fileData[files[fd].currLocation++];
    }
    return i;
}

/// Length of the file in bytes.
/// Params:
///     fd = File to get length of.
/// Returns: -1 if error, length else.
size_t length(FileDescriptor fd) {
    assert(fd != -1);

    if (fd < 0 || fd > fileCount - 1) {
        return -1;
    }

    return files[fd].fileLength;
}

/// Write data to a file, only write and append permissions can write.
/// Params:
///     fd    = File descriptor to write to.
///     data  = Data to write.
///     count = Count of bytes to write.
/// Returns: Bytes that were written, or `-1` if failed.
ptrdiff_t write(FileDescriptor fd, ubyte* data, size_t count) {
    assert(fd != -1);

    if (fd < 0 || fd > fileCount - 1) {
        return -1;
    }

    if (files[fd].currLocation + count >= files[fd].fileLength) {
        resizeAllocation(&files[fd].fileData, files[fd].currLocation + count - files[fd].fileLength);
    }

    foreach (i; 0..count) {
        files[fd].fileData[files[fd].currLocation++] = data[i];
    }

    return count;
}
