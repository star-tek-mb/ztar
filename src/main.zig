const std = @import("std");
const ztar = @import("ztar.zig");

comptime {
    _ = ztar; // run tests
}

pub fn main() !void {
    var buf_stream = std.io.fixedBufferStream(@embedFile("arch.tar"));
    var tar_reader = ztar.reader(buf_stream.reader());
    var tar_iterator = tar_reader.iterator();
    while (try tar_iterator.next()) |entry| {
        std.log.debug("{s} {} {d}", .{entry.name, entry.@"type", entry.size});
        try tar_iterator.skip();
    }
}
