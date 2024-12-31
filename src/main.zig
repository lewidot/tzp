const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {

    // Declare address, type of socket and protocol.
    const address = try net.Address.resolveIp("127.0.0.1", 5882);
    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;

    // Define the socket.
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    // Allow socket to be stopped and started without errors.
    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

    // Bind the socket to the address.
    try posix.bind(listener, &address.any, address.getOsSockLen());

    // Listen on the address and receive incoming requests.
    try posix.listen(listener, 128);
    std.debug.print("⚡server listening on port: {d}\n", .{address.getPort()});

    // While server is listening, handle requests.
    while (true) {
        // Allocate memory address for the clients address.
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |e| {
            std.debug.print("error accept: {}\n", .{e});
            continue;
        };
        defer posix.close(socket);

        // Print the connected clients address.
        std.debug.print("{} connected\n", .{client_address});

        write(socket, "Hello (and goodbye)") catch |e| {
            std.debug.print("error writing: {}\n", .{e});
        };
    }
}

/// Write bytes to the socket.
fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        // Loop needed to ensure all bytes are written.
        // Therefore all bytes from the position index are written.
        const written = try posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
