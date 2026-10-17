#!/bin/zsh
# Builds AngelTime.app into ./build. Pass "test" to run the unit tests instead.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --quiet
fi

if [[ "${1:-}" == "test" ]]; then
  xcodebuild -project AngelTime.xcodeproj -scheme AngelTime -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData test
  exit 0
fi

# -allowProvisioningUpdates lets Xcode create the signing certificate and profiles once a
# DEVELOPMENT_TEAM is set in project.yml. It does nothing for the default ad-hoc build.
xcodebuild -project AngelTime.xcodeproj -scheme AngelTime -configuration Release \
  -derivedDataPath build/DerivedData -allowProvisioningUpdates build

rm -rf build/AngelTime.app
cp -R build/DerivedData/Build/Products/Release/AngelTime.app build/
echo "Built $(pwd)/build/AngelTime.app"
