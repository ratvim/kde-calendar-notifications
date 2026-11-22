#!/usr/bin/env bash
# ==============================================================================
# Installer for Calendar & Notification Center Applet for KDE Plasma 6
# Package: org.kde.plasma.calendarnotifications
# ==============================================================================

set -e

APPLET_ID="org.kde.plasma.calendarnotifications"
INSTALL_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Calendar & Notification Center for KDE Plasma 6 — Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Check required tools
echo "==> Checking required tools..."
missing_tools=()
command -v zip >/dev/null 2>&1 || missing_tools+=("zip")

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "❌ Missing required tools: ${missing_tools[*]}"
    exit 1
fi

# 2. Make scripts executable
echo "==> Setting script permissions..."
chmod +x "${SCRIPT_DIR}/contents/scripts/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/package.sh" 2>/dev/null || true

# 3. Build plasmoid package
echo "==> Packaging plasmoid..."
bash "${SCRIPT_DIR}/package.sh"

# 4. Install plasmoid to local Plasma directory
echo "==> Installing plasmoid to ${INSTALL_DIR}..."
mkdir -p "${HOME}/.local/share/plasma/plasmoids"

# If previously installed, remove old directory to ensure fresh copy
if [ -d "${INSTALL_DIR}" ]; then
    echo "    Removing existing installation..."
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p "${INSTALL_DIR}"
cp -r "${SCRIPT_DIR}/metadata.json" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/contents" "${INSTALL_DIR}/"

# Ensure installed scripts are executable
chmod +x "${INSTALL_DIR}/contents/scripts/"*.sh 2>/dev/null || true

# 5. Register with kpackagetool6 if available
if command -v kpackagetool6 >/dev/null 2>&1; then
    echo "==> Registering with kpackagetool6..."
    kpackagetool6 --type Plasma/Applet -u "${SCRIPT_DIR}/${APPLET_ID}.plasmoid" 2>/dev/null || \
    kpackagetool6 --type Plasma/Applet -i "${SCRIPT_DIR}/${APPLET_ID}.plasmoid" 2>/dev/null || true
fi

# 6. Clear QML disk cache
echo "==> Clearing QML cache..."
rm -rf "${HOME}/.cache/plasma_qml_cache"* "${HOME}/.cache/"*qmlcache* 2>/dev/null || true

# 7. Refresh and reload Plasma shell
if command -v qdbus6 >/dev/null 2>&1; then
    echo "==> Refreshing Plasma shell cache via qdbus6..."
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
fi

if systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
    echo "==> Reloading plasma-plasmashell..."
    systemctl --user restart plasma-plasmashell 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation complete!"
echo ""
echo "To add the widget to your panel:"
echo "  1. Right-click your KDE panel -> 'Add Widgets...'"
echo "  2. Search for 'Calendar & Notification Center'"
echo "  3. Drag and drop it onto your panel"
echo ""
echo "To preview immediately without restarting Plasma:"
echo "  plasmoidviewer -a ${APPLET_ID}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
