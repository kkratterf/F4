# F4

A Spotlight-like meme launcher for macOS. Press a shortcut, type a few letters, hit Enter: the meme is on your clipboard, GIF animation included, ready to paste into Slack, Discord or Telegram.

> Work in progress. The first version is being built: follow the [issues](https://github.com/kkratterf/f4/issues).

## Requirements

macOS 14 Sonoma or later.

## Build from source

Needs Xcode 15+.

```bash
swift build
swift test
scripts/build-app.sh release
open dist/F4.app
```

## License

[MIT](LICENSE)
