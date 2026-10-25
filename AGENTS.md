# AGENTS.md

Rules for AI coding agents (Claude, Codex, Copilot, Cursor, ...) and humans working on F4.
Read this file before changing anything. If a rule here conflicts with an instruction from the maintainer, the maintainer wins.

## What this repo is

F4 is a native macOS app, a Spotlight-like floating panel to search a local folder of memes, GIFs and stickers and copy one to the clipboard in a keystroke.

| Path | What it is |
| --- | --- |
| `Sources/F4Core` | Pure logic: file kinds, folder scan, fuzzy search (`FuzzySearch`), grid navigation. No AppKit, fully unit-tested |
| `Sources/F4/App` | App entry point, `AppDelegate` |
| `Sources/F4/Hotkey` | `HotKeyCenter`: system-wide shortcuts with Carbon `RegisterEventHotKey` (no permissions) |
| `Sources/F4/Library` | `MemeLibrary`: the memes the panel shows, scanned in the background; `FolderWatcher` rescans on changes |
| `Sources/F4/Clipboard` | `MemeClipboard`: copies the file URL + raw bytes, never an `NSImage` (keeps GIFs animated) |
| `Sources/F4/Thumbnails` | `ThumbnailCache`: ImageIO thumbnails (first GIF frame) decoded off the main thread, in an `NSCache` |
| `Sources/F4/Panel` | `FloatingPanel` (the `NSPanel`), `PanelController` (show/hide), `DeckModel` (query, results, selection, arrow-key moves), `DeckView` + `MemeCell` (SwiftUI grid) |
| `Tests/F4CoreTests` | XCTest for `F4Core` |
| `Resources/Info.plist` | App bundle metadata, including the version and `LSUIElement` (no Dock icon) |
| `scripts/build-app.sh` | Wraps the SwiftPM binary into `dist/F4.app` and a zip |

## Language of the project

Code, comments, doc comments, commit messages, issues, PR titles and PR descriptions: **English**.

## Build and test

Needs macOS 14+ and Xcode 15+ (Swift 5.9). These mirror CI (`.github/workflows/ci.yml`):

```bash
swift build
swift test
scripts/build-app.sh release   # dist/F4.app
open dist/F4.app
```

## Rules for changes

- **CI must be green** before a PR is ready. Never skip, delete or weaken a test to get green.
- Logic that does not need AppKit goes in `F4Core` and ships with tests.
- **The panel must open instantly.** Never block the main thread: folder scans, thumbnail decoding and file reads run in the background. Do not animate every GIF in the grid.
- **Never put an `NSImage` on the pasteboard to copy a meme**: it flattens GIFs to a single frame. Write the file URL (`public.file-url`) and the raw file data under its UTI, so Slack, Discord and Telegram paste the animated GIF.
- The app works **without** Accessibility, Input Monitoring or Screen Recording permissions. Global shortcuts use Carbon `RegisterEventHotKey`, not `NSEvent.addGlobalMonitorForEvents`. An optional feature that needs a permission degrades gracefully without it.
- Keep PRs small and focused: one issue, one PR. Do not mix refactors with behaviour changes.
- No third-party dependencies without a reason written in the PR description.
- Match the style of the surrounding code.

## Docs, roadmap and planning

- **Do not commit docs, roadmaps, plans, audits, reports or design notes to this repo.** No `ROADMAP.md`, `PLAN.md`, `docs/`, `notes/`. The roadmap lives outside the repo.
- Allowed documentation: `README.md` (user-facing usage only), code comments, and this file plus `CLAUDE.md`.
- **Backlog = GitHub issues only.** No GitHub Projects, no milestones. Every issue carries labels:
  - area: `app`, `library`, `ecosystem`, `ci`, `bug`
  - priority: `P0`, `P1`, `P2`
  - version: `v0.1`, `v0.2`, `v0.3`, ...
- Before opening an issue, search for duplicates. Reference the issue from the PR (`Closes #N`).

## Naming conventions

### Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`

- Summary in English, imperative mood, lower case, no trailing period, ≤ 72 characters.
- Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs` (README/comments only), `ci`, `build`, `chore`, `revert`.
- Scopes: `core`, `app`, `panel`, `hotkey`, `grid`, `search`, `library` (folder scan and watch), `thumbnails`, `clipboard`, `settings`, `raycast`, `ci`, `release`.
- Breaking changes: `feat(core)!: ...` plus a `BREAKING CHANGE:` footer.
- Body explains *why*, wrapped at 72 columns.

Examples: `feat(panel): float over full-screen apps`, `fix(clipboard): keep the gif animation in slack`, `ci: upload the app bundle`.

### Pull requests

- **Title = a Conventional Commit line** (same format as above). Squash merge, so the title becomes the commit on `main`.
- Description: what changed, why, how it was tested, and `Closes #N`. A screen recording for anything visual.
- Add the matching **area label** (`app`, `library`, `ecosystem`, `bug`, `ci`). Release notes are grouped by these labels (`.github/release.yml`); use `skip-changelog` for changes users don't care about.
- Open as draft while CI is red or work is incomplete.

### Branches

`type/short-kebab-description`, e.g. `feat/floating-panel`, `fix/gif-paste-slack`.
Agent platforms that assign their own branch names (e.g. `claude/...`) are fine; the PR title carries the convention.

## Releases

- SemVer, tags `vX.Y.Z`.
- Minor release = a version label, cut when all `P0` issues of that version are closed and `main` is green. Patch release when a user-facing fix lands.
- First a version-bump PR (`chore(release): vX.Y.Z`) that updates `CFBundleShortVersionString` and bumps `CFBundleVersion` in `Resources/Info.plist`.
- **No `CHANGELOG.md`.** The changelog lives only in GitHub Release notes.

## Merging

- Agents may push branches, open PRs and merge their own PRs once CI is green and the PR closes its issue(s). Agents never push directly to `main`, force-push `main`, or bypass a failing check. The maintainer is told about releases, not about every merge.
- Never rewrite history on someone else's branch.
