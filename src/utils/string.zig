const std = @import("std");

pub const String = struct {
    buffer: ?[]u8,
    size: usize,
    allocator: std.mem.Allocator,

    pub const StringError = error{ OutOfMemory, OutOfRange };

    pub fn init(allocator: std.mem.Allocator) String {
        return .{
            .buffer = null,
            .size = 0,
            .allocator = allocator,
        };
    }

    pub fn initDefaultString(allocator: std.mem.Allocator, buffer: []const u8) !String {
        var string = init(allocator);

        try string.concat(buffer);

        return string;
    }

    pub fn initDefaultCharacter(allocator: std.mem.Allocator, buffer: u8) !String {
        var string = init(allocator);

        try string.allocate(1);
        var tmp: [1]u8 = undefined;

        std.mem.writeInt(u8, tmp[0..1], buffer, .little);

        try string.insert(&tmp, 0);

        return string;
    }

    pub fn allocate(self: *String, bytes: usize) StringError!void {
        if (self.buffer) |buffer| {
            if (bytes < self.size)
                self.size = bytes;

            self.buffer = self.allocator.realloc(buffer, bytes) catch {
                return StringError.OutOfMemory;
            };
        } else {
            self.buffer = self.allocator.alloc(u8, bytes) catch {
                return StringError.OutOfMemory;
            };
        }
    }

    pub fn deinit(self: *String) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }

    pub fn len(self: String) usize {
        if (self.buffer) |buffer| {
            var length: usize = 0;
            var i: usize = 0;

            while (i < self.size) {
                i += String.getUTF8Size(buffer[i]);
                length += 1;
            }

            return length;
        }

        return 0;
    }

    pub fn insert(self: *String, str: []const u8, index: usize) StringError!void {
        if (self.buffer) |buffer| {
            if (self.size + str.len > buffer.len) {
                try self.allocate((self.size + str.len));
            }
        } else {
            try self.allocate(str.len);
        }

        const buffer = self.buffer.?;

        if (index == self.len()) {
            var i: usize = 0;
            while (i < str.len) : (i += 1) {
                buffer[self.size + i] = str[i];
            }
        } else {
            var i: usize = buffer.len - 1;

            while (i >= index) : (i -= 1) {
                if (i + str.len < buffer.len) {
                    buffer[i + str.len] = buffer[i];
                }

                if (i == 0)
                    break;
            }

            i = 0;

            while (i < str.len) : (i += 1) {
                buffer[index + i] = str[i];
            }
        }

        self.size += str.len;
    }

    pub fn concat(self: *String, char: []const u8) !void {
        try self.insert(char, self.len());
    }

    pub fn concatCharacter(self: *String, char: u8) !void {
        var tmp: [1]u8 = undefined;

        std.mem.writeInt(u8, tmp[0..1], char, .little);

        try self.insert(&tmp, self.len());
    }

    pub fn toString(self: String) []const u8 {
        if (self.buffer) |buffer| return buffer[0..self.size];

        return "";
    }

    pub fn compare(self: String, other: String) bool {
        if (self.buffer == null and other.buffer == null) return true;

        if (self.buffer != null and other.buffer != null)
            return std.mem.eql(u8, self.buffer.?, other.buffer.?);

        return false;
    }

    pub fn clear(self: *String) !void {
        if (self.buffer) |buffer| {
            for (buffer) |*ch| ch.* = 0;
            self.size = 0;
        }
    }

    pub fn toLowerCase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                buffer[i] = std.ascii.toLower(buffer[i]);

                i += 1;
            }
        }
    }

    pub fn toUpperCase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                buffer[i] = std.ascii.toUpper(buffer[i]);

                i += 1;
            }
        }
    }

    pub fn findIndex(self: *String, char: []const u8) ?usize {
        if (self.buffer) |buffer| {
            const index = std.mem.indexOf(u8, buffer[0..self.size], char);

            if (index) |i| return i;
        }

        return null;
    }

    pub fn findLastIndex(self: *String, char: []const u8) ?usize {
        if (self.buffer) |buffer| {
            const index = std.mem.lastIndexOf(u8, buffer[0..self.size], char);

            if (index) |i| return i;
        }

        return null;
    }

    pub fn replaceAll(self: *String, search_str: []const u8, replace_str: []const u8) !void {
        if (self.buffer) |buffer| {
            const isExist = self.findIndex(search_str);

            if (isExist != null) {
                _ = std.mem.replace(u8, buffer, search_str, replace_str, buffer[0..]);

                if (replace_str.len != search_str.len) {
                    var new_size: usize = 0;

                    if (search_str.len > replace_str.len) {
                        new_size = self.size - (search_str.len - replace_str.len);
                    } else {
                        new_size = self.size + (replace_str.len - search_str.len);
                    }

                    try self.allocate(new_size);
                }
            }
        }
    }

    pub fn split(self: *String, delimiter: []const u8) !?std.ArrayList(String) {
        if (self.buffer) |buffer| {
            var array = std.ArrayList(String).init(self.allocator);

            var it = std.mem.splitSequence(u8, buffer, delimiter);

            while (it.next()) |str| {
                const string_from_str = try String.initDefaultString(self.allocator, str);

                try array.append(string_from_str);
            }

            return array;
        }

        return null;
    }

    pub fn clone(self: *String) !String {
        const string = try String.initDefaultString(self.allocator, self.toString());

        return string;
    }

    inline fn getUTF8Size(character: u8) u3 {
        return std.unicode.utf8ByteSequenceLength(character) catch {
            return 1;
        };
    }
};

