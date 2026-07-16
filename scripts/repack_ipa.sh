#!/bin/bash

# CareSync IPA Repackaging Utility 🛠️
#
# Updates the bundled .env configuration inside a precompiled iOS IPA archive
# with the active local .env values from the project root.

set -e

IPA_PATH="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify input argument
if [ -z "$IPA_PATH" ]; then
  echo "Error: No IPA path provided."
  echo "Usage: $0 <path_to_downloaded_ipa>"
  exit 1
fi

# Resolve absolute path of IPA
if [[ "$IPA_PATH" = /* ]]; then
  ABS_IPA_PATH="$IPA_PATH"
else
  ABS_IPA_PATH="$(pwd)/$IPA_PATH"
fi

if [ ! -f "$ABS_IPA_PATH" ]; then
  echo "Error: IPA file not found at '$ABS_IPA_PATH'"
  exit 1
fi

# Verify local .env exists
ENV_PATH="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_PATH" ]; then
  echo "Error: Local .env configuration file not found at '$ENV_PATH'"
  exit 1
fi

echo "Updating configuration for: $ABS_IPA_PATH"
echo "Using local configuration: $ENV_PATH"

# Create a clean temporary staging directory
STAGING_DIR="$(mktemp -d)"

# Replicate the bundle folder structure used by Flutter assets
ASSETS_DIR="$STAGING_DIR/Payload/Runner.app/Frameworks/App.framework/flutter_assets"
mkdir -p "$ASSETS_DIR"

# Copy local .env config
cp "$ENV_PATH" "$ASSETS_DIR/.env"

# Run zip update from staging root
cd "$STAGING_DIR"
zip -u "$ABS_IPA_PATH" Payload/Runner.app/Frameworks/App.framework/flutter_assets/.env > /dev/null

# Cleanup
rm -rf "$STAGING_DIR"

echo "Done! The IPA has been successfully repacked with your local environment variables."
echo "You can now sideload it using Sideloadly."
