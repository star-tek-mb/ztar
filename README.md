# Overview

**ztar** - is a small library for reading tar files.

# Features

* Lightweight
* One file
* Non allocating
* Simple API

# Usage

Just copy **ztar.zig** to your project libraries/sources folder and you are ready to go.

# Example

```zig
const std = @import("std");
const ztar = @import("ztar.zig");

pub fn main() !void {
    var buf_stream = std.io.fixedBufferStream(@embedFile("arch.tar"));
    var tar_reader = ztar.reader(buf_stream.reader());
    var tar_iterator = tar_reader.iterator();
    while (try tar_iterator.next()) |entry| {
        std.log.debug("{s} {} {d}", .{entry.name, entry.@"type", entry.size});
        // read file here for example
        // tar_reader.readAll(buffer[0..entry.blockSize()]);
        // or skip it
        try tar_iterator.skip();
    }
}
```
