#!/usr/bin/env bash
# ==============================================================================
# Packager for Calendar & Notification Center Applet for KDE Plasma 6
# Produces: org.kde.plasma.calendarnotifications.plasmoid
# ==============================================================================

set -e

APPLET_ID="org.kde.plasma.calendarnotifications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/${APPLET_ID}.plasmoid"

echo "==> Packaging ${APPLET_ID} into ${OUTPUT_FILE}..."

# Ensure backend scripts are executable
chmod +x "${SCRIPT_DIR}/contents/scripts/"*.sh 2>/dev/null || true

# Remove old bundle if exists
rm -f "${OUTPUT_FILE}"

cd "${SCRIPT_DIR}"

# Create zip bundle matching KDE Plasma 6 Plasmoid specification
zip -r "${OUTPUT_FILE}" \
    metadata.json \
    contents/ \
    -x "*.git*" "*.DS_Store*" "*__pycache__*" "*.swp" "metadata.desktop"

echo "✅ Package created successfully: ${OUTPUT_FILE} ($(du -h "${OUTPUT_FILE}" | cut -f1))"
