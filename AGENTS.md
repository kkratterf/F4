# AGENTS.md

Rules for AI coding agents (Claude, Codex, Copilot, Cursor, ...) and humans working on F4.
Read this file before changing anything. If a rule here conflicts with an instruction from the maintainer, the maintainer wins.

Agents that want to **use** F4 rather than change it (find out what it does, install it, explain it to someone) should read [`site/llms.txt`](site/llms.txt) and [`site/llms-full.txt`](site/llms-full.txt), also served at https://kkratterf.github.io/f4/llms.txt and https://kkratterf.github.io/f4/llms-full.txt.

## What this repo is

F4 is a native macOS app, a Spotlight-like floating panel to search a local folder of memes, GIFs and stickers and copy one to the clipboard in a keystroke. It ships as a DMG, a zip, a one-line installer and a Homebrew cask, updates itself with Sparkle, and has a website on GitHub Pages and a Raycast extension.

| Path | What it is |
| --- | --- |
| `Package.swift` | SwiftPM manifest: `F4Core` (library), `F4` (the app executable, depends on Sparkle), `F4CoreTests` |
| `Sources/F4Core` | Pure logic: file kinds (`MemeKind`), folder scan with subfolders as categories (`MemeScanner`), recents/favourites order (`MemeOrdering`), easter eggs and the Konami code (`EasterEggs`), fuzzy search (`FuzzySearch`), grid navigation (`GridNavigation`), where the panel opens and how it snaps while dragged (`PanelPlacement`), updater checks (`UpdaterConfiguration`), which keys can be the global shortcut (`ShortcutRules`). No AppKit, fully unit-tested |
| `Sources/F4/App` | App entry point (`F4App`, with the `AppDelegate`), `StatusItemController` (menu bar icon and menu), `AppUpdater` (wraps Sparkle's `SPUStandardUpdaterController`) |
| `Sources/F4/Hotkey` | `HotKeyCenter`: system-wide shortcuts with Carbon `RegisterEventHotKey` (no permissions) |
| `Sources/F4/Library` | `MemeLibrary`: the memes the panel shows, scanned in the background; `FolderWatcher` (FSEvents) rescans on changes; `UsageStore` (favourites, recents) |
| `Sources/F4/Clipboard` | `MemeClipboard`: copies the file URL + raw bytes, never an `NSImage` (keeps GIFs animated); `AutoPaster`: optional ⌘V (Accessibility) |
| `Sources/F4/Settings` | `AppSettings` (UserDefaults), `LoginItem` (`SMAppService`), `ShortcutRecorder`, `SettingsView`, `SettingsWindowController` |
| `Sources/F4/Thumbnails` | `ThumbnailCache`: ImageIO thumbnails (first GIF frame) decoded off the main thread, in an `NSCache` |
| `Sources/F4/Panel` | `FloatingPanel` (the `NSPanel`), `PanelController` (show/hide, arrow keys, Konami code), `DeckModel` (query, results, selection, arrow-key moves), `DeckView` + `MemeCell` (SwiftUI grid), `AnimatedImageView` (plays the hovered/selected GIF), `WindowDragArea` + `SnapGuideWindow` (drag the panel with snap guides), `BasitoFace` (the F4 face, drawn in code) |
| `Sources/F4/Resources` | `Localizable.xcstrings`: String Catalog, English keys with Italian translations |
| `Tests/F4CoreTests` | XCTest for `F4Core` |
| `Resources/Info.plist` | App bundle metadata: the version (`CFBundleShortVersionString`, the single source of truth for releases), `LSUIElement` (no Dock icon), the Sparkle feed (`SUFeedURL`) and public key (`SUPublicEDKey`) |
| `raycast/` | Raycast extension (TypeScript) that searches the same meme folder; built in CI with `ray build` |
| `scripts/build-app.sh` | Wraps the SwiftPM binary into `dist/F4.app` and `dist/F4-x.y.z.zip`: universal binary, icon, Sparkle framework, localizations, signature |
| `scripts/build-dmg.sh` | Builds `dist/F4-x.y.z.dmg` from `dist/F4.app`: a styled drag-to-Applications window |
| `scripts/make-icon.swift`, `scripts/make-dmg-background.swift` | Draw the app icon (the F4 keycap logo) and the DMG background in code; no image is committed |
| `scripts/check-strings.py` | CI check: every string in the String Catalog has an Italian translation |
| `scripts/update-appcast.py` | Adds a release to the Sparkle appcast (`site/appcast.xml`) |
| `site/` | The project website (static HTML and CSS, no build step), deployed to GitHub Pages; it also hosts `appcast.xml`, `llms.txt`, `llms-full.txt` and `logo.svg` (the logo, also used by the README) |
| `Casks/f4.rb` | Homebrew cask (the repo is its own tap), bumped by the release workflow |
| `install.sh` | One-line installer and uninstaller (POSIX `sh`, checked with ShellCheck) |
| `.github/workflows/ci.yml` | CI on every PR and push to `main` (see below) |
| `.github/workflows/release.yml` | Publishes a release when a version bump lands on `main` |
| `.github/workflows/pages.yml` | Deploys `site/` to GitHub Pages |
| `.github/release.yml` | How release notes are grouped by PR label |
| `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md` | Issue forms (bug, feature) and the PR template |
| `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` | User docs, the short contributor guide, how to report a vulnerability, MIT |

### How it fits together

- **At runtime.** `HotKeyCenter` fires the global shortcut → `PanelController` shows the `FloatingPanel` → `DeckView` renders `DeckModel`, whose results come from `MemeLibrary` (scanned off the main thread by `MemeScanner`, rescanned by `FolderWatcher`) filtered by `FuzzySearch` and ordered by `MemeOrdering` → Enter or a click calls `MemeClipboard`, records the meme in `UsageStore`, hides the panel, and `AutoPaster` presses ⌘V if the user turned it on.
- **Updates.** `AppUpdater` starts Sparkle only when `UpdaterConfiguration.isEnabled` says the bundle is a real `.app` with a real public key and an https feed, so `swift run` and a missing key simply hide the updater. Sparkle reads `site/appcast.xml` from GitHub Pages and checks each update against `SUPublicEDKey`.
- **Distribution.** `release.yml` builds the app, the zip and the DMG, publishes them on a GitHub Release, signs the zip for Sparkle, adds it to the appcast, bumps the cask and redeploys the site. The website's Download button links `releases/latest/download/F4.dmg`, so it always serves the newest stable DMG with no site change.

## Language of the project

Code, comments, doc comments, commit messages, issues, PR titles and PR descriptions: **English**. The app UI is English with an Italian translation, used when macOS runs in Italian. Release-note section titles (`.github/release.yml`) and the easter-egg banners are in Italian on purpose.

## Build and test

Needs macOS 14+ and Xcode 15+ (Swift 5.9). These mirror CI (`.github/workflows/ci.yml`):

```bash
swift build
swift test
scripts/build-app.sh release   # dist/F4.app and dist/F4-x.y.z.zip
scripts/build-dmg.sh           # dist/F4-x.y.z.dmg
open dist/F4.app
```

Without a Mac (for example in a Linux container) nothing Swift builds: edit carefully, push, and let CI build it. The Python and shell parts run anywhere:

```bash
python3 scripts/check-strings.py
shellcheck scripts/*.sh && shellcheck --shell=sh install.sh
python3 -m http.server -d site 8000   # preview the website at http://localhost:8000
```

### What CI checks

| Job | Runs on | Checks |
| --- | --- | --- |
| Build and test | macOS | `swift build`, `swift test`, builds `F4.app` and checks it (universal binary, signature, `LSUIElement`, Italian strings, icon, Sparkle framework and rpath, launches and stays up for 8 seconds), builds the DMG and mounts it to check the layout. Uploads the zip and the DMG as artifacts |
| Lint scripts | Linux | ShellCheck on `scripts/*.sh` and `install.sh`, `check-strings.py`, a round trip of `update-appcast.py` |
| Raycast extension | Linux | `npm ci` and `ray build` in `raycast/` |
| Homebrew cask | macOS | `brew style` and an offline `brew audit --strict` of `Casks/f4.rb` |

## Rules for changes

- **CI must be green** before a PR is ready. Never skip, delete or weaken a test to get green.
- Logic that does not need AppKit goes in `F4Core` and ships with tests.
- **The panel must open instantly.** Never block the main thread: folder scans, thumbnail decoding and file reads run in the background. Do not animate every GIF in the grid.
- **Never put an `NSImage` on the pasteboard to copy a meme**: it flattens GIFs to a single frame. Write the file URL (`public.file-url`) and the raw file data under its UTI, so Slack, Discord and Telegram paste the animated GIF.
- The app works **without** Accessibility, Input Monitoring or Screen Recording permissions. Global shortcuts use Carbon `RegisterEventHotKey`, not `NSEvent.addGlobalMonitorForEvents`. An optional feature that needs a permission degrades gracefully without it.
- **No network requests** other than Sparkle's update check. No analytics, no telemetry, no account. The README, the site and `llms.txt` promise this.
- **The logo is an F4 keycap**, the default shortcut. `scripts/make-icon.swift` (app icon) and `site/logo.svg` share the same geometry; change them together, then regenerate `site/og.png` and `raycast/assets/icon.png` from the SVG. The menu bar icon is the same key, drawn as a template image in `StatusItemController`.
- **The default shortcut is F4 alone.** A function key can be a shortcut without modifiers; any other key needs ⌘, ⌥ or ⌃ (`ShortcutRules`). On Mac keyboards F4 needs fn unless the user turned on standard function keys: every place that names the shortcut says so.
- **Every new UI string needs an Italian translation** in `Sources/F4/Resources/Localizable.xcstrings` (String Catalog, English source). SwiftUI literals (`Text("…")`, `Button("…")`) are looked up automatically; a plain `String` shown to the user must use `String(localized: "…")`; a ternary of literals needs `LocalizedStringKey(...)`. Text that must never be translated uses `Text(verbatim:)`. CI runs `scripts/check-strings.py`.
- **No copyrighted stills, memes or GIFs in the repo**, not even for the basito face, the icon or the website: draw them in code. Users bring their own memes (and their own `.basito.png`).
- **The website may show real memes, but never from the repo.** It links GIFs from the shows' official channels on GIPHY (`media.giphy.com/media/<id>/...`), each one linked to its GIPHY page, with the credit line in the footer kept up to date. Never from fan uploads, never a GIF downloaded into `site/`. The one exception is the site favicon (`favicon.ico`, `favicon-32.png`, `apple-touch-icon.png`): the real "F4, basito" still, committed on the maintainer's explicit request; the app icon and the panel face stay drawn in code. A missing GIF must leave a coloured tile, not a broken layout.
- Keep PRs small and focused: one issue, one PR. Do not mix refactors with behaviour changes.
- No third-party dependencies without a reason written in the PR description (and in a comment in `Package.swift`, as for Sparkle).
- Match the style of the surrounding code.
- **Keep the docs true.** A change users can see updates, in the same PR, every place that describes it: `README.md`, `site/index.html`, `site/llms.txt` and `site/llms-full.txt` (and `raycast/README.md` for the extension). A change to how the repo works (paths, scripts, workflows, rules) updates this file.

### Recipes

- **A new UI string:** write it in English in the code, add the key and its Italian translation to `Localizable.xcstrings`, run `python3 scripts/check-strings.py`.
- **A new setting:** a `Key` and a `@Published` property in `AppSettings` (stored in `UserDefaults`), a control in `SettingsView`, strings translated, the setting listed in the README "Settings" section and in `llms-full.txt`.
- **A new file type:** a case in `MemeKind` (extension → UTI), tests in `Tests/F4CoreTests`, check that `ThumbnailCache` can decode it and `MemeClipboard` writes it under the right UTI, then update the supported types in the Settings caption, the README, the site FAQ and both `llms` files.
- **A new easter egg:** an entry in the table in `EasterEggs.swift` (the key is matched after normalisation), a test, and, if it has a new effect, the effect in the panel. The docs only say easter eggs exist; do not list them.
- **The website:** edit `site/` directly (a new GIF follows the GIPHY rule above); `pages.yml` deploys it when the PR lands. Keep the `og:`/`twitter:` tags, the JSON-LD and `sitemap.xml` consistent with any change of title, URL or description. Never edit `site/appcast.xml` by hand: the release workflow owns it.
- **The release pipeline:** a change to `release.yml` is checked with a dry run (Actions → Release → Run workflow → `dry_run`) before it is relied on.

## Docs, roadmap and planning

- **Do not commit docs, roadmaps, plans, audits, reports or design notes to this repo.** No `ROADMAP.md`, `PLAN.md`, `docs/`, `notes/`. The roadmap lives outside the repo.
- Allowed documentation: `README.md` and `raycast/README.md` (user-facing usage only), `CONTRIBUTING.md`, `SECURITY.md`, the GitHub issue and pull request templates, the website in `site/` (including `llms.txt` and `llms-full.txt`), code comments, and this file plus `CLAUDE.md`.
- **Backlog = GitHub issues only.** No GitHub Projects, no milestones. Every issue carries labels:
  - area: `app`, `library`, `ecosystem`, `ci`, `bug`
  - priority: `P0` (must have for the version), `P1` (should have), `P2` (nice to have)
  - version: `v0.1`, `v0.2`, `v0.3`, ...
- Before opening an issue, search for duplicates. Reference the issue from the PR (`Closes #N`).

## Naming conventions

### Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`

- Summary in English, imperative mood, lower case, no trailing period, ≤ 72 characters.
- Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs` (README, `AGENTS.md`, comments, `llms` files), `ci`, `build`, `chore`, `revert`.
- Scopes: `core`, `app`, `panel`, `hotkey`, `grid`, `search`, `library` (folder scan and watch), `thumbnails`, `clipboard`, `settings`, `updater`, `site`, `raycast`, `ci`, `release`.
- Breaking changes: `feat(core)!: ...` plus a `BREAKING CHANGE:` footer.
- Body explains *why*, wrapped at 72 columns.

Examples: `feat(panel): float over full-screen apps`, `fix(clipboard): keep the gif animation in slack`, `ci: upload the app bundle`.

### Pull requests

- **Title = a Conventional Commit line** (same format as above). Squash merge, so the title becomes the commit on `main`.
- Description: what changed, why, how it was tested, and `Closes #N`, following `.github/pull_request_template.md`. A screen recording for anything visual.
- Add the matching **area label** (`app`, `library`, `ecosystem`, `bug`, `ci`) and the version label. Release notes are grouped by area label (`.github/release.yml`); use `skip-changelog` for changes users don't care about (docs, CI, release bumps).
- Open as draft while CI is red or work is incomplete.

### Branches

`type/short-kebab-description`, e.g. `feat/floating-panel`, `fix/gif-paste-slack`.
Agent platforms that assign their own branch names (e.g. `claude/...`) are fine; the PR title carries the convention.

## Releases

- SemVer, tags `vX.Y.Z`. Release titles are the tag alone (`v0.2.0`), never "F4 v0.2.0".
- Minor release = a version label, cut when all `P0` issues of that version are closed and `main` is green. Patch release when a user-facing fix lands.
- **Releasing = merging a version bump.** `CFBundleShortVersionString` in `Resources/Info.plist` is the only version in the repo (`build-app.sh` sets `CFBundleVersion` from it, the cask is bumped by the workflow). A version with a suffix (`0.3.0-beta.1`) becomes a pre-release, which gets no appcast entry and no cask bump.
- **No `CHANGELOG.md`.** The changelog lives only in GitHub Release notes, generated from PR titles and grouped by label.

### How to cut a release (agents can do all of it)

1. Check that every `P0` issue of the version is closed and the last CI run on `main` is green.
2. Optional, after a change to the pipeline: run `release.yml` by hand with `dry_run` and read its summary and artifact.
3. Open a PR `chore(release): vX.Y.Z` that **only** changes `CFBundleShortVersionString` in `Resources/Info.plist`. Labels: `ci`, `skip-changelog`, the version label. It closes the version's release issue if there is one.
4. Merge it when CI is green. On `main`, `release.yml` then runs on its own: it skips if the tag exists, otherwise tests, builds, and publishes the tag `vX.Y.Z` with `F4-X.Y.Z.zip`, `F4-X.Y.Z.dmg`, `F4.dmg` (the same DMG under the fixed name the website links) and `SHA256SUMS.txt`; signs the zip with `SPARKLE_ED_PRIVATE_KEY`; commits the appcast entry and the cask bump to `main`; redeploys the site.
5. Check the result: the release page, `https://github.com/kkratterf/f4/releases/latest/download/F4.dmg`, the new `<item>` in `https://kkratterf.github.io/f4/appcast.xml`, and `version` in `Casks/f4.rb`.
6. If the run fails before the GitHub Release is created, nothing was tagged: fix the cause in a PR, then run `release.yml` by hand (`workflow_dispatch`). If it fails after (pushing the appcast and the cask), the release is out and a re-run would stop at the tag check: land the appcast entry (`scripts/update-appcast.py` with the signature from the run's log) and the cask bump in a PR. Never delete or move a published tag.

Updates reach users through Sparkle: the public half of the signing key is `SUPublicEDKey` in `Resources/Info.plist` and must match the `SPARKLE_ED_PRIVATE_KEY` secret. Never change the public key: every installed copy would reject the next update. Without the secret the workflow warns and the app simply does not update.

## Merging

- Agents may push branches, open PRs and merge their own PRs once CI is green and the PR closes its issue(s). Agents never push directly to `main`, force-push `main`, or bypass a failing check. The maintainer is told about releases, not about every merge.
- Never rewrite history on someone else's branch.

## What only the maintainer does

Agents cannot do these, so they ask the maintainer once and carry on with the rest:

- Repository settings: the About description and topics, GitHub Pages source, branch protection, labels' existence.
- Secrets: `SPARKLE_ED_PRIVATE_KEY` today; an Apple Developer ID certificate and notarization credentials when F4 gets notarized. Never write a secret, a private key or a token into the repo, an issue, a PR or a log.
- Editing or deleting a published GitHub Release by hand.
- Store submissions under the maintainer's account, such as the Raycast Store.
