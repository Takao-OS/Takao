/// Driver for ATA devices.
module storage.ata;

import lib.lock:                 Lock;
import memory.alloc:             allocate, free;
import arch.x86_64_stivale2.cpu: outb, outw, inb, inw;

/// Struct to represent an ATA drive once initialized.
struct ATADrive {
    Lock        lock;            /// Drive lock.
    bool        isMaster;        /// Whether the drive is master or not.
    ushort[256] identify;        /// Identify information.
    ushort      dataPort;        /// Data port.
    ushort      errorPort;       /// Error port.
    ushort      sectorCountPort; /// Sector count port.
    ushort      lbaLowPort;      /// LBA low port.
    ushort      lbaMidPort;      /// LBA mid port.
    ushort      lbaHiPort;       /// LBA high port.
    ushort      devicePort;      /// Device port.
    ushort      commandPort;     /// Command port.
    ushort      controlPort;     /// Control port.

    ulong  sectorCount;     /// Sector count.
    ushort bytesPerSector;  /// Bytes per sector.
}

private immutable ushort[] ataPorts = [0x1f0, 0x170];

private __gshared size_t probeCurrentIndex;

/// Probes and returns a found drive, or `null` if not found.
ATADrive* probeAndAdd() {
    ATADrive* drive = null;
    foreach (i; probeCurrentIndex..ataPorts.length * 2) {
        drive = initDrive(probeCurrentIndex++);
        if (drive != null) {
            break;
        }
    }
    return drive;
}

private ATADrive* initDrive(size_t index) {
    debug import lib.debugtools: log, warn;

    auto dev  = allocate!ATADrive;
    auto port = cast(ushort)ataPorts[index / 2]; 
    dev.dataPort        = port;
    dev.errorPort       = cast(ushort)(port + 0x1);
    dev.sectorCountPort = cast(ushort)(port + 0x2);
    dev.lbaLowPort      = cast(ushort)(port + 0x3);
    dev.lbaMidPort      = cast(ushort)(port + 0x4);
    dev.lbaHiPort       = cast(ushort)(port + 0x5);
    dev.devicePort      = cast(ushort)(port + 0x6);
    dev.commandPort     = cast(ushort)(port + 0x7);
    dev.controlPort     = cast(ushort)(port + 0x206);
    dev.isMaster        = !(index % 2);
    dev.bytesPerSector  = 512;

    // Identify the drive.
    outb(dev.devicePort, dev.isMaster ? 0xa0 : 0xb0);
    outb(dev.sectorCountPort, 0);
    outb(dev.lbaLowPort, 0);
    outb(dev.lbaMidPort, 0);
    outb(dev.lbaHiPort, 0);
    outb(dev.commandPort, 0xec); // Identify.
    if (!inb(dev.commandPort)) {
        free(dev);
        debug warn("ata: Drive is dead");
        return null;
    }

    int timeout = 0;
    while (inb(dev.commandPort) & 0b10000000) {
        if (timeout++ == 100_000 - 1) {
            debug warn("ata: Drive timed out, skipped!");
            free(dev);
            return null;
        }
    }

    // Check for non standard ATAPI.
    if (inb(dev.lbaMidPort) || inb(dev.lbaHiPort)) {
        debug warn("ata: Ignoring non standard ATAPI");
        free(dev);
        return null;
    }

    // Check for results.
    foreach (i; 0..100_000) {
        const auto status = inb(dev.commandPort);
        if (status & 0b00000001) {
            debug warn("ata: Error/Timeout occurred");
            free(dev);
            return null;
        }
        if (status & 0b00001000) {
            goto success;
        }
    }
    debug warn("ata: Error/Timeout occurred");
    free(dev);
    return null;
success:
    debug log("ata: Identified ATA drive");
    foreach (i; 0..dev.identify.length) {
        dev.identify[i] = inw(dev.dataPort);
    }
    dev.sectorCount = *(cast(ulong*)(&dev.identify[100]));
    debug log("ata: ATA drive sector count: ", dev.sectorCount);
    dev.lock.release();
    return dev;
}

