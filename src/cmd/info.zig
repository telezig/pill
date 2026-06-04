//! Info & queries — demonstrates reading the incoming Msg, calling TL methods
//! (getMe, users.GetUsers), resolving usernames, and building styled replies with
//! FormattedText.
//!
//! Commands: /help /ping /uptime /me /id /info /resolve

const std = @import("std");
const tz = @import("tz");
const f = tz.functions;
const h = tz.helpers;
const Msg = tz.Msg;

/// Set once in main() at startup; read by /uptime.
pub var start_time: std.Io.Timestamp = .{ .nanoseconds = 0 };

pub fn onHelp(msg: Msg) !void {
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold("pill");
    try ft.plain(" — tz feature showcase\n\n");
    const cmds = &[_][2][]const u8{
        .{ "/help", "this message" },
        .{ "/ping", "latency from message date" },
        .{ "/uptime", "time since bot start" },
        .{ "/me", "bot's own user info" },
        .{ "/id", "show peer/user/message IDs" },
        .{ "/info", "sender's user info" },
        .{ "/resolve @u", "resolve username → peer id" },
        .{ "/setcommands", "(re)register the command menu" },
        .{ "/echo <text>", "echo in bold" },
        .{ "/fmt", "formatting demo" },
        .{ "/keyboard", "inline keyboard + callbacks" },
        .{ "/edit", "send then edit a message" },
        .{ "/typing", "send typing action" },
        .{ "/document", "send a text file" },
        .{ "/download", "attach a file: stream via File.next()" },
        .{ "/ptest", "verify parallel download vs sequential" },
        .{ "/testalbum", "download + sendAlbum" },
        .{ "/testexternal", "InputMediaPhotoExternal" },
        .{ "/react", "add ❤ (reply to msg)" },
        .{ "/unreact", "clear reactions (reply)" },
        .{ "/pin", "pin a message (reply)" },
        .{ "/unpin", "unpin a message (reply)" },
        .{ "/delete", "delete a message (reply)" },
        .{ "/forward", "forward to this chat (reply)" },
        .{ "/ask", "multi-step conversation" },
    };
    for (cmds) |cmd| {
        try ft.code(cmd[0]);
        try ft.plain("  ");
        try ft.plain(cmd[1]);
        try ft.plain("\n");
    }
    try ft.plain("\nType ");
    try ft.code("@<botname> <text>");
    try ft.plain(" in any chat for inline mode. Send me a photo/sticker and I'll re-send it as a file.");
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onPing(msg: Msg) !void {
    const now_ms = std.Io.Clock.real.now(msg.ctx.io).toMilliseconds();
    const age_ms = now_ms - @as(i64, msg.date()) * 1000;
    const s = try std.fmt.allocPrint(msg.ctx.allocator, "pong — {d}ms", .{age_ms});
    defer msg.ctx.allocator.free(s);
    try msg.reply(s);
}

pub fn onUptime(msg: Msg) !void {
    const now = std.Io.Clock.real.now(msg.ctx.io);
    const elapsed_s = now.toSeconds() - start_time.toSeconds();
    const hh = @divFloor(elapsed_s, 3600);
    const mm = @divFloor(@rem(elapsed_s, 3600), 60);
    const ss = @rem(elapsed_s, 60);
    const s = try std.fmt.allocPrint(msg.ctx.allocator, "uptime: {d}h {d}m {d}s", .{ hh, mm, ss });
    defer msg.ctx.allocator.free(s);
    try msg.reply(s);
}

pub fn onMe(msg: Msg) !void {
    const users_resp = try h.getMe(msg.ctx);
    defer users_resp.deinit();
    const users = users_resp.value;
    if (users.len == 0) return msg.reply("no result");
    const user = switch (users[0]) {
        .User => |u| u,
        else => return msg.reply("unexpected type"),
    };
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold("bot info\n");
    const id_str = try std.fmt.allocPrint(msg.ctx.allocator, "id: {d}\n", .{user.id});
    defer msg.ctx.allocator.free(id_str);
    try ft.plain(id_str);
    if (user.first_name.value) |n| {
        try ft.plain("name: ");
        try ft.plain(n);
        try ft.plain("\n");
    }
    if (user.username.value) |n| {
        try ft.plain("username: @");
        try ft.plain(n);
        try ft.plain("\n");
    }
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onId(msg: Msg) !void {
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold("ids\n");
    const msg_str = try std.fmt.allocPrint(msg.ctx.allocator, "msg_id: {d}\n", .{msg.id()});
    defer msg.ctx.allocator.free(msg_str);
    try ft.plain(msg_str);
    switch (msg.raw.peer_id) {
        .PeerUser => |p| {
            const s = try std.fmt.allocPrint(msg.ctx.allocator, "peer: user {d}\n", .{p.user_id});
            defer msg.ctx.allocator.free(s);
            try ft.plain(s);
        },
        .PeerChat => |p| {
            const s = try std.fmt.allocPrint(msg.ctx.allocator, "peer: chat {d}\n", .{p.chat_id});
            defer msg.ctx.allocator.free(s);
            try ft.plain(s);
        },
        .PeerChannel => |p| {
            const s = try std.fmt.allocPrint(msg.ctx.allocator, "peer: channel {d}\n", .{p.channel_id});
            defer msg.ctx.allocator.free(s);
            try ft.plain(s);
        },
    }
    if (msg.senderId()) |sid| {
        const s = try std.fmt.allocPrint(msg.ctx.allocator, "from: user {d}\n", .{sid});
        defer msg.ctx.allocator.free(s);
        try ft.plain(s);
    }
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onInfo(msg: Msg) !void {
    const sender_id = msg.senderId() orelse return;
    var id_input = [_]tz.unions.InputUser{msg.ctx.entities.inputUser(sender_id) orelse return};
    const users_resp = try msg.ctx.call(f.users.GetUsers{ .id = &id_input });
    defer users_resp.deinit();
    const users = users_resp.value;
    if (users.len == 0) return msg.reply("no result");
    const user = switch (users[0]) {
        .User => |u| u,
        else => return msg.reply("unexpected user type"),
    };
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold("user info\n");
    const id_str = try std.fmt.allocPrint(msg.ctx.allocator, "id: {d}\n", .{user.id});
    defer msg.ctx.allocator.free(id_str);
    try ft.plain(id_str);
    if (user.first_name.value) |n| {
        try ft.plain("first: ");
        try ft.plain(n);
        try ft.plain("\n");
    }
    if (user.last_name.value) |n| {
        try ft.plain("last: ");
        try ft.plain(n);
        try ft.plain("\n");
    }
    if (user.username.value) |n| {
        try ft.plain("username: @");
        try ft.plain(n);
        try ft.plain("\n");
    }
    if (user.bot.value != null) try ft.italic("(bot account)");
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onResolve(msg: Msg) !void {
    const arg = std.mem.trim(u8, std.mem.trimStart(u8, msg.text()["/resolve".len..], " "), "@");
    if (arg.len == 0) return msg.reply("usage: /resolve @username");
    const peer = msg.ctx.resolveUsername(arg) catch |err| {
        const s = try std.fmt.allocPrint(msg.ctx.allocator, "error: {s}", .{@errorName(err)});
        defer msg.ctx.allocator.free(s);
        return msg.reply(s);
    };
    const id: i64 = switch (peer) {
        .InputPeerUser => |p| p.user_id,
        .InputPeerChannel => |p| p.channel_id,
        .InputPeerChat => |p| p.chat_id,
        else => 0,
    };
    const kind: []const u8 = switch (peer) {
        .InputPeerUser => "user",
        .InputPeerChannel => "channel",
        .InputPeerChat => "chat",
        else => "?",
    };
    const s = try std.fmt.allocPrint(msg.ctx.allocator, "resolved: {s} id={d}", .{ kind, id });
    defer msg.ctx.allocator.free(s);
    try msg.reply(s);
}
