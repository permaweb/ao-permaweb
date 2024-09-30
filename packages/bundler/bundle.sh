#!/bin/bash

set -e

# Define the target file
TARGET_FILE="./dist/bundle-trusted.lua"

# Clear the target file if it exists
> "$TARGET_FILE"

# Array of files to bundle
FILES=(
    "./apm_client.lua"
    "./trusted.lua"
    "../kv/base/src/kv.lua"
    "../kv/batchplugin/src/batch.lua"
    "../asset-manager/asset-manager.lua"
    "../zone/src/zone.lua"
)

# Array of corresponding package names
PACKAGE_NAMES=(
    ""
    ""
    "@permaweb/kv-base"
    "@permaweb/kv-batch"
    "@permaweb/asset-manager"
    "@permaweb/zone"
)

# Function to print headers
print_header() {
    HEADER="$1"
    WIDTH=80
    BORDER=$(printf '%*s' "$WIDTH" '' | tr ' ' '=')

    echo ""
    echo ""
    echo "-- $BORDER"
    echo "-- $BORDER"
    echo "-- $HEADER"
    echo "-- $BORDER"
    echo "-- $BORDER"
}

# Append each file's content to the target file
for i in "${!FILES[@]}"; do
    echo "Processing file: $FILE"

    FILE="${FILES[$i]}"
    PACKAGE_NAME="${PACKAGE_NAMES[$i]}"

    if [[ "$FILE" == *"apm"* ]] || [[ "$FILE" == *"trusted"* ]]; then
        cat "$FILE" >> "$TARGET_FILE"
        continue
    fi

    if [ -f "$FILE" ]; then
        FILE_NAME=$(basename "$FILE" .lua)
        FUNCTION_NAME="load_${FILE_NAME//-/_}"

        # Add header to target file if a package name is provided
        if [ -n "$PACKAGE_NAME" ]; then
            print_header "$PACKAGE_NAME" >> "$TARGET_FILE"
        fi

        echo "local function $FUNCTION_NAME()" >> "$TARGET_FILE"
        cat "$FILE" >> "$TARGET_FILE"
        echo "end" >> "$TARGET_FILE"
        echo "package.loaded['$PACKAGE_NAME'] = $FUNCTION_NAME()" >> "$TARGET_FILE"
        echo "" >> "$TARGET_FILE"  # Add a newline for separation
    else
        echo "File '$FILE' does not exist."
    fi
done

echo "Bundling complete. Output written to $TARGET_FILE."
