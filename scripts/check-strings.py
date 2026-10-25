#!/usr/bin/env python3
"""Checks that every UI string in Sources/F4 has an Italian translation.

Finds the literals of String(localized:), LocalizedStringKey(...) and the
SwiftUI views that localize their first argument (Text, Button, Toggle, ...),
turns interpolations into %@ like Xcode does, and fails when one is missing
from the String Catalog or has no Italian value. Text(verbatim:) is skipped.
"""
import glob
import json
import re
import sys

CATALOG = "Sources/F4/Resources/Localizable.xcstrings"
PATTERN = re.compile(
    r'(?:String\(localized: |LocalizedStringKey\(|\bText\(|\bButton\(|\bToggle\(|\bSection\('
    r'|\bLabeledContent\(|\bTextField\(|\.accessibilityLabel\(|\.help\(|ContentUnavailableView\(\s*)'
    r'"((?:[^"\\]|\\.)*)"'
)

strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]
errors = []
for path in sorted(glob.glob("Sources/F4/**/*.swift", recursive=True)):
    source = open(path, encoding="utf-8").read()
    for match in PATTERN.finditer(source):
        key = re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "%@", match.group(1))
        if not re.search(r"[A-Za-z]", key):
            continue
        line = source.count("\n", 0, match.start()) + 1
        entry = strings.get(key)
        italian = (entry or {}).get("localizations", {}).get("it", {}).get("stringUnit", {}).get("value")
        if not italian:
            errors.append(f"{path}:{line}: no Italian translation for {key!r}")

for error in errors:
    print(f"::error::{error}" if "GITHUB_ACTIONS" in __import__("os").environ else error)
if errors:
    sys.exit(1)
print(f"String Catalog OK ({len(strings)} strings)")
