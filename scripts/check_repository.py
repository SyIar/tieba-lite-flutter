"""Check source language, localization parity and tracked credential material."""

import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
paths = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard"], cwd=root, text=True).splitlines()
errors = []
han = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
for name in sorted(set(paths)):
    path = root / name
    if not path.is_file():
        continue
    if path.suffix.lower() in {".p12", ".mobileprovision", ".ipa", ".key"}:
        errors.append(f"Do not commit signing material or binaries: {name}")
    try:
        content = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    localized = name in {"lib/l10n/app_zh.arb", "assets/l10n/emoticons_zh.arb"}
    if path.suffix.lower() not in {".md", ".sql"} and not localized and han.search(content):
        errors.append(f"Non-English source outside approved localization: {name}")

locales = [json.loads((root / f"lib/l10n/app_{locale}.arb").read_text(encoding="utf-8")) for locale in ("en", "zh")]
keys = [{key for key in locale if not key.startswith("@")} for locale in locales]
if keys[0] != keys[1]:
    errors.append(f"Localization key mismatch: {sorted(keys[0] ^ keys[1])}")
if errors:
    raise SystemExit("\n".join(errors))
print("Source language and localization checks passed.")
