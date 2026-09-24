#!/usr/bin/env python3
"""Merge strings extracted by the compiler (*.stringsdata in DerivedData) into
Shared/Resources/Localizable.xcstrings. Run after a build:
    python3 scripts/update-strings.py build/DD
"""
import glob, json, os, sys

root = sys.argv[1] if len(sys.argv) > 1 else "build/DD"
catalog_path = "Shared/Resources/Localizable.xcstrings"
catalog = json.load(open(catalog_path))
strings = catalog.setdefault("strings", {})
found = set()
for path in glob.glob(os.path.join(root, "**/Foundry*.build/**/*.stringsdata"), recursive=True):
    data = json.load(open(path))
    for entry in data.get("tables", {}).get("Localizable", []):
        found.add(entry["key"])
for key in sorted(found):
    strings.setdefault(key, {"extractionState": "extracted_with_value", "localizations": {
        "en": {"stringUnit": {"state": "new", "value": key}}}})
catalog["sourceLanguage"] = "en"
catalog["version"] = "1.0"
json.dump(catalog, open(catalog_path, "w"), indent=2, ensure_ascii=False, sort_keys=True)
print(f"{len(found)} strings in catalog")
