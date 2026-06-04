//! Inline mode — answering `@bot <query>` inline queries. Demonstrates handling
//! the UpdateBotInlineQuery update type and building an InputBotInlineResult that
//! sends a text message when the user picks it.
//!
//! Register in BotFather first: /setinline to enable inline mode for the bot.

const tz = @import("tz");
const tg = tz.types;
const h = tz.helpers;

pub fn onInline(ctx: tz.Context, update: tg.UpdateBotInlineQuery) !void {
    const query = if (update.query.len == 0) "type something..." else update.query;

    // One article result that echoes the query back as a bold message.
    var ft = h.FormattedText.init(ctx.allocator);
    defer ft.deinit();
    try ft.bold(query);

    var results = [_]tz.unions.InputBotInlineResult{
        .{ .InputBotInlineResult = .{
            .id = "echo",
            .type = "article",
            .title = .some("Echo"),
            .description = .some(query),
            .send_message = .{ .InputBotInlineMessageText = .{
                .message = ft.text.items,
                .entities = .some(ft.entities.items),
            } },
        } },
    };
    try h.answerInlineQuery(ctx, update, &results, .{ .cache_time = 1 });
}
