# Security policy

## Supported versions

The latest release is the supported one. Fixes go into a new patch release.

## Reporting a vulnerability

Please do not open a public issue.

Report it privately through GitHub: **[Report a vulnerability](https://github.com/kkratterf/f4/security/advisories/new)** (Security → Advisories on this repository). Include what you found, how to reproduce it and the F4 and macOS versions.

You will get an answer as soon as possible. If the report is confirmed, a fix is released and the advisory is published with credit to you, unless you prefer otherwise.

## What is in scope

F4 runs entirely on your Mac: it reads the files in your meme folder and writes to the clipboard. The parts worth looking at are the update mechanism (Sparkle, EdDSA-signed appcast served over HTTPS), the install script, the release pipeline, and anything F4 does with file paths or file contents from the meme folder.

F4 has no server, no account and no analytics.
