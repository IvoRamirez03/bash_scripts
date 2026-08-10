# Tunnelblick VPN Deploy Script with MDM

Bash script to silently deploy a Tunnelblick VPN configuration on Apple Silicon Macs via MDM (tested with Applivery). Runs as root and installs the profile as a Shared configuration available to all users.

## Requirements

- macOS Ventura / Sonoma / Sequoia (Apple Silicon)
- Tunnelblick 8.x installed before running this script
- Executed as root via MDM

## Usage

1. Replace the `config.ovpn` heredoc content with your actual OpenVPN configuration.
2. Update `VPN_NAME` if needed.
3. Deploy via your MDM as a root script.

The profile will be installed at:
```
/Library/Application Support/Tunnelblick/Shared/<VPN_NAME>.tblk
```

If Tunnelblick is running at the time of deployment, it will be restarted automatically to load the new profile. Otherwise, it will be detected on the next launch.

Tunnelblick will open automatically at the end of the deployment, ready for the user to enter their VPN credentials. If Tunnelblick was already running, it will be restarted first to ensure the new profile is loaded.

## .tblk structure

```
VPN_NAME.tblk/
└── Contents/
    ├── Info.plist        (644 root:wheel)
    └── Resources/
        └── config.ovpn   (700 root:wheel)
```

## Permissions

Tunnelblick enforces strict permission checks via `openvpnstart`. The required layout for Shared configurations is:

| Path | Permission |
|---|---|
| `Shared/` | `755` root:wheel |
| `VPN.tblk/` | `755` root:wheel |
| `Contents/` | `755` root:wheel |
| `Contents/Info.plist` | `644` root:wheel |
| `Contents/Resources/` | `755` root:wheel |
| `Contents/Resources/config.ovpn` | **`700`** root:wheel |
| Any other file in `Resources/` | **`700`** root:wheel |

> **Important:** `config.ovpn` and all other files in `Resources/` (keys, certs, etc.) must be `0700`, not `0644`. Tunnelblick considers any config file readable by non-root users as insecure and will refuse to connect with the message *"The configuration is not secure. It must be reinstalled."*
>
> ---

## Applivery Config (PPPC / FDA)

In order for the script to move configuration files to `/Library/Application Support/Tunnelblick` and manage network permissions without user intervention, it is necessary to configure a **Privacy Preferences Policy Control (PPPC)** profile in Applivery.

Without this, macOS will block the agent's actions and the script will fail when attempting to write to protected directories.

### Payload config:

| Campo | Valor |
| :--- | :--- |
| **Service** | System Policy All Files |
| **Identifier** | `com.applivery.mdm-agent-macos` |
| **Identifier Type** | Bundle ID |
| **Code Requirement** | `anchor apple generic and identifier "com.applivery.mdm-agent-macos" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = BJ55G8KDLB)` |
| **Comment** | FDA script for Tunnelblick |

> [!IMPORTANT]
> Make sure to assign this profile to the same devices or groups where you will deploy the Tunnelblick script. This grants the Applivery agent full disk access so it can perform the installation correctly.

## Known issues

### Tunnelblick 8.0.1 installer binary crashes from MDM context

The built-in `installer` binary at `Tunnelblick.app/Contents/Resources/installer` crashes with `NSInvalidArgumentException` when run from a root MDM context without an active GUI session:

```
Unable to determine user. Some operations cannot be performed.
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
reason: '-[__NSCFString deleteCharactersInRange:]: Range or index out of bounds'
```

This is a confirmed bug in build 6301. For this reason, this script bypasses the installer binary entirely and writes the `.tblk` directly to the Shared directory.

### `/tmp` is a symlink

macOS resolves `/tmp` to `/private/tmp`. The Tunnelblick installer rejects any path that passes through a symlink as a security measure. Always use `/private/tmp` for any intermediate files.

---

## Debugging

If you need to trace the deployment, add the following `echo` statements back into the script at the relevant steps:

```bash
# After detecting Tunnelblick version
echo "Tunnelblick detected: ${TB_VERSION}"

# After detecting console user
echo "Console user: ${CONSOLE_USER} (uid=${CONSOLE_UID})"

# Before building the .tblk
echo "==> [1/4] Building .tblk structure..."

# Before writing the ovpn
echo "==> [2/4] Writing config.ovpn..."

# Before applying permissions
echo "==> [3/4] Applying permissions..."

# After applying permissions — shows the full tree
ls -laR "$DEST_TBLK"

# Before notifying Tunnelblick
echo "==> [4/4] Notifying Tunnelblick..."

# If Tunnelblick is running and will be restarted
echo "Tunnelblick is running — restarting to load new profile..."

# If Tunnelblick is not running
echo "Tunnelblick is not running. Config will be loaded on next launch."

# On success
echo "Done. Profile installed at: ${DEST_TBLK}"
echo "NOTE: The user will be prompted to confirm the profile on first use."
```

Also useful for diagnosing installer binary failures — these debug log files are created by the installer in `/private/tmp`:

```bash
ls /private/tmp/*tunnelblick-installer* 2>/dev/null | while read -r f; do
    echo ">> $f:"
    cat "$f"
done
```
