//! Rich Messages (layer 227) — Markdown demo, HTML demo, streaming demo.
//!
//! Commands: /richmd  /richhtml  /richstream

const std = @import("std");
const tz = @import("tz");
const tg = tz.types;
const f = tz.functions;
const h = tz.helpers;
const Msg = tz.Msg;

/// /richmd — Markdown variant showcase.
pub fn onRichMd(msg: Msg) !void {
    try msg.respondRich(.{ .InputRichMessageMarkdown = .{
        .markdown =
        \\# rich messages ✨
        \\
        \\**bold** *italic* ~~strike~~ `code` ==marked== ||spoiler||
        \\<u>underline</u> <sup>sup</sup> <sub>sub</sub>
        \\
        \\inline math: $e^{i\pi} + 1 = 0$
        \\
        \\$$\sum_{n=1}^{39} e^{in\theta} = \text{miku}$$
        \\
        \\```zig
        \\const answer: u8 = 42;
        \\```
        \\
        \\>the best error message is the one you never see
        \\
        \\- [ ] write tests
        \\- [x] ship it
        \\
        \\| name | value |
        \\|:-----|------:|
        \\| pi   | 3.14  |
        \\| e    | 2.71  |
        \\
        \\![✨](tg://emoji?id=5368324170671202286)
        \\layer 227[^a]
        \\
        \\[^a]: miku = 39.
        ,
    } });
}

/// /richhtml — HTML variant showcase.
pub fn onRichHtml(msg: Msg) !void {
    try msg.respondRich(.{ .InputRichMessageHTML = .{
        .html =
        \\<h1>rich messages ✨</h1>
        \\<p><b>bold</b> <i>italic</i> <u>underline</u> <s>strike</s>
        \\<tg-spoiler>spoiler</tg-spoiler> <mark>marked</mark> <code>code</code>
        \\<sup>sup</sup> <sub>sub</sub></p>
        \\
        \\<p>inline: <tg-math>e^{i\pi} + 1 = 0</tg-math>
        \\  emoji: <tg-emoji emoji-id="5368324170671202286">✨</tg-emoji></p>
        \\
        \\<tg-math-block>\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}</tg-math-block>
        \\
        \\<pre><code class="language-zig">const answer: u8 = 42;</code></pre>
        \\
        \\<ul>
        \\<li><input type="checkbox" checked>ship it</li>
        \\<li><input type="checkbox">write tests</li>
        \\</ul>
        \\
        \\<table bordered striped>
        \\<tr><th>name</th><th>value</th></tr>
        \\<tr><td>pi</td><td>3.14</td></tr>
        \\<tr><td>e</td><td>2.71</td></tr>
        \\</table>
        \\
        \\<blockquote>the best error message is the one you never see</blockquote>
        \\
        \\<details open><summary>aside</summary>
        \\<p>layer 227 — <a href="#fn-a">miku = 39</a></p>
        \\</details>
        \\
        \\<figure><img src="https://s3.s4r.in/aozoraneko"/><figcaption>aozoraneko</figcaption></figure>
        \\
        \\<tg-reference name="fn-a">miku = 39.</tg-reference>
        \\<footer>tz · layer 227</footer>
        ,
    } });
}

