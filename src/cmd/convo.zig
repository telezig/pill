//! Multi-step conversation — /ask asks a question, then the user's *next* message
//! is consumed as the answer.
//!
//! tz update handlers are stateless free functions, so per-user conversation state
//! has nowhere to live except module scope. We guard it with a mutex because the
//! bot's Io may be multi-threaded (std.Io.Threaded). This is the honest, idiomatic
//! place for app state given the handler model — not an abstraction for its own sake.

const std = @import("std");
const tz = @import("tz");
const Msg = tz.Msg;

const Step = enum { awaiting_name };

var mu: std.Io.Mutex = .init;
var pending: std.AutoHashMapUnmanaged(i64, Step) = .empty;

/// Start the conversation: remember that we're waiting for this user's name.
pub fn onAsk(msg: Msg) !void {
    const uid = msg.senderId() orelse return;
    {
        mu.lockUncancelable(msg.ctx.io);
        defer mu.unlock(msg.ctx.io);
        try pending.put(msg.ctx.allocator, uid, .awaiting_name);
    }
    try msg.reply("what's your name?");
}

/// Called for every incoming message before command dispatch. If the sender has a
/// pending step, consume this message as the answer and return true.
pub fn handle(msg: Msg) !bool {
    const uid = msg.senderId() orelse return false;
    const step = blk: {
        mu.lockUncancelable(msg.ctx.io);
        defer mu.unlock(msg.ctx.io);
        const e = pending.fetchRemove(uid) orelse return false;
        break :blk e.value;
    };
    switch (step) {
        .awaiting_name => {
            const s = try std.fmt.allocPrint(msg.ctx.allocator, "hi, {s}! 👋", .{msg.text()});
            defer msg.ctx.allocator.free(s);
            try msg.reply(s);
        },
    }
    return true;
}
