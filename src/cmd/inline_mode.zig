//! Inline mode — query format drives the result type:
//!
//!   @bot https://...   → photo from that URL
//!   @bot $LaTeX$       → rich message math block
//!   @bot (empty)       → usage help

const std = @import("std");
const tz = @import("tz");
const tg = tz.types;
const h = tz.helpers;

pub fn onInline(ctx: tz.Context, update: tg.UpdateBotInlineQuery) !void {
    const q = std.mem.trim(u8, update.query, " ");

    if (q.len == 0) return answerHelp(ctx, update);

    if (std.mem.startsWith(u8, q, "http://") or std.mem.startsWith(u8, q, "https://"))
        return answerPhoto(ctx, update, q);

    if (q[0] == '$')
        return answerMath(ctx, update, q);
}

fn answerHelp(ctx: tz.Context, update: tg.UpdateBotInlineQuery) !void {
    var results = [_]tz.unions.InputBotInlineResult{
        .{ .InputBotInlineResult = .{
            .id = "help",
            .type = "article",
            .title = .some("Usage"),
            .description = .some("$formula$ → math"),
            .send_message = .{ .InputBotInlineMessageRichMessage = .{
                .rich_message = .{ .InputRichMessageHTML = .{
                    .html =
                    \\<blockquote><tg-math>\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}</tg-math></blockquote>
                    \\<tg-math-block>\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}</tg-math-block>
                    \\<blockquote><tg-math>\text{fBm}(x) = \sum_{k=0}^{n-1} \frac{\sin(2^k x + \phi_k)}{2^{kH}}</tg-math></blockquote>
                    \\<tg-math-block>\text{fBm}(x) = \sum_{k=0}^{n-1} \frac{\sin(2^k x + \phi_k)}{2^{kH}}</tg-math-block>
                    ,
                } },
            } },
        } },
    };
    try h.answerInlineQuery(ctx, update, &results, .{ .cache_time = 0 });
}

fn answerPhoto(ctx: tz.Context, update: tg.UpdateBotInlineQuery, url: []const u8) !void {
    const mime = try fetchContentType(ctx.allocator, ctx.io, url);
    defer ctx.allocator.free(mime);

    const no_attrs: []const tz.unions.DocumentAttribute = &.{};
    const web_doc = tg.InputWebDocument{
        .url = url,
        .size = 0,
        .mime_type = mime,
        .attributes = no_attrs,
    };
    var results = [_]tz.unions.InputBotInlineResult{
        .{ .InputBotInlineResult = .{
            .id = "photo",
            .type = "photo",
            .title = .some("Send photo"),
            .content = .some(web_doc),
            .thumb = .some(web_doc),
            .send_message = .{ .InputBotInlineMessageMediaAuto = .{ .message = "" } },
        } },
    };
    try h.answerInlineQuery(ctx, update, &results, .{ .cache_time = 0 });
}

fn answerMath(ctx: tz.Context, update: tg.UpdateBotInlineQuery, q: []const u8) !void {
    var expr = q;
    while (expr.len > 0 and expr[0] == '$') expr = expr[1..];
    while (expr.len > 0 and expr[expr.len - 1] == '$') expr = expr[0 .. expr.len - 1];
    expr = std.mem.trim(u8, expr, " ");

    if (expr.len == 0) return answerHelp(ctx, update);

    const html = try std.fmt.allocPrint(ctx.allocator, "<tg-math-block>{s}</tg-math-block>", .{expr});
    defer ctx.allocator.free(html);

    var results = [_]tz.unions.InputBotInlineResult{
        .{ .InputBotInlineResult = .{
            .id = "math",
            .type = "article",
            .title = .some("Send math ✨"),
            .description = .some(expr),
            .send_message = .{ .InputBotInlineMessageRichMessage = .{
                .rich_message = .{ .InputRichMessageHTML = .{ .html = html } },
            } },
        } },
    };
    try h.answerInlineQuery(ctx, update, &results, .{ .cache_time = 0 });
}

fn fetchContentType(allocator: std.mem.Allocator, io: std.Io, url: []const u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var req = try client.request(.HEAD, uri, .{});
    defer req.deinit();
    try req.sendBodiless();

    var redirect_buf: [4096]u8 = undefined;
    const response = try req.receiveHead(&redirect_buf);

    const ct = response.head.content_type orelse "image/jpeg";
    const end = std.mem.indexOfScalar(u8, ct, ';') orelse ct.len;
    return allocator.dupe(u8, std.mem.trim(u8, ct[0..end], " "));
}
