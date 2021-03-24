/// Driver for echfs filesystems.
module storage.echfs;

import storage.driver: PartitionInfo, FSType;
import memory.alloc:   allocate, free;
import storage.driver: readDrive, writeDrive;
import lib.string:     fromCString;
import lib.math:       divRoundUp;
debug import lib.debugtools: warn, log;

private struct ECHFSIdentityTable {
    align(1):
    ubyte[4] jmp;
    char[8]  signature;
    ulong    blockCount;
    ulong    dirLength;
    ulong    blockSize;
    uint     reserved;
    ulong    guid;
}

private struct ECHFSDirEntry {
    align(1):
    ulong     parentID;
    ubyte     type;
    char[201] name;
    ulong     atime;
    ulong     mtime;
    ushort    perms;
    ushort    owner;
    ushort    group;
    ulong     ctime;
    ulong     payload;
    ulong     size;
}

/// Information to be maintained for echfs.
struct ECHFSInfo {
    ECHFSIdentityTable idTable;          /// Table of identification.
    ulong              allocTableSize;   /// Size of the allocation table in bytes.
    ulong              allocTableOffset; /// Byte offset of the allocation table in disk.
    ulong              mainDirOffset;    /// Byte offset of the main directory in disk.
}

private immutable echfsRootDir    = ~(cast(ulong)0);     // Directory ID of the root dir.
private immutable echfsEndOfDir   = 0;        // Directory ID of end of dir.
private immutable echfsDeletedDir = ~0LU - 1; // Directory ID of a free block.

private immutable echfsEndOfChain = ~0LU; // End of chain in the allocation table.

private immutable echfsFileType = 0; // Type of a directory entry which is a file.
private immutable echfsDirType  = 1; // Ditto but dir.

/// Probe echfs, and if found, return a partition info allocated with `newObj`.
ECHFSInfo* probeECHFS(PartitionInfo* part) {
    assert(part != null);

    // Read block 0, which is the identity table.
    ECHFSIdentityTable table;
    if (!readDrive(part.containingDrive, &table, part.driveOffset, table.sizeof)) {
        debug warn("echfs: Could not read drive in probing.");
        return null;
    }

    // Check the signature.
    if (fromCString(table.signature.ptr, table.signature.length) != "_ECH_FS_") {
        debug log("echfs: Not an echfs drive");
        return null;
    }

    // Fill out info.
    auto ret             = allocate!ECHFSInfo;
    ret.idTable          = table;
    ret.allocTableSize   = divRoundUp(table.blockCount * ulong.sizeof, table.blockSize) * table.blockSize;
    ret.allocTableOffset = part.driveOffset + (16 * table.blockSize);
    ret.mainDirOffset    = ret.allocTableOffset + ret.allocTableSize;
    debug log("echfs: Found FS of ", table.blockCount, " blocks (", table.blockSize, " bytes)");
    return ret;
}

/// Read file from disk in a memory allocated array using `allocate`.
/// Params:
///     part       = Partition containing the filesystem.
///     path       = Path of the file inside the partition.
///     file       = Array allocated with `allocate` holding the read file.
///     fileLength = Length of the read data.
/// Returns: true if success, false in failure.
bool echfsReadFile(PartitionInfo* part, string path, out ubyte* file, out size_t fileLength) {
    import lib.string: fromCString;

    assert(part != null && part.fsType == FSType.ECHFS);

    auto drive         = part.containingDrive;
    const auto fsInfo  = cast(ECHFSInfo*)part.fsInfo;
    const auto blkSize = fsInfo.idTable.blockSize;

    ECHFSDirEntry dirEntry;
    if (!searchEntry(part, path, dirEntry)) {
        debug warn("echfs: File '", path, "' not found");
        return false;
    }

    // Get the list of blocks the file uses.
    auto fileBlockCount = divRoundUp(dirEntry.size, blkSize);
    auto fileBlockList  = allocate!(ulong)(fileBlockCount);

    fileBlockList[0] = dirEntry.payload;
    foreach (i; 1..fileBlockCount) {
        const auto index = fsInfo.allocTableOffset + fileBlockList[i - 1] * ulong.sizeof;
        if (!readDrive(drive, &fileBlockList[i], index, ulong.sizeof)) {
            debug warn("echfs: Could not read allocation list for ", path);
            free(fileBlockList);
            return false;
        }
    }

    // Copy on file and return.
    auto ret      = allocate!(ubyte)(dirEntry.size);
    auto blk      = allocate!(ubyte)(blkSize);
    auto retIndex = 0;
    foreach (i; 0..fileBlockCount) {
        auto offset = (fileBlockList[i] * blkSize) + part.driveOffset;

        if (!readDrive(drive, blk, offset, blkSize)) {
            debug warn("echfs: Could not read final file at offset ", offset);
            // FIXME: If I dont put this 4 prints, in this order, for some reason, this
            // call to readDrive will fail.
            // please someone from ldc explain this.
            debug log("A:",drive);
            debug log("A:",blk);
            debug log("A:",offset);
            debug log("A:",blkSize);
            free(ret);
            free(blk);
            free(fileBlockList);
            return false;
        }

        for (size_t j = 0; retIndex != dirEntry.size && j < blkSize; j++) {
            ret[retIndex++] = blk[j];
        }
    }

    free(blk);
    free(fileBlockList);
    file       = ret;
    fileLength = dirEntry.size;
    return true;
}

/// Write file to disk, overwritting exitent ones or creating a new one.
/// Params:
///     part       = Partition containing the filesystem.
///     path       = Path of the file inside the partition to write or create and write.
///     file       = File contents to write.
///     fileLength = Length of the data to write.
/// Returns: true if success, false in failure.
bool echfsWriteFile(PartitionInfo* part, string path, ubyte* file, size_t fileLength) {
    assert(part != null && part.fsType == FSType.ECHFS);
    return false;
}

// Searches for an entry, returns true and the entry if found, false if not found.
private bool searchEntry(PartitionInfo* part, string path, out ECHFSDirEntry entry) {
    assert(part != null);

    char* searchPath     = cast(char*)path;
    auto  fsInfo         = cast(ECHFSInfo*)part.fsInfo;
    auto  drive          = part.containingDrive;
    ulong wantedParent   = echfsRootDir;
    bool  isLastElement  = false;
    const auto dirLength = fsInfo.idTable.dirLength * fsInfo.idTable.blockSize;

next:
    char[128] wantedName;
    while (*searchPath == '/') { searchPath++; }
    for (int i = 0; ; i++, searchPath++) {
        if (*searchPath == '\0' || *searchPath == '/' || i >= path.length) {
            if (*searchPath == '\0') {
                isLastElement = true;
            }
            wantedName[i] = '\0';
            searchPath++;
            break;
        }
        wantedName[i] = *searchPath;
    }

    ECHFSDirEntry dirEntry;
    for (ulong i = 0; i < dirLength; i += ECHFSDirEntry.sizeof) {
        if (!readDrive(drive, &dirEntry, i + fsInfo.mainDirOffset, ECHFSDirEntry.sizeof)) {
            debug warn("echfs: Failed to read entry");
            return false;
        }

        if (dirEntry.parentID == echfsEndOfDir) {
            break;
        }

        if (fromCString(wantedName.ptr) == fromCString(dirEntry.name.ptr) &&
            dirEntry.parentID == wantedParent && dirEntry.type == (isLastElement ? echfsFileType : echfsDirType)) {
            if (isLastElement) {
                goto found;
            } else {
                wantedParent = dirEntry.payload;
                goto next;
            }
        }
    }

    return false;
found:
    entry = dirEntry;
    return true;
}
