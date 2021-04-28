/// Main utilities for interfacing with the storage subsystem.
module storage.driver;

import lib.list:       List;
import kernelprotocol: KernelDevice;

/// The storage subsystem is accessed requesting access and opening paths.
/// The system storage architecture is based on a list of devices, like windows.

/// Types of drive.
enum DriveType {
    ATA
}

/// Types of fs.
enum FSType {
    ECHFS,
    None
}

/// Data to identify a mount.
struct DriveMount {
    string    name;      /// Name of the drive.
    DriveType type;      /// Type of the drive.
    void*     driveData; /// Driver-specific data.
}

/// Data to identify a partition.
struct PartitionInfo {
    size_t      partitionIndex;  /// Index of the partition.
    size_t      driveOffset;     /// Raw offset on the drive.
    DriveMount* containingDrive; /// Drive which contains the partition.
    FSType      fsType;          /// Type of FS.
    void*       fsInfo;          /// Information used internally by the FS.
}

// Structure to cache drive contents.
private struct BlockCache {
    DriveMount* drive;  // Drive that owns the cache.
    size_t      offset; // Offset of the cache block.
    ubyte[4096] cache;  // Actual cached data.
}

/// Main storage driver.
struct StorageDriver {
    static:
    private __gshared List!DriveMount    driveMounts;  // Mounted and identified drives.
    private __gshared List!PartitionInfo partitions;   // Partitions identified and in use.
    private __gshared List!BlockCache    cachedBlocks; // Cached blocks from drives.

    /// Initialize the driver with devices.
    void initialize(const KernelDevice[] devs) {
        import storage.ata: ataProbeAndAdd  = probeAndAdd, ATADrive;
        import lib.string:  buildString;
        debug import lib.debugtools: log;

        void addDrive(DriveMount dr) {
            auto i = driveMounts.push(dr);
            auto p = scanPartitions(&driveMounts[i]);
            foreach (j; 0..p.length) {
                partitions.push(p[j]);
            }
            debug log("storage: Added drive ", (&driveMounts[i]).name);
        }

        cachedBlocks = List!(BlockCache)(30);
        driveMounts  = List!(DriveMount)(3);
        partitions   = List!(PartitionInfo)(6);

        // Probe ATA drives.
        ATADrive* atadrive;
        auto driveIndex = 0;
        while ((atadrive = ataProbeAndAdd()) != null) {
            DriveMount dr;
            dr.name      = buildString("ata", driveIndex);
            dr.type      = DriveType.ATA;
            dr.driveData = atadrive;
            addDrive(dr);
            driveIndex++;
        }
    }

    /// Retrive the drive mount info of a drive, if any.
    /// Params:
    ///     name = Name of the drive.
    /// Returns: Pointer to drive mount, or `null` if not found.
    DriveMount* findDrive(string name) {
        foreach (i; 0..driveMounts.length) {
            auto item = &driveMounts[i];
            if (item.name == name) {
                return item;
            }
        }

        return null;
    }

    /// Retrive the information of a partition, if any.
    /// Params:
    ///     name  = Name of the drive.
    ///     index = Index of the partition in the drive.
    /// Returns: Pointer to partition info, or `null` if not found.
    PartitionInfo* findPartition(string name, size_t index) {
        const auto drive = findDrive(name);
        if (drive == null) {
            return null;
        }

        foreach (i; 0..partitions.length) {
            auto item = &partitions[i];
            if (item.containingDrive == drive && item.partitionIndex == index) {
                return item;
            }
        }

        return null;
    }

    private ubyte* readDrive4K(DriveMount* drive, size_t offset) {
        import storage.ata: ATADrive, atRead = read4k;

        assert(drive != null);

        // Check cache.
        foreach (i; 0..cachedBlocks.length) {
            auto item = &cachedBlocks[i];
            if (item.drive == drive && item.offset == offset) {
                return item.cache.ptr;
            }
        }

        // Request a block, cache it, and return it.
        BlockCache c;
        c.drive  = drive;
        c.offset = offset;
        final switch (drive.type) {
            case DriveType.ATA:
                if (!atRead(cast(ATADrive*)drive.driveData, c.cache.ptr, offset)) {
                    return null;
                }
                break;
        }

        // Add block to cache.
        foreach (i; 0..cachedBlocks.length) {
            auto item = &cachedBlocks[i];
            if (item.drive == null) {
                item.drive  = c.drive;
                item.offset = c.offset;
                item.cache  = c.cache;
                return item.cache.ptr;
            }
        }

        const auto i = cachedBlocks.push(c);
        return cachedBlocks[i].cache.ptr;
    }

