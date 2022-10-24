const std = @import("std");

pub const EntryType = enum(u8) { File = '0', Hardlink = '1', Symlink = '2', Character = '3', Block = '4', Directory = '5', Pipe = '6', Longfile = 'L', Longlink = 'K' };

pub const Entry = struct {
    mode: u16,
    owner: u16,
    group: u16,
    size: u32,
    mtime: i64,
    @"type": EntryType,
    name: [100]u8,
    linkname: [100]u8,

    pub fn blockSize(self: Entry) u32 {
        return self.size + (512 - self.size % 512) % 512;
    }
};

const RawHeader = extern struct {
    name: [100]u8,
    mode: [8]u8,
    owner: [8]u8,
    group: [8]u8,
    size: [12]u8,
    mtime: [12]u8,
    checksum: [8]u8,
    @"type": u8,
    linkname: [100]u8,
    format: [6]u8,
    version: [2]u8,
    owner_name: [32]u8,
    group_name: [32]u8,
    device_major: [8]u8,
    device_minor: [8]u8,
    prefix: [155]u8,
    _padding: [12]u8,

    fn getField(self: *RawHeader, comptime field: []const u8) []const u8 {
        var bytes = @field(self, field);
        return bytes[0 .. std.mem.indexOfScalar(u8, bytes[0..], 0) orelse bytes.len];
    }

    fn getChecksum(self: *RawHeader) u32 {
        var bytes = std.mem.asBytes(self);
        var checksum: u32 = 256;
        for (bytes) |byte, i| {
            if (i < @offsetOf(RawHeader, "checksum") or i >= @offsetOf(RawHeader, "type")) {
                checksum += byte;
            }
        }
        return checksum;
    }

    pub fn toEntry(self: *RawHeader) Entry {
        return .{
            .mode = std.fmt.parseInt(u16, self.getField("mode"), 8) catch 0,
            .owner = std.fmt.parseInt(u16, self.getField("owner"), 8) catch 0,
            .group = std.fmt.parseInt(u16, self.getField("group"), 8) catch 0,
            .size = std.fmt.parseInt(u32, self.getField("size"), 8) catch 0,
            .mtime = std.fmt.parseInt(i64, self.getField("mtime"), 8) catch 0,
            .@"type" = std.meta.intToEnum(EntryType, self.@"type") catch EntryType.File,
            .name = self.name,
            .linkname = self.linkname,
        };
    }
};

pub fn reader(r: anytype) Reader(@TypeOf(r)) {
    return .{ .reader = r };
}

pub fn Reader(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        reader: ReaderType,

        pub const Iterator = struct {
            const Self = @This();

            reader: ReaderType,
            last_entry: Entry = undefined,

            pub fn next(self: *Iterator) !?Entry {
                var raw = self.reader.readStruct(RawHeader) catch |err| switch (err) {
                    error.EndOfStream => return null,
                    else => return err,
                };

                var checksum = std.fmt.parseInt(u32, raw.getField("checksum"), 8) catch |err| switch (err) {
                    error.InvalidCharacter => return null,
                    else => return err,
                };
                if (raw.getChecksum() != checksum) {
                    return error.BadChecksum;
                }
                self.last_entry = raw.toEntry();
                return self.last_entry;
            }

            pub fn skip(self: *Iterator) !void {
                return self.reader.skipBytes(self.last_entry.blockSize(), .{});
            }
        };

        pub fn iterator(self: Self) Iterator {
            return .{ .reader = self.reader };
        }
    };
}

test "tar header size" {
    try std.testing.expectEqual(512, @sizeOf(RawHeader));
}

test "tar header to entry" {
    var buf_stream = std.io.fixedBufferStream(@embedFile("arch.tar"));
    var raw_header = try buf_stream.reader().readStruct(RawHeader);
    var entry = raw_header.toEntry();

    try std.testing.expectStringStartsWith(&entry.name, "testtesttesttesttesttesttesttesttest/");
    try std.testing.expectEqual(entry.mode, 0o755);
    try std.testing.expectEqual(entry.owner, 1000);
    try std.testing.expectEqual(entry.group, 1000);
    try std.testing.expectEqual(entry.size, 0);
    try std.testing.expectEqual(entry.mtime, 1666611719);
    try std.testing.expectEqual(raw_header.getChecksum(), 8664);
    try std.testing.expectEqual(entry.@"type", EntryType.Directory);
}

test "tar iterator" {
    var buf_stream = std.io.fixedBufferStream(@embedFile("arch.tar"));
    var tar_reader = reader(buf_stream.reader());
    var tar_iterator = tar_reader.iterator();
    while (try tar_iterator.next()) |_| {
        try tar_iterator.skip();
    }
}
