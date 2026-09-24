#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?This script is intended for GitHub Actions}"
: "${FLUTTER_REVISION:?A pinned Flutter revision is required}"
: "${FLUTTER_VERSION:?A pinned Flutter release tag is required}"
: "${GITHUB_PATH:?GitHub Actions environment is required}"

sdk_path="$RUNNER_TEMP/flutter-sdk"
git init "$sdk_path"
git -C "$sdk_path" remote add origin https://github.com/flutter/flutter.git
git -C "$sdk_path" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION"
git -C "$sdk_path" checkout --detach "refs/tags/$FLUTTER_VERSION"
test "$(git -C "$sdk_path" rev-parse HEAD)" = "$FLUTTER_REVISION"
printf '%s\n' "$sdk_path/bin" >> "$GITHUB_PATH"
export PATH="$sdk_path/bin:$PATH"
flutter config --no-analytics
flutter --version
