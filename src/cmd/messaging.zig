//! Messaging — sending and editing text, rich formatting, chat actions, and inline
//! keyboards with callback handling.
//!
//! Commands: /echo /fmt /edit /typing /keyboard  (+ button callbacks)

const std = @import("std");
const tz = @import("tz");
const tg = tz.types;
const f = tz.functions;
const h = tz.helpers;
const Msg = tz.Msg;

pub fn onEcho(msg: Msg) !void {
    const arg = msg.text()["/echo ".len..];
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold(arg);
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onFmt(msg: Msg) !void {
    var ft = h.FormattedText.init(msg.ctx.allocator);
    defer ft.deinit();
    try ft.bold("bold");
    try ft.plain("  ");
    try ft.italic("italic");
    try ft.plain("  ");
    try ft.underline("underline");
    try ft.plain("  ");
    try ft.strike("strike");
    try ft.plain("  ");
    try ft.spoiler("spoiler");
    try ft.plain("\n");
    try ft.code("inline code");
    try ft.plain("\n");
    try ft.pre("pub fn main() !void {}\n", "zig");
    try ft.link("ziglang.org", "https://ziglang.org");
    try msg.replyFmt(ft.text.items, ft.entities.items);
}

pub fn onKeyboard(msg: Msg) !void {
    const peer = msg.peer() orelse return;
    var row1 = [_]tz.unions.KeyboardButton{
        h.keyboard.callbackButton("Button A", "cb:a"),
        h.keyboard.callbackButton("Button B", "cb:b"),
    };
    var row2 = [_]tz.unions.KeyboardButton{
        h.keyboard.urlButton("ziglang.org", "https://ziglang.org"),
    };
    var rows = [_]tg.KeyboardButtonRow{
        h.keyboard.inlineRow(&row1),
        h.keyboard.inlineRow(&row2),
    };
    try msg.ctx.exec(f.messages.SendMessage{
        .peer = peer,
        .message = "choose:",
        .reply_markup = .some(h.keyboard.inlineKeyboard(&rows)),
    });
}

/// Callback queries from the inline-keyboard buttons above.
pub fn onCallback(ctx: tz.Context, update: tg.UpdateBotCallbackQuery) !void {
    const data = update.data.value orelse return;
    if (std.mem.eql(u8, data, "cb:a")) {
        try h.answerCallbackQuery(ctx, update, .{ .text = "you pressed A!" });
    } else if (std.mem.eql(u8, data, "cb:b")) {
        try h.answerCallbackQuery(ctx, update, .{ .text = "you pressed B!", .alert = true });
    } else {
        try h.answerCallbackQuery(ctx, update, .{});
    }
}

pub fn onEdit(msg: Msg) !void {
    const peer = msg.peer() orelse return;
    const sent = try msg.ctx.call(f.messages.SendMessage{
        .peer = peer,
        .message = "editing in 2s...",
    });
    defer sent.deinit();
    const msg_id = h.sentMessageId(sent.value) orelse return;
    std.Io.sleep(msg.ctx.io, std.Io.Duration.fromSeconds(2), .awake) catch {};
    try h.editMessage(msg.ctx, peer, msg_id, .{ .text = "edited! ✓" });
}

pub fn onTyping(msg: Msg) !void {
    try h.sendChatAction(msg.ctx, msg.peer() orelse return, .{ .SendMessageTypingAction = .{} });
    std.Io.sleep(msg.ctx.io, std.Io.Duration.fromSeconds(2), .awake) catch {};
    try msg.reply("done typing");
}
