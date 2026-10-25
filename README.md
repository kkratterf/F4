# F4

*F4, basito.* Named after the most famous face in [Boris](https://it.wikipedia.org/wiki/Boris_(serie_televisiva)).

A Spotlight-like meme launcher for macOS. Press a shortcut, type a few letters, hit Enter: the meme is on your clipboard, GIF animation included, ready to paste into Slack, Discord or Telegram.

> Work in progress. The first version is being built: follow the [issues](https://github.com/kkratterf/f4/issues).

## Install

1. Download `F4-<version>.zip` from the [latest release](https://github.com/kkratterf/f4/releases/latest), unzip it and move **F4.app** to Applications.
2. F4 is not notarized yet. The first time you open it macOS blocks it: go to **System Settings → Privacy & Security** and click **Open Anyway**. Or run `xattr -dr com.apple.quarantine /Applications/F4.app`.
3. Press **⌘⇧M** anywhere. Put your memes in `~/Pictures/Memes` (or pick another folder in Settings, from the menu bar icon).

Needs macOS 14 Sonoma or later.

## Use

Type to search, arrows to move, **Enter** to copy, then paste with ⌘V. GIFs stay animated in Slack, Discord and Telegram. **Esc** or a click outside closes the panel.

Put a `.basito.png` (or `.gif`, `.jpg`) in the meme folder to use your own basito face when there is nothing to show. And try typing a few lines from Boris or The Office in the search field.

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
