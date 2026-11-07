#!/bin/bash
# testflight_upload.sh - archive the tvOS app and upload it to App Store Connect for
# TestFlight. Only on the owner's request for that upload.
#
#   scripts/testflight_upload.sh <build>   # higher than any build uploaded for this version
#
# Sets CURRENT_PROJECT_VERSION, archives Release for generic tvOS, then exports with method app-store-connect /
# destination upload and automatic signing, through the Apple account signed in to Xcode
# (Settings > Accounts). Output under ~/DevTemp/newtube. Commit the project file after.
set -uo pipefail
BUILD="${1:?usage: scripts/testflight_upload.sh <build number>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$HOME/DevTemp/newtube"
OUT="$D/scratch/testflight"
PROJECT="$ROOT/NewTubeApp/NewTubeApp.xcodeproj/project.xcproj"
mkdir -p "$OUT" "$D/logs"

sed -i '' -E "s/\"CURRENT_PROJECT_VERSION\": \"[0-9]+\"/\"CURRENT_PROJECT_VERSION\": \"$BUILD\"/" "$PROJECT"
VERSION=$(sed -nE 's/.*"MARKETING_VERSION": "([0-9.]+)".*/\1/p' "$PROJECT" | head -1)
TEAM=$(sed -nE 's/.*"DEVELOPMENT_TEAM": "([A-Z0-9]+)".*/\1/p' "$PROJECT" | head -1)

ARCHIVE="$OUT/NewTube-$VERSION-$BUILD.xcarchive"
rm -rf "$ARCHIVE" "$OUT/export-$BUILD"
echo "archiving $VERSION ($BUILD)..."
/usr/bin/xcodebuild -workspace "$ROOT/NewTube.xcworkspace" -scheme "NewTube" -configuration Release \
    -destination 'generic/platform=tvOS' -derivedDataPath "$D/derived-data/archive" \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates archive >"$D/logs/archive-$BUILD.log" 2>&1 \
    || { grep -E 'error:' "$D/logs/archive-$BUILD.log" | head -8; echo "archive failed: $D/logs/archive-$BUILD.log" >&2; exit 1; }
got=$(/usr/libexec/PlistBuddy -c 'Print ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist")
[ "$got" = "$BUILD" ] || { echo "the archive is build $got, not $BUILD" >&2; exit 1; }

cat >"$OUT/export_options.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>$TEAM</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "uploading $VERSION ($BUILD) to App Store Connect..."
/usr/bin/xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/export_options.plist" \
    -exportPath "$OUT/export-$BUILD" -allowProvisioningUpdates >"$D/logs/upload-$BUILD.log" 2>&1
rc=$?
grep -E 'Upload succeeded|error|Error' "$D/logs/upload-$BUILD.log" | head -8
[ $rc -eq 0 ] && grep -q 'Upload succeeded' "$D/logs/upload-$BUILD.log" || { echo "upload failed: $D/logs/upload-$BUILD.log" >&2; exit 1; }
echo "$VERSION ($BUILD) uploaded; commit $PROJECT"
