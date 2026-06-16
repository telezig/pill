//! Join Request Gate (layer 227) — handles UpdateBotChatInviteRequester when
//! the channel has a guard bot configured.  The update now carries a query_id
//! that the bot must answer with bots.SetJoinChatResults.
//!
//! Result variants:
//!   .JoinChatBotResultApproved  — let the user in immediately
//!   .JoinChatBotResultDeclined  — reject the request
//!   .JoinChatBotResultQueued    — hold for manual admin review
//!   .JoinChatBotResultWebView   — redirect the user to a URL before deciding

const std = @import("std");
const tz = @import("tz");
const tg = tz.types;
const f = tz.functions;
const Msg = tz.Msg;

/// Called for every UpdateBotChatInviteRequester.  When the update has a
/// query_id (layer 227 gate flow) we answer it; older updates without one are
/// purely informational and need no reply.
pub fn onJoinRequest(ctx: tz.Context, update: tg.UpdateBotChatInviteRequester) !void {
    const query_id = update.query_id.value orelse return; // pre-227 — no reply needed

    // Demo: approve everyone.  Real bots would inspect update.user_id,
    // update.about, or the invite link to pick a result.
    try ctx.exec(f.bots.SetJoinChatResults{
        .query_id = query_id,
        .result = .{ .JoinChatBotResultApproved = .{} },
    });

    // Other result variants for reference:
    //
    // Decline:
    //   .result = .{ .JoinChatBotResultDeclined = .{} }
    //
    // Queue for manual review:
    //   .result = .{ .JoinChatBotResultQueued = .{} }
    //
    // Redirect to a web app before deciding:
    //   .result = .{ .JoinChatBotResultWebView = .{ .url = "https://example.com/verify" } }

    _ = std.log.info("approved join request query_id={d} user_id={d}", .{ query_id, update.user_id });
}