test "String: clone" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    var string2 = try string.clone();
    defer string2.deinit();

    try std.testing.expectEqual(string.len(), 4);
    try std.testing.expectEqual(string2.len(), 4);
    try std.testing.expect(std.mem.eql(u8, string2.toString(), "test"));
    try std.testing.expect(std.mem.eql(u8, string2.toString(), string.toString()));
}

test "String: initDefaultCharacter" {
    var string = try String.initDefaultCharacter(std.testing.allocator, 't');
    defer string.deinit();

    try std.testing.expectEqual(string.len(), 1);
    try std.testing.expect(std.mem.eql(u8, string.toString(), "t"));
}

test "String: initDefaultString" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    var string2 = try String.initDefaultString(std.testing.allocator, "test,test2,test3");
    defer string2.deinit();

    try std.testing.expectEqual(string.len(), 4);
    try std.testing.expectEqual(string.buffer.?.len, string.len());
    try std.testing.expect(std.mem.eql(u8, string.toString(), "test"));

    try std.testing.expectEqual(string2.len(), 16);
    try std.testing.expectEqual(string2.buffer.?.len, string2.len());
    try std.testing.expect(std.mem.eql(u8, string2.toString(), "test,test2,test3"));
}

test "String: insert and concat" {
    var string = String.init(std.testing.allocator);
    defer string.deinit();

    try string.insert("test", 0);

    try std.testing.expectEqual(string.len(), 4);
    try std.testing.expect(std.mem.eql(u8, string.toString(), "test"));

    try string.concat("🚀tata");

    try std.testing.expectEqual(string.len(), 9);
    try std.testing.expect(std.mem.eql(u8, string.toString(), "test🚀tata"));
}

test "String: concatWithCharacter" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    try string.concatCharacter('t');

    try std.testing.expectEqual(string.len(), 5);
    try std.testing.expect(std.mem.eql(u8, string.toString(), "testt"));
}

test "String: compare" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    var string2 = try String.initDefaultString(std.testing.allocator, "test");
    defer string2.deinit();

    var string3 = try String.initDefaultString(std.testing.allocator, "tata");
    defer string3.deinit();

    try std.testing.expectEqual(string.compare(string2), true);
    try std.testing.expectEqual(string.compare(string3), false);

    var string_null = String.init(std.testing.allocator);
    defer string_null.deinit();

    var string_null_2 = String.init(std.testing.allocator);
    defer string_null_2.deinit();

    try std.testing.expectEqual(string_null.compare(string_null_2), true);
}

test "String: clear" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    try string.clear();

    try std.testing.expectEqual(string.len(), 0);

    try string.concat("tata");

    try std.testing.expectEqual(string.len(), 4);
    try std.testing.expect(std.mem.eql(u8, string.toString(), "tata"));
}

test "String: toLowerCase" {
    var string = try String.initDefaultString(std.testing.allocator, "TEST");
    defer string.deinit();

    string.toLowerCase();

    try std.testing.expect(std.mem.eql(u8, string.toString(), "test"));
}

test "String: toUpperCase" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    string.toUpperCase();

    try std.testing.expect(std.mem.eql(u8, string.toString(), "TEST"));
}

test "String: findIndex" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    try std.testing.expectEqual(string.findIndex("t").?, 0);
    try std.testing.expectEqual(string.findIndex("e").?, 1);
    try std.testing.expectEqual(string.findIndex("s").?, 2);

    try std.testing.expectEqual(string.findIndex("te").?, 0);
    try std.testing.expectEqual(string.findIndex("es").?, 1);

    try std.testing.expectEqual(string.findIndex("a"), null);
}

test "String: findLastIndex" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    try std.testing.expectEqual(string.findLastIndex("t").?, 3);
    try std.testing.expectEqual(string.findLastIndex("e").?, 1);
    try std.testing.expectEqual(string.findLastIndex("s").?, 2);

    try std.testing.expectEqual(string.findIndex("st").?, 2);
    try std.testing.expectEqual(string.findIndex("te").?, 0);

    try std.testing.expectEqual(string.findLastIndex("a"), null);
}

test "String: replaceAll" {
    var string = try String.initDefaultString(std.testing.allocator, "test");
    defer string.deinit();

    try string.replaceAll("t", "a");

    try std.testing.expect(std.mem.eql(u8, string.toString(), "aesa"));

    try string.replaceAll("a", "t");
    try string.replaceAll("z", "b");

    try std.testing.expect(std.mem.eql(u8, string.toString(), "test"));

    try string.replaceAll("test", "r");

    try std.testing.expect(std.mem.eql(u8, string.toString(), "r"));

    try string.replaceAll("r", "");

    try std.testing.expect(std.mem.eql(u8, string.toString(), ""));

    try string.concat("test test2");
    try string.replaceAll("test test", "");

    try std.testing.expect(std.mem.eql(u8, string.toString(), "2"));
}

test "String: split" {
    var string = try String.initDefaultString(std.testing.allocator, "test,test2,test3");
    defer string.deinit();

    var res = try string.split(",");
    defer res.?.deinit();
    defer for (res.?.items) |*item| item.deinit();

    try std.testing.expectEqual(res.?.items.len, 3);
    try std.testing.expect(std.mem.eql(u8, res.?.items[0].toString(), "test"));
    try std.testing.expect(std.mem.eql(u8, res.?.items[1].toString(), "test2"));
    try std.testing.expect(std.mem.eql(u8, res.?.items[2].toString(), "test3"));

    var res2 = try string.split("/");
    defer res2.?.deinit();
    defer for (res2.?.items) |*item| item.deinit();

    try std.testing.expectEqual(res2.?.items.len, 1);
    try std.testing.expect(std.mem.eql(u8, res2.?.items[0].toString(), "test,test2,test3"));
}