    private bool writeDrive4K(DriveMount* drive, void* data, size_t offset) {
        import storage.ata: ATADrive, atWrite = write4k;

        assert(drive  != null);
        assert(data != null);

        // Flush dirty cache from the same drive.
        for (size_t i = 0; i < cachedBlocks.length; i++) {
            auto item = &cachedBlocks[i]; //cachedBlocks.pointerToIndex(i);
            if (item.drive == drive && item.offset == offset) {
                item.drive = null;
                break;
            }
        }

        // Actually write.
        final switch (drive.type) {
            case DriveType.ATA:
                return atWrite(cast(ATADrive*)drive.driveData, data, offset);
        }
    }

    /// Read raw data from a mounted drive.
    /// Params:
    ///     drive  = Drive to read.
    ///     output = Where to write.
    ///     offset = Offset to read from.
    ///     count  = Count of bytes to read.
    /// Returns: true if success, false if failure.
    bool readDrive(DriveMount* drive, void* output, size_t offset, size_t count) {
        assert(drive  != null);
        assert(output != null);

        const size_t finalOffset      = offset + count;
        const size_t blockOffset      = offset / 4096;
        const size_t blockFinalOffset = finalOffset / 4096;
        if (blockOffset == blockFinalOffset) {
            // 1 Block read, we just fetch it, copy it, and done.
            auto ret = readDrive4K(drive, blockOffset);
            ret     += offset % 4096;
            foreach (i; 0..count) {
                (cast(ubyte*)output)[i] = ret[i];
            }
            return true;
        } else {
            // TODO: We dont support more than 1 block reads so far.
            return false;
        }
    }

    /// Write raw data to a mounted drive.
    /// Params:
    ///     drive  = Drive to write to.
    ///     data   = Data to write.
    ///     offset = Offset to read from.
    ///     count  = Count of bytes to write.
    /// Returns: true if success, false if failure.
    bool writeDrive(DriveMount* drive, void* data, size_t offset, size_t count) {
        assert(drive != null);
        assert(data  != null);

        const size_t finalOffset      = offset + count;
        const size_t blockOffset      = offset / 4096;
        const size_t blockFinalOffset = finalOffset / 4096;
        if (blockOffset == blockFinalOffset) {
            // 1 Block write, we just do so.
            ubyte[4096] ret;
            foreach (i; 0..count) {
                ret[i] = (cast(ubyte*)data)[i];
            }
            return writeDrive4K(drive, ret.ptr, blockOffset);
        } else {
            // TODO: We dont support writes of more than 1 block at this point.
            return false;
        }
    }

    private List!(PartitionInfo) scanPartitions(DriveMount* mount) {
        import storage.echfs: probeECHFS;
        debug import lib.debugtools: warn;

        struct MBREntry {
            align(1):
            ubyte    status;
            ubyte[3] chsFirstSector;
            ubyte    type;
            ubyte[3] chsLastSector;
            uint     firstSector;
            uint     sectorCount;
        }

        // TODO: Lol support GPT.
        // Cover yourself in oil.

        auto ret = List!(PartitionInfo)(1);
        ubyte[2] hint = [0, 0];
        ubyte[2] def  = [0, 0]; // @suppress(dscanner.suspicious.unmodified)
        ubyte[2] mbSig = [0, 0]; // @suppress(dscanner.suspicious.unmodified)
        readDrive(mount, hint.ptr, 444, hint.length);
        if (hint != def && hint != mbSig) {
            debug warn("storage: MBR hint not found in drive");
            return ret;
        }

        size_t index = 0; // @suppress(dscanner.suspicious.unmodified)
        MBREntry[4] entries;
        readDrive(mount, entries.ptr, 446, entries.sizeof);
        foreach (i; 0..entries.length) {
            if (!entries[i].type) {
                continue;
            }

            PartitionInfo part;
            part.partitionIndex  = index++;
            part.driveOffset     = entries[i].firstSector * 512;
            part.containingDrive = mount;
            part.fsType          = FSType.None;
            part.fsInfo          = null;
            auto a = probeECHFS(&part); // @suppress(dscanner.suspicious.unmodified)
            if (a != null) {
                part.fsType = FSType.ECHFS;
                part.fsInfo = a;
            }
            ret.push(part);
        }

        return ret;
    }
}
