//! Moderation actions on a replied-to message: reactions, pin/unpin, delete,
//! forward. All take the reply target (replyToId) and use the high-level helpers.
//!
//! Commands: /react /unreact /pin /unpin /delete /forward

const tz = @import("tz");
const h = tz.helpers;
const Msg = tz.Msg;

pub fn onReact(msg: Msg) !void {
    const peer = msg.peer() orelse return;
    try h.addReaction(msg.ctx, peer, msg.replyToId() orelse msg.id(), "❤");
}

pub fn onUnreact(msg: Msg) !void {
    const peer = msg.peer() orelse return;
    try h.removeReaction(msg.ctx, peer, msg.replyToId() orelse msg.id());
}

pub fn onPin(msg: Msg) !void {
    const target_id = msg.replyToId() orelse
        return msg.respond("reply to a message to pin it");
    try h.pinMessage(msg.ctx, msg.peer() orelse return, target_id, .{});
}

pub fn onUnpin(msg: Msg) !void {
    const target_id = msg.replyToId() orelse
        return msg.respond("reply to a message to unpin it");
    try h.pinMessage(msg.ctx, msg.peer() orelse return, target_id, .{ .unpin = true });
}

pub fn onDelete(msg: Msg) !void {
    const target_id = msg.replyToId() orelse
        return msg.respond("reply to a message to delete it");
    try h.deleteMessage(msg.ctx, msg.peer() orelse return, target_id);
}

pub fn onForward(msg: Msg) !void {
    const target_id = msg.replyToId() orelse
        return msg.respond("reply to a message to forward it");
    const peer = msg.peer() orelse return;
    var fwd_ids = [_]i32{target_id};
    try h.forwardMessages(msg.ctx, peer, peer, &fwd_ids);
}