private int ataRead(ATADrive* disk, ulong sector, ubyte* buffer) {
    debug import lib.debugtools: warn;

    outb(disk.devicePort, disk.isMaster ? 0x40 : 0x50);
    outb(disk.sectorCountPort, 0);   // sector count high byte
    outb(disk.lbaLowPort, cast(ubyte)((sector & 0x000000FF000000) >> 24));
    outb(disk.lbaMidPort, cast(ubyte)((sector & 0x0000FF00000000) >> 32));
    outb(disk.lbaHiPort, cast(ubyte)((sector & 0x00FF0000000000) >> 40));
    outb(disk.sectorCountPort, 1);   // sector count low byte
    outb(disk.lbaLowPort, cast(ubyte)(sector & 0x000000000000FF));
    outb(disk.lbaMidPort, cast(ubyte)((sector & 0x0000000000FF00) >> 8));
    outb(disk.lbaHiPort, cast(ubyte)((sector & 0x00000000FF0000) >> 16));    
    outb(disk.commandPort, 0x24); // read command

    ubyte status = inb(disk.commandPort);
    while (((status & 0x80) == 0x80)
        && ((status & 0x01) != 0x01)) 
        status = inb(disk.commandPort);

    if (status & 0x01) {
        debug warn("ATA: Error reading sector ", sector, " on drive ", disk);
        return -1;
    }

    for (int i = 0; i < 256; i++) {
        const ushort wdata = inw(disk.dataPort);
        int c = i * 2;
        buffer[c] = wdata & 0xFF;
        buffer[c + 1] = (wdata >> 8) & 0xFF;
    }
    
    return 0;
}

private int ataWrite(ATADrive* disk, ulong sector, ubyte* buffer) {
    debug import lib.debugtools: warn;

    outb(disk.devicePort, disk.isMaster ? 0x40 : 0x50);
    outb(disk.sectorCountPort, 0);   // sector count high byte
    outb(disk.lbaLowPort, cast(ubyte)((sector & 0x000000FF000000) >> 24));
    outb(disk.lbaMidPort, cast(ubyte)((sector & 0x0000FF00000000) >> 32));
    outb(disk.lbaHiPort, cast(ubyte)((sector & 0x00FF0000000000) >> 40));
    outb(disk.sectorCountPort, 1);   // sector count low byte
    outb(disk.lbaLowPort, cast(ubyte)(sector & 0x000000000000FF));
    outb(disk.lbaMidPort, cast(ubyte)((sector & 0x0000000000FF00) >> 8));
    outb(disk.lbaHiPort, cast(ubyte)((sector & 0x00000000FF0000) >> 16));
    outb(disk.commandPort, 0x34); // EXT write command

    ubyte status = inb(disk.commandPort);
    while (((status & 0x80) == 0x80)
        && ((status & 0x01) != 0x01)) 
        status = inb(disk.commandPort);

    if (status & 0x01) {
        debug warn("ATA: Error writting sector ", sector, " on drive ", disk);
        return -1;
    }

    for (int i = 0; i < 256; i ++) {
        const int c = i * 2;
        const ushort wdata = (buffer[c + 1] << 8) | buffer[c];
        outw(disk.dataPort, wdata);
    }
    
    ataFlush(disk);
    return 0;
}

private void ataFlush(ATADrive* disk) {
    debug import lib.debugtools: warn;

    outb(disk.devicePort, disk.isMaster ? 0x40 : 0x50);
    outb(disk.commandPort, 0xEA); // cache flush EXT command

    ubyte status = inb(disk.commandPort);

    while (((status & 0x80) == 0x80)
        && ((status & 0x01) != 0x01)) 
        status = inb(disk.commandPort);
    
    if (status & 0x01) {
        debug warn("ATA: Error occured while flushing cache.");
    }
}

/// Reads a 4kbyte data block from a drive.
/// Params:
///     drive  = Drive to read from.
///     output = Output of the read.
///     offset = Offset to start reading from.
/// Returns: true in success or false in failure.
bool read4k(ATADrive* drive, void* output, size_t offset) {
    drive.lock.acquire();

    const auto sectorOffset = offset * 8;
    auto ret = cast(ubyte*)output;

    static foreach (i; 0..8) {
        if (ataRead(drive, sectorOffset + i, ret + (i * 512)) == -1) {
            return false;
        }
    }

    drive.lock.release();
    return true;
}

/// Write a 4k data block to a drive.
/// Params:
///     drive  = Drive to read from.
///     data   = Data to write.
///     offset = Offset to start writting to.
/// Returns: true in success or false in failure.
bool write4k(ATADrive* drive, void* data, size_t offset) {
    drive.lock.acquire();

    const auto sectorOffset = offset * 8;
    auto ret = cast(ubyte*)data;

    static foreach (i; 0..8) {
        if (ataWrite(drive, sectorOffset + i, ret + (i * 512)) == -1) {
            return false;
        }
    }

    drive.lock.release();
    return true;
}
