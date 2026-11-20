"""Structural validation runnable without Xcode; it is not a Swift compiler."""
from pathlib import Path
import json
import plistlib
import struct
import sys

root = Path(__file__).resolve().parents[1]
errors = []

for path in root.glob("App/Resources/*.plist"):
    try:
        with path.open("rb") as source:
            plistlib.load(source)
    except Exception as error:
        errors.append(f"{path.name}: {error}")

with (root / "App/Resources/PrivacyInfo.xcprivacy").open("rb") as source:
    privacy = plistlib.load(source)
assert privacy["NSPrivacyTracking"] is False

for path in root.glob("App/Resources/Assets.xcassets/**/Contents.json"):
    try:
        contents = json.loads(path.read_text())
        for image in contents.get("images", []):
            if "filename" in image and not (path.parent / image["filename"]).exists():
                errors.append(f"Missing asset {image['filename']}")
    except Exception as error:
        errors.append(f"{path}: {error}")

icon = root / "App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
if icon.exists():
    content = icon.read_bytes()
    if content[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", content[16:24]) != (1024, 1024):
        errors.append("App icon must be a 1024x1024 PNG")

info = plistlib.loads((root / "App/Resources/Info.plist").read_bytes())
if not info.get("NSLocationWhenInUseUsageDescription"):
    errors.append("Location purpose string is missing")
if "NSLocationAlwaysAndWhenInUseUsageDescription" in info or "UIBackgroundModes" in info:
    errors.append("App must not request background location")

for required in ["project.yml", ".github/workflows/ios.yml", "README.md", "App/NearbyPharmacyApp.swift"]:
    if not (root / required).is_file():
        errors.append(f"Missing {required}")

swift_files = list(root.glob("App/**/*.swift"))
test_count = sum(path.read_text(encoding="utf-8").count("func test") for path in root.glob("Tests/*.swift"))
ui_count = sum(path.read_text(encoding="utf-8").count("func test") for path in root.glob("UITests/*.swift"))
if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"Structure OK: {len(swift_files)} Swift source files, {test_count} unit tests, {ui_count} UI tests.")
print("Swift compilation, simulator execution, and live MapKit search require macOS/Xcode.")
