#!/bin/bash
set -euo pipefail

VPN_NAME="YOUR_VPN_NAME"
SHARED_DIR="/Library/Application Support/Tunnelblick/Shared"
DEST_TBLK="${SHARED_DIR}/${VPN_NAME}.tblk"
DEST_CONTENTS="${DEST_TBLK}/Contents"
DEST_RESOURCES="${DEST_CONTENTS}/Resources"
DEST_OVPN="${DEST_RESOURCES}/config.ovpn"
TUNNELBLICK_INSTALLER="/Applications/Tunnelblick.app/Contents/Resources/installer"

if [ ! -f "$TUNNELBLICK_INSTALLER" ]; then
    echo "ERROR: Tunnelblick is not installed at /Applications/Tunnelblick.app" && exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root" && exit 1
fi

CONSOLE_USER=$(scutil <<< "show State:/Users/ConsoleUser" \
    | awk '/Name :/ && !/loginwindow/ && !/_mbsetupuser/ { print $3; exit }')
[ -z "$CONSOLE_USER" ] && echo "ERROR: Could not detect an active console user." && exit 1
CONSOLE_UID=$(id -u "$CONSOLE_USER")

rm -rf "${SHARED_DIR}/private" 2>/dev/null || true
rm -rf "$DEST_TBLK"

mkdir -p "$SHARED_DIR"
chown root:wheel "$SHARED_DIR"
chmod 755 "$SHARED_DIR"
mkdir -p "$DEST_RESOURCES"

cat > "${DEST_CONTENTS}/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.yourvpnname.vpn</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>TunnelblickVersion</key>
    <string>2</string>
</dict>
</plist>
PLIST_EOF

cat > "$DEST_OVPN" << 'OVPN_EOF'
dev tun
persist-tun
persist-key
data-ciphers AES-128-GCM:AES-256-CBC
data-ciphers-fallback AES-256-CBC
auth SHA512
# ... your OpenVPN config here ...
OVPN_EOF

[ ! -s "$DEST_OVPN" ] && echo "ERROR: .ovpn file is empty." && exit 1

chown -R root:wheel "$DEST_TBLK"
chmod 755 "$DEST_TBLK"
chmod 755 "$DEST_CONTENTS"
chmod 755 "$DEST_RESOURCES"
chmod 644 "${DEST_CONTENTS}/Info.plist"
chmod 700 "$DEST_OVPN"
find "$DEST_RESOURCES" -type f ! -name "*.plist" -exec chmod 700 {} \;
xattr -rc "$DEST_TBLK"

if launchctl asuser "$CONSOLE_UID" /bin/launchctl print "gui/${CONSOLE_UID}" 2>/dev/null \
   | grep -q "net.tunnelblick.tunnelblick"; then
    launchctl asuser "$CONSOLE_UID" \
        osascript -e 'tell application "Tunnelblick" to quit' 2>/dev/null || true
    sleep 3
    launchctl asuser "$CONSOLE_UID" \
        open -a /Applications/Tunnelblick.app 2>/dev/null || true
fi
