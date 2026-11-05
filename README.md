<p align="center"><img src="Resources/logo/icon.png" width="128" height="128" alt="The F4 logo: Stanis from Boris, basito"></p>

# F4

**Your stickers, on the Mac.**

[![CI](https://github.com/kkratterf/f4/actions/workflows/ci.yml/badge.svg)](https://github.com/kkratterf/f4/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/kkratterf/f4)](https://github.com/kkratterf/f4/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)
[![Website](https://img.shields.io/badge/website-f4.kkratter.com-FFC43D)](https://f4.kkratter.com/)

Stickers like on WhatsApp, but for the whole Mac. Press **F4**, type a few letters, hit Enter: the sticker is on your clipboard — animation included — ready to paste into WhatsApp, Slack, Discord, Telegram or anywhere else. A native macOS app in Swift (SwiftUI and AppKit), free and open source, no account and no tracking.

*F4, basito.* Named after the most famous face in [Boris](https://it.wikipedia.org/wiki/Boris_(serie_televisiva)).

**Website:** [f4.kkratter.com](https://f4.kkratter.com/)

**Install** (macOS 14+, free, no special permissions):

```bash
curl -fsSL https://raw.githubusercontent.com/kkratterf/f4/main/install.sh | sh
```

or [download the DMG](https://github.com/kkratterf/f4/releases/latest/download/F4.dmg), or use [Homebrew](#3-homebrew). F4 is not notarized yet: see [first launch](#4-first-launch-and-gatekeeper) if macOS blocks it.

---

## How it works

1. Copy any sticker or image (⌘C: in WhatsApp, right-click a sticker → Copy), press **fn F4** and paste it with **⌘V**: F4 keeps it as a sticker. You can also drop files or click **Add** in the panel, and switch on the packs you want from the menu bar (**Packs**). They go in F4's own library, `~/Library/Application Support/F4/Memes`, which comes with a starter pack already in it. Subfolders become categories.
2. Press **F4** from any app. The panel floats above everything, full-screen apps included, and opens instantly. On a Mac keyboard the top row are media keys first (F4 opens Spotlight or Launchpad): hold **fn** and press **F4**, or turn on **Use F1, F2, etc. keys as standard function keys** in System Settings → Keyboard → Keyboard Shortcuts → Function Keys. On most other keyboards F4 just works.
3. Type to search, move with the arrow keys, press **Enter**. The sticker is copied and a small **Copied to Clipboard** toast says so; paste it with ⌘V wherever you want.

**Esc**, or a click outside, closes the panel. Drag it by the search bar to move it: it snaps to the centre of the screen, and opens where you left it next time.

## Features

| | |
| --- | --- |
| 🎞️ **Animated stickers stay animated** | F4 writes the file URL (`public.file-url`) and the raw bytes under the file's UTI, never a decoded `NSImage`, so apps paste the animation. PNG, WebP (WhatsApp and Telegram's format), GIF and JPEG all work as stickers. |
| ⚡️ **Instant** | Folder scans, thumbnail decoding and file reads happen in the background. The main thread is never blocked, and only the hovered or selected sticker animates. |
| 🔎 **Fuzzy search** | Type a few letters of the name or the folder: "tif" finds "this is fine". Favourites (click the star on a sticker, or ⌘D) get their own section on top and their own tab (Tab, ⌘1 and ⌘2), then the ones you used last. |
| 📦 **Packs you switch on** | The menu bar's **Packs** lists sticker packs: switch one on and F4 downloads it into a folder of your library, switch it off and it goes to the Trash. F4 ships only the list of links, never the files, and downloads nothing until you switch a pack on. |
| 🎁 **Starter pack** | F4 never opens empty: it ships with animated emoji (`Emoji/`) and its own stickers (`F4/`: "basito", "dai dai dai", the F4 keycap...), copied into F4's library on the first launch, so they are yours to move, rename or delete. With a folder of your own they are listed after your stickers instead (Show Starter Pack in the menu bar). |
| 📥 **WhatsApp sticker packs** | Drop a `.wastickers` file (the format WhatsApp sticker packs come in) on the panel, paste it with ⌘V, pick it with **Add**, or paste a link to one: F4 unpacks it into a folder named after the pack. Packs from [getstickerpack.com](https://getstickerpack.com/stickers) (what the "Sticker Maker" apps use) work from their link: paste the pack page or its "Add to WhatsApp" link and F4 downloads all its stickers into a folder named after it. Single stickers work too: in WhatsApp for Mac, right-click a sticker → Copy, then ⌘V in the panel. |
| ➕ **Add from the panel** | Press ⌘V in the panel to add a copied sticker, a sticker pack or an image link (in WhatsApp or Telegram: right-click a sticker → Copy), drop files or stickers on it, or click **Add**. No Finder needed. The first launch shows how, and so do **How to Add Stickers…** in the menu bar and the ⓘ button in the panel. |
| 🖼️ **Memes become stickers** | A photo or a meme you add becomes a 512×512 sticker, the size WhatsApp uses: the whole picture, caption included, fitted into the square, with the space left over transparent. Nothing is cut out or added. Transparent PNGs, GIFs and WebP stay exactly as they are, and **⌥⌘V** keeps any picture as it is. |
| 🗂️ **Folders without Finder** | Each subfolder is a category you can search by name. Right-click a sticker in the panel to **Move To** a folder (or a **New Folder…**), **Rename…** it or **Move to Trash**; the menu bar's **Folders** creates, renames and trashes folders. Favourites and recents follow the files. |
| ✅ **Copied, and it tells you** | After a copy a small toast at the bottom of the screen says **Copied to Clipboard**, then fades. It takes no clicks and no focus, so ⌘V works right away. |
| 🔐 **No permissions** | The global shortcut uses Carbon `RegisterEventHotKey`: no Accessibility, no Input Monitoring, no Screen Recording. F4 asks for no permission at all. |
| 🖥️ **Menu bar** | No Dock icon and no Settings window. The menu bar icon opens the panel, copies one of your last 5 stickers in a click, and manages folders and packs. F4 starts at login on its own. |
| 🔄 **Updates itself** | F4 checks the release feed and installs a new version in one click (Check for Updates… in the menu bar). |
| 🇮🇹 **English and Italian** | The app follows your Mac's language. |
| 🧩 **Raycast** | A [Raycast extension](raycast) searches the same folder, if that is where your hands already are. |

### Easter eggs

The empty state draws the basito face in code. Drop a `.basito.png` (or `.gif`, `.jpg`) in the sticker folder to use your own face instead. Typing a few lines from Boris or The Office in the search field — or the Konami code — does something. Find out which.

### Automation: `f4://` URLs

Shortcuts, Raycast, Alfred, a Stream Deck, a script or an AI agent can drive F4 by opening a URL, for example `open "f4://copy?name=this%20is%20fine"` in Terminal.

| URL | What it does |
| --- | --- |
| `f4://open` | Shows the panel |
| `f4://search?q=this%20is%20fine` | Shows the panel with the search typed in |
| `f4://copy?name=this%20is%20fine` | Copies the best match without showing the panel (beeps if nothing matches) |
| `f4://reload` | Rescans the sticker folder |
| `f4://settings` | Opens the menu bar menu under the pointer, where the options are |

`f4://copy` picks the sticker the panel would put first for that search (favourites and recents win a tie) and shows the same Copied toast. If F4 is not running, the URL starts it.

### Options

F4 has no Settings window: everything is in the menu bar menu, like [Maramao](https://github.com/kkratterf/maramao)'s.

- **Open F4** and your **Recent Stickers**.
- **Folders ▸** (New Folder…, and Rename… or Move to Trash for each folder) and **Packs ▸** (when F4 lists a pack, each one is a switch: on downloads its stickers into a folder named after it, off moves that folder to the Trash).
- **Show Starter Pack**, only if you use a sticker folder picked in a version before 0.4.3.
- **Check for Updates…** and **Quit F4**.

There is nothing else to set. The shortcut is always **fn F4** (F4 alone with standard function keys) and can't be changed. F4 adds itself to your login items on the first launch, so it is always there; macOS shows a notification, and you can still remove it in System Settings → General → Login Items.

---

## Install

F4 needs **macOS 14 Sonoma or later** and no special permissions. Pick one of the three ways below.

### 1. The DMG (drag and drop)

1. [Download the latest DMG](https://github.com/kkratterf/f4/releases/latest/download/F4.dmg) (or pick a version from the [releases](https://github.com/kkratterf/f4/releases)).
2. Open it and drag **F4** onto **Applications**.
3. Eject the disk image.

Every release also ships a plain `F4-x.y.z.zip` and a `SHA256SUMS.txt` to check the downloads (`shasum -a 256 -c SHA256SUMS.txt --ignore-missing`).

### 2. The one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/kkratterf/f4/main/install.sh | sh
```

The script downloads the latest release, checks its SHA-256, quits F4 if it is running, installs `F4.app` in `/Applications` (or `~/Applications` if `/Applications` is not writable), clears the quarantine flag and offers to open it. Read it first if you like: it is [short](install.sh).

| Variable | Effect |
| --- | --- |
| `F4_VERSION=v0.2.0` | install a specific release instead of the latest |
| `F4_INSTALL_DIR=~/Apps` | install somewhere else |
| `F4_NO_OPEN=1` | do not offer to open F4 at the end |

Variables go after the pipe: `curl -fsSL .../install.sh | F4_VERSION=v0.2.0 sh`.

### 3. Homebrew

```bash
brew tap kkratterf/f4 https://github.com/kkratterf/f4
brew install --cask f4
```

The tap lives in this repository (`Casks/f4.rb`) and is updated by every release.

### 4. First launch and Gatekeeper

F4 is not notarized by Apple yet, so the first time you open a copy from the DMG or the zip macOS says it cannot verify the developer. To open it anyway:

1. Try to open it once and close the warning.
2. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the message about F4.
3. Enter your Mac password and confirm.

Or clear the quarantine flag in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/F4.app
```

The install script does this for you. You only need to do it once per version.

### 5. Where is it?

F4 has no Dock icon. Press **F4** (**fn F4** on a Mac keyboard), or look for the F4 key in the **menu bar**, top right. It starts at login on its own (System Settings → General → Login Items to remove it).

### 6. Updating

F4 updates itself: it checks the release feed and offers the new version. You can also decline automatic checks when Sparkle first asks and install new versions by hand (drag the new DMG's app over the old one, or run the one-liner again). Your settings and your memes are kept.

With Homebrew: the cask is marked `auto_updates`, so a plain `brew upgrade` leaves F4 alone and lets the app update itself.

### 7. Uninstalling

```bash
curl -fsSL https://raw.githubusercontent.com/kkratterf/f4/main/install.sh | sh -s -- --uninstall
```

With Homebrew: `brew uninstall --cask f4`, or `brew uninstall --zap --cask f4` to remove the settings too.

The script quits F4, deletes `F4.app` and its settings (`defaults delete com.kkratterf.f4`). Your sticker folder is never touched.

### 8. Build from source

Needs macOS 14+ and Xcode 15+.

```bash
git clone https://github.com/kkratterf/f4
cd f4
swift build
swift test                      # unit tests
scripts/build-app.sh release    # builds dist/F4.app
open dist/F4.app
```

`scripts/build-dmg.sh` builds the DMG. The website has no build step: preview it with `python3 -m http.server -d site 8000`.

---

## Privacy

F4 has no analytics, no account and no server. It reads the files in your sticker folder locally and writes the one you pick to the clipboard. It goes online for three things only: the update check against the release feed on [the website](https://f4.kkratter.com/appcast.xml); downloading a link you paste or drop into the panel yourself; and downloading a pack you switch on in the menu bar's **Packs**. The update check can be turned off when Sparkle first asks.

## FAQ

**Which files does it understand?** GIF, PNG, JPEG and WebP (WhatsApp and Telegram stickers). HEIC and short videos are on the [roadmap](https://github.com/kkratterf/f4/issues).

**Where do the stickers come from?** From you: stickers you paste or drop, WhatsApp sticker packs (`.wastickers`), and the packs you switch on. F4 itself ships only openly licensed emoji and stickers drawn in code: the packs are lists of links, downloaded on your Mac when you switch them on.

**Can I change the shortcut?** No: F4 is the F4 key, fn F4 on a Mac keyboard, and it stays that way.

**F4 opens Spotlight or Launchpad instead.** On a Mac keyboard the top row are media keys first (F4 opens Spotlight or Launchpad): hold **fn** and press **F4**, or turn on **Use F1, F2, etc. keys as standard function keys** in System Settings → Keyboard → Keyboard Shortcuts → Function Keys. On most other keyboards F4 just works.

**Can a script or an AI assistant use F4?** Yes, with [`f4://` URLs](#automation-f4-urls): `open "f4://copy?name=basito"` copies a sticker from anywhere. Shortcuts actions, a command line tool and an MCP server are on the way. Facts for AI assistants live in [llms.txt](https://f4.kkratter.com/llms.txt) and the full reference in [llms-full.txt](https://f4.kkratter.com/llms-full.txt); agents that change the code read [AGENTS.md](AGENTS.md).

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the short version and [AGENTS.md](AGENTS.md) for the full rules (they are written for AI agents and humans alike). Found a bug or have an idea? [Open an issue](https://github.com/kkratterf/f4/issues/new/choose).

## Credits

- The animated emoji in the starter pack are [Noto Emoji](https://googlefonts.github.io/noto-emoji-animation/) by Google, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), downscaled for F4.
- The GIFs on the website are powered by [GIPHY](https://giphy.com) and come from the official channels of [The Office](https://giphy.com/theoffice), [Parks and Recreation](https://giphy.com/parksandrec), [NBC](https://giphy.com/nbc), [Brooklyn Nine-Nine](https://giphy.com/brooklynninenine) and [SpongeBob SquarePants](https://giphy.com/spongebob). They belong to their owners and are not part of F4.
- The logo is Stanis from [Boris](https://it.wikipedia.org/wiki/Boris_(serie_televisiva)), "F4, basito".
- Headings on the website use [Bricolage Grotesque](https://github.com/ateliertriay/bricolage) (SIL Open Font License 1.1).

## License

[MIT](LICENSE).

---

<p align="center">
  <b>Made with Claude and a face that has seen things</b>
</p>
