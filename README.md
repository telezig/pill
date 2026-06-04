# pill

a telegram bot built on [tz](https://github.com/telezig/tz). it exists to show how the library is used, written plainly.

- messaging — send, edit, formatted text, chat actions
- inline keyboards + callbacks
- media — upload, sequential download (`File.next()`), parallel download/upload, albums, server-side external media
- inline mode — `@bot <text>` answered via `answerInlineQuery`
- moderation — reactions, pin/unpin, delete, forward
- multi-step conversation — state kept at module scope, since handlers are free functions
- command menu — registered once at startup through the `on_ready` hook

```sh
# OWNER_ID is optional — unset answers everyone; /id prints yours
API_ID=123456 API_HASH=your_api_hash BOT_TOKEN=123456:your-bot-token OWNER_ID=123456789 zig build run
```

api id / hash from <https://my.telegram.org>, bot token from [@BotFather](https://t.me/BotFather). for inline mode, send `/setinline` to BotFather first.

session persists to `pill.session`.

| command | shows |
|---|---|
| `/help` `/ping` `/uptime` | `FormattedText`, `Msg.date`, `Io.Clock` |
| `/me` `/info` | `getMe`, `users.GetUsers`, `ctx.entities` |
| `/id` `/resolve @u` | reading `Msg`, `resolveUsername` |
| `/echo` `/fmt` | `FormattedText` — bold/italic/code/pre/link |
| `/keyboard` + buttons | `keyboard.*`, `answerCallbackQuery` |
| `/edit` `/typing` | `editMessage`, `sendChatAction` |
| `/document` | `media.sendDocument` |
| `/download` | `File.next()` — sequential stream |
| `/ptest` | parallel vs sequential download — bytes + timing |
| `/testalbum` `/testexternal` | `media.sendAlbum`, `InputMediaPhotoExternal` |
| `/react` `/unreact` `/pin` `/unpin` `/delete` `/forward` | moderation helpers |
| `/ask` | multi-step conversation |
| `@bot <text>` | inline mode |
| a photo or sticker | download, then re-upload as a file |
