# Contributing to F4

Thanks for being here. F4 is a small app with a simple promise: find a meme in a keystroke, paste it without losing the animation. Anything that keeps that promise is welcome.

## Report a bug or ask for a feature

[Open an issue](https://github.com/kkratterf/f4/issues/new/choose). There are forms for bugs and ideas. For a bug, the macOS version, the app you pasted into and a screen recording help more than anything else. Search the [open issues](https://github.com/kkratterf/f4/issues) first: the backlog lives there, labelled by area, priority and version.

## Build it

Needs macOS 14 Sonoma or later and Xcode 15+ (Swift 5.9).

```bash
git clone https://github.com/kkratterf/f4
cd f4
swift build
swift test
scripts/build-app.sh release   # dist/F4.app
open dist/F4.app
```

The website is plain HTML and CSS in `site/`: `python3 -m http.server -d site 8000`.

## Open a pull request

- One issue, one pull request. Keep it small; do not mix a refactor with a change in behaviour.
- The title is a [Conventional Commit](https://www.conventionalcommits.org/) line, e.g. `fix(clipboard): keep the gif animation in slack`.
- The description says what changed, why, and how you tested it, and closes the issue (`Closes #N`). Add a screen recording for anything visual.
- CI must be green. Never skip, delete or weaken a test to get there.
- Logic that does not need AppKit goes in `Sources/F4Core` with tests.
- Every new user-facing string needs its Italian translation in `Sources/F4/Resources/Localizable.xcstrings`; CI checks it.
- No copyrighted memes, stills or GIFs in the repository, not even for the basito face: draw it in code.

The full rules, including the ones about the panel staying instant and the app needing no permissions, are in [AGENTS.md](AGENTS.md). It is written for AI coding agents and humans alike, so read it before a bigger change.

## Security

Found a vulnerability? Please do not open a public issue: see [SECURITY.md](SECURITY.md).
