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
    std.log.info("⚡server listening on port: {d}", .{address.getPort()});

    // Declare a buffer to read client data into.
    var buf: [128]u8 = undefined;
    // While server is listening, handle requests.
    while (true) {
        // Allocate memory address for the clients address.
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |e| {
            std.log.err("error accept: {}", .{e});
            continue;
        };
        defer posix.close(socket);

        // Log the connected clients address.
        std.log.info("{} connected", .{client_address});

        // Set a timeout to stop a client blocking the thread indefinitely.
        const timeout = posix.timeval{ .tv_sec = 2, .tv_usec = 500_000 };
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));

        // Read data from the client.
        // `read` holds the length of bytes read.
        const read = posix.read(socket, &buf) catch |e| {
            std.log.err("error reading: {}", .{e});
            continue;
        };

        // If no bytes are read from the client, continue with the loop.
        if (read == 0) {
            continue;
        }

        // Write the bytes read from the client back from the server.
        write(socket, buf[0..read]) catch |e| {
            std.log.err("error writing: {}", .{e});
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
