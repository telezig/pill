//! pill — a tz feature-showcase bot.
//!
//! This is the wiring: read credentials, build a `Client` with a comptime handler
//! table, register one handler per update type, and dispatch slash-commands with a
//! plain `if` chain (explicit control flow over a clever command table — easier to
//! read, very Zig). Each capability lives in its own `cmd/*.zig` module; see
//! README.md for the command ↔ tz-API map.
//!
//! Credentials come from the environment: API_ID, API_HASH, BOT_TOKEN.

const std = @import("std");
const tz = @import("tz");
const tg = tz.types;
const f = tz.functions;
const Msg = tz.Msg;

const info = @import("cmd/info.zig");
const messaging = @import("cmd/messaging.zig");
const media = @import("cmd/media.zig");
const moderation = @import("cmd/moderation.zig");
const inline_mode = @import("cmd/inline_mode.zig");
const convo = @import("cmd/convo.zig");

/// Set in main() from the OWNER_ID env var. null = respond to everyone.
var owner_id: ?i64 = null;

fn isAllowed(msg: Msg) bool {
    const owner = owner_id orelse return true; // no owner set → open to all
    return switch (msg.raw.peer_id) {
        .PeerUser => |p| p.user_id == owner,
        else => false,
    };
}

fn onMessage(ctx: tz.Context, update: tg.UpdateNewMessage) !void {
    const msg = Msg.from(ctx, update) orelse return;
    // Ignore our own outgoing messages: after a send, the local pts lags and the
    // next getDifference replays them back to us.
    if (msg.raw.out.value != null) return;
    if (!isAllowed(msg)) return;

    // A pending multi-step conversation consumes the next message before any
    // command dispatch. Returns true if it handled this message.
    if (try convo.handle(msg)) return;

    // info
    if (msg.is("/start") or msg.is("/help")) return info.onHelp(msg);
    if (msg.is("/ping")) return info.onPing(msg);
    if (msg.is("/uptime")) return info.onUptime(msg);
    if (msg.is("/me")) return info.onMe(msg);
    if (msg.is("/id")) return info.onId(msg);
    if (msg.is("/info")) return info.onInfo(msg);
    if (msg.is("/setcommands")) return onSetCommands(msg);
    if (msg.prefix("/resolve")) return info.onResolve(msg);
    // messaging
    if (msg.prefix("/echo ")) return messaging.onEcho(msg);
    if (msg.is("/fmt")) return messaging.onFmt(msg);
    if (msg.is("/keyboard")) return messaging.onKeyboard(msg);
    if (msg.is("/edit")) return messaging.onEdit(msg);
    if (msg.is("/typing")) return messaging.onTyping(msg);
    // media
    if (msg.is("/document")) return media.onDocument(msg);
    if (msg.is("/testalbum")) return media.onTestAlbum(msg);
    if (msg.is("/testexternal")) return media.onTestExternal(msg);
    if (msg.prefix("/download")) return media.onDownload(msg);
    if (msg.is("/ptest")) return media.onParallel(msg);
    // moderation
    if (msg.is("/react")) return moderation.onReact(msg);
    if (msg.is("/unreact")) return moderation.onUnreact(msg);
    if (msg.is("/pin")) return moderation.onPin(msg);
    if (msg.is("/unpin")) return moderation.onUnpin(msg);
    if (msg.is("/delete")) return moderation.onDelete(msg);
    if (msg.is("/forward")) return moderation.onForward(msg);
    // conversation
    if (msg.is("/ask")) return convo.onAsk(msg);

    // No command matched: if it's media, echo it back as a file.
    try media.onIncomingMedia(msg);
}

fn onCallback(ctx: tz.Context, update: tg.UpdateBotCallbackQuery) !void {
    return messaging.onCallback(ctx, update);
}

fn onInline(ctx: tz.Context, update: tg.UpdateBotInlineQuery) !void {
    return inline_mode.onInline(ctx, update);
}

/// The comptime handler table — one entry per update type we care about. The
/// Client dispatches each incoming update to the matching handler with zero
/// runtime lookup.
const handlers = &.{
    tz.handler(tg.UpdateNewMessage, onMessage),
    tz.handler(tg.UpdateBotCallbackQuery, onCallback),
    tz.handler(tg.UpdateBotInlineQuery, onInline),
};

/// Register the command menu so clients show our commands. Used both as the
/// on_ready hook (runs once at startup) and by /setcommands for manual re-runs
/// against an existing session.
fn registerCommands(ctx: tz.Context) !void {
    var cmds = [_]tg.BotCommand{
        .{ .command = "help", .description = "show commands" },
        .{ .command = "ping", .description = "latency from message date" },
        .{ .command = "me", .description = "bot's own user info" },
        .{ .command = "fmt", .description = "formatting demo" },
        .{ .command = "keyboard", .description = "inline keyboard" },
        .{ .command = "download", .description = "stream an attached file" },
        .{ .command = "ptest", .description = "verify parallel download" },
        .{ .command = "ask", .description = "multi-step conversation" },
    };
    try ctx.exec(f.bots.SetBotCommands{
        .scope = .{ .BotCommandScopeDefault = .{} },
        .lang_code = "",
        .commands = &cmds,
    });
}

fn onSetCommands(msg: Msg) !void {
    try registerCommands(msg.ctx);
    try msg.reply("commands registered");
}

/// Credentials read from the environment. The strings point into the process
/// environment block, which is stable for the program's lifetime.
const Config = struct {
    api_id: i32,
    api_hash: []const u8,
    bot_token: []const u8,
    /// Optional: when unset, the bot answers everyone.
    owner_id: ?i64,

    fn fromEnv(environ: std.process.Environ) !Config {
        const api_id_str = environ.getPosix("API_ID") orelse return error.MissingApiId;
        return .{
            .api_id = std.fmt.parseInt(i32, std.mem.trim(u8, api_id_str, " \n\r"), 10) catch
                return error.InvalidApiId,
            .api_hash = environ.getPosix("API_HASH") orelse return error.MissingApiHash,
            .bot_token = environ.getPosix("BOT_TOKEN") orelse return error.MissingBotToken,
            .owner_id = if (environ.getPosix("OWNER_ID")) |s|
                std.fmt.parseInt(i64, std.mem.trim(u8, s, " \n\r"), 10) catch return error.InvalidOwnerId
            else
                null,
        };
    }
};

/// The runtime hands us a ready `io`, `gpa`, and the process environment — no
/// manual allocator/event-loop setup needed.
pub fn main(init: std.process.Init) !void {
    const config = Config.fromEnv(init.minimal.environ) catch |err| {
        std.log.err("config: {s} — set API_ID, API_HASH and BOT_TOKEN", .{@errorName(err)});
        return err;
    };
    owner_id = config.owner_id;

    var file_storage = tz.Storage.File.init("pill.session");

    const client = try tz.Client(handlers).init(init.gpa, .{
        .api_id = config.api_id,
        .api_hash = config.api_hash,
        .bot_token = config.bot_token,
        .storage = file_storage.storage(),
        .on_ready = registerCommands,
    });
    defer client.deinit();

    info.start_time = std.Io.Clock.real.now(init.io);
    try client.run(init.io);
}
