#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPIMAGE="${1:-}"
if [[ -z "$APPIMAGE" ]]; then
  APPIMAGE="$(find "$ROOT_DIR/dist" -maxdepth 1 -type f -name 'Tunneler-*.AppImage' -print -quit 2>/dev/null || true)"
fi
if [[ -z "$APPIMAGE" || ! -f "$APPIMAGE" ]]; then
  echo "ERROR: Pass a Tunneler AppImage path or build it first." >&2
  exit 1
fi

INSTALL_DIR="$HOME/.local/bin"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$INSTALL_DIR" "$APPLICATIONS_DIR" "$ICON_DIR"
install -m 0755 "$APPIMAGE" "$INSTALL_DIR/Tunneler.AppImage"
install -m 0644 "$ROOT_DIR/assets/au.pmhs.tunneler.svg" "$ICON_DIR/au.pmhs.tunneler.svg"
sed "s|^Exec=.*|Exec=$INSTALL_DIR/Tunneler.AppImage|" \
  "$ROOT_DIR/au.pmhs.tunneler.desktop" >"$APPLICATIONS_DIR/au.pmhs.tunneler.desktop"
chmod 0644 "$APPLICATIONS_DIR/au.pmhs.tunneler.desktop"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
fi
echo "Tunneler is installed for $(id -un)."
