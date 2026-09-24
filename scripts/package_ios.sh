#!/usr/bin/env bash
set -euo pipefail

app_path="build/ios/iphoneos/Runner.app"
test -d "$app_path"
test -f "$app_path/Runner"
test -f "$app_path/Frameworks/App.framework/App"
test -f "$app_path/Frameworks/Flutter.framework/Flutter"
xcrun lipo -archs "$app_path/Runner" | tr ' ' '\n' | grep -qx arm64
test "$(/usr/libexec/PlistBuddy -c 'Print :DTPlatformName' "$app_path/Info.plist")" = iphoneos

# A unique staging directory avoids touching any other build artifacts.
stage_path="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/tblite-ipa.XXXXXX")"
mkdir -p "$stage_path/Payload" artifacts
ditto "$app_path" "$stage_path/Payload/Runner.app"
(cd "$stage_path" && /usr/bin/zip -qry "$OLDPWD/artifacts/TiebaLite-unsigned.ipa" Payload)
python3 scripts/verify_ipa.py artifacts/TiebaLite-unsigned.ipa
(cd artifacts && shasum -a 256 TiebaLite-unsigned.ipa > SHA256SUMS)
python3 - <<'PY'
import json
import os
import subprocess
from pathlib import Path

def output(*args):
    return subprocess.check_output(args, text=True).strip()

info = {
    "source_commit": output("git", "rev-parse", "HEAD"),
    "flutter_revision": os.environ["FLUTTER_REVISION"],
    "xcode": output("xcodebuild", "-version"),
    "run_id": os.environ.get("GITHUB_RUN_ID"),
    "run_number": os.environ.get("GITHUB_RUN_NUMBER"),
    "signing": "unsigned; re-sign locally using Sideloadly",
    "validation": "device build and IPA structure only; live feature acceptance is separate",
}
Path("artifacts/build-info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
PY