/// /richstream — multi-phase streaming demo.
///
/// Phase 1  <tg-thinking> (draft-only)
/// Phase 2  partial content
/// Phase 3  final message
pub fn onRichStream(msg: Msg) !void {
    const peer = msg.peer() orelse return;
    const alloc = msg.ctx.allocator;

    // Non-zero draft_id stays constant so the client animates in-place.
    var draft_id: i64 = 0;
    while (draft_id == 0) msg.ctx.io.random(std.mem.asBytes(&draft_id));

    // -- Phase 1: thinking -------------------------------------------------
    try msg.ctx.exec(f.messages.SetTyping{
        .peer = peer,
        .action = .{ .InputSendMessageRichMessageDraftAction = .{
            .random_id = draft_id,
            .rich_message = .{ .InputRichMessageHTML = .{
                .html = \\<tg-thinking>working on it...</tg-thinking>
                ,
            } },
        } },
    });
    std.Io.sleep(msg.ctx.io, std.Io.Duration.fromSeconds(2), .awake) catch {};

    // -- Phase 2: partial --------------------------------------------------
    try msg.ctx.exec(f.messages.SetTyping{
        .peer = peer,
        .action = .{ .InputSendMessageRichMessageDraftAction = .{
            .random_id = draft_id,
            .rich_message = .{ .InputRichMessageHTML = .{
                .html =
                \\<h1>stream demo</h1>
                \\<p><b>bold</b> <i>italic</i> <u>underline</u> <s>strike</s>
                \\<tg-spoiler>spoiler</tg-spoiler> <mark>marked</mark> <code>code</code></p>
                \\<tg-math-block>\hat{f}(\xi) = \int_{-\infty}^{\infty} f(t)\,e^{-2\pi i \xi t}\,dt</tg-math-block>
                \\<p><i>almost there...</i></p>
                ,
            } },
        } },
    });
    std.Io.sleep(msg.ctx.io, std.Io.Duration.fromSeconds(2), .awake) catch {};

    // -- Phase 3: final ----------------------------------------------------
    const sender_id = msg.senderId() orelse 0;
    const mention = try std.fmt.allocPrint(alloc, "<a href=\"tg://user?id={d}\">you</a>\n", .{sender_id});
    defer alloc.free(mention);

    const html = try std.mem.concat(alloc, u8, &.{
        \\<h1>stream demo</h1>
        \\
        \\<h2>text</h2>
        \\<p><b>bold</b> <i>italic</i> <u>underline</u> <s>strike</s>
        \\<tg-spoiler>spoiler</tg-spoiler> <mark>marked</mark> <code>code</code>
        \\<sup>sup</sup> <sub>sub</sub></p>
        \\
        \\<h2>math</h2>
        \\<tg-math-block>\hat{f}(\xi) = \int_{-\infty}^{\infty} f(t)\,e^{-2\pi i \xi t}\,dt</tg-math-block>
        \\<tg-math-block>\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}</tg-math-block>
        \\
        \\<h2>code</h2>
        \\<pre><code class="language-zig">const answer: u8 = 42;</code></pre>
        \\
        \\<h2>lists</h2>
        \\<ul><li>unordered</li><li>items</li></ul>
        \\<ol><li>first</li><li>second</li></ol>
        \\<ol type="a"><li>alpha</li><li>bravo</li></ol>
        \\<ul>
        \\<li><input type="checkbox" checked>done</li>
        \\<li><input type="checkbox">todo</li>
        \\</ul>
        \\
        \\<h2>table</h2>
        \\<table bordered striped>
        \\<caption>constants</caption>
        \\<tr><th>name</th><th align="right">value</th></tr>
        \\<tr><td>pi</td><td align="right">3.14159</td></tr>
        \\<tr><td>e</td><td align="right">2.71828</td></tr>
        \\<tr><td colspan="2" align="center">miku = 39</td></tr>
        \\</table>
        \\
        \\<h2>quotes</h2>
        \\<blockquote>the best error message is the one you never see</blockquote>
        \\<aside>layer 227<cite>tz</cite></aside>
        \\
        \\<h2>details</h2>
        \\<details open><summary>expand me</summary>
        \\<p>rich content inside: <b>bold</b>, <tg-math>e^{i\pi}+1=0</tg-math></p>
        \\</details>
        \\
        \\<h2>media</h2>
        \\<figure><img src="https://s3.s4r.in/aozoraneko" tg-spoiler/><figcaption>photo (spoiler)<cite>s4r.in</cite></figcaption></figure>
        \\<figure><audio src="https://telegram.org/example/audio.mp3"></audio><figcaption>audio</figcaption></figure>
        \\<figure><video src="https://telegram.org/example/video.mp4" tg-spoiler></video><figcaption>video (spoiler)</figcaption></figure>
        \\<tg-slideshow>
        \\<img src="https://s3.s4r.in/aozoraneko"/>
        \\<img src="https://s3.s4r.in/teto/mon"/>
        \\<figcaption>slideshow</figcaption>
        \\</tg-slideshow>
        \\
        \\<h2>location</h2>
        \\<figure><tg-map lat="41.9" long="12.5" zoom="14"/><figcaption>Rome</figcaption></figure>
        \\
        \\<h2>entities</h2>
        \\<p>#tz $TZ +12345678901 card:&nbsp;4242&nbsp;4242&nbsp;4242&nbsp;4242</p>
        \\<p><tg-emoji emoji-id="5368324170671202286">✨</tg-emoji> &nbsp;
        \\<tg-time unix="1647531900" format="wDT">Mar 17 22:45</tg-time></p>
        \\<p>ref: <a href="#note-1">footnote</a></p>
        \\<tg-reference name="note-1">miku = 39.</tg-reference>
        \\<p>
        ,
        mention,
        \\<a href="https://github.com/telezig/tz">tz</a></p>
        \\
        \\<hr/>
        \\<footer>tz · layer 227</footer>
        \\
        ,
    });
    defer alloc.free(html);

    try msg.respondRich(.{ .InputRichMessageHTML = .{ .html = html } });
}
