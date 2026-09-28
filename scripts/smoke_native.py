"""Run guest-only native UI checks using an available iPhone simulator."""
import json
import subprocess
from pathlib import Path

def run(*args):
    return subprocess.check_output(args, text=True)

inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
devices = [device for runtime, items in inventory["devices"].items() if "iOS-26" in runtime
           for device in items if device["name"].startswith("iPhone") and device.get("isAvailable")]
if not devices:
    raise SystemExit("An iOS 26 iPhone simulator is required for UI verification.")
device = devices[0]["udid"]
output = Path("artifacts/native-ui")
output.mkdir(parents=True, exist_ok=True)
result = output / "Launch.xcresult"
test = subprocess.run(["xcodebuild", "test", "-project", "native/TiebaLite.xcodeproj", "-scheme", "TiebaLite",
                "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={device}",
                "-derivedDataPath", "native/simulator-build", "-resultBundlePath", str(result),
                "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-"])
subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                "--output-path", str(output / "screenshots")], check=False)
summary = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)], capture_output=True, text=True)
(output / "summary.json").write_text(summary.stdout or summary.stderr)
raise SystemExit(test.returncode)
