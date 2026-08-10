# Tunnelblick VPN MDM Deployment Script

Automated Bash script to silently deploy a standardized Tunnelblick OpenVPN configuration profile on macOS (Apple Silicon) via MDM (tested with Applivery). It runs with root privileges and installs the configuration as a **Shared profile** available to all system users.

# Problem Statement & Context

In environments relying on OpenVPN-based access (e.g., WordPress management or internal infrastructure), macOS users must rely on third-party clients such as [Tunnelblick](https://tunnelblick.net/).

Over time, infrastructure changes, frequent client updates, and legacy configurations managed by multiple administrators often lead to inconsistent profile names and broken connections across the fleet.

This script normalizes and standardizes the deployed VPN configuration, bypassing fragile installer binaries and simplifying corporate profile updates.

---

## Requirements

* **OS:** macOS Ventura, Sonoma, or Sequoia (Apple Silicon).
* **Prerequisite:** Tunnelblick 8.x installed prior to script execution.
* **Execution:** Root privileges via MDM agent.

---

## Usage

1. Paste your OpenVPN configuration content into the `config.ovpn` heredoc inside the script.
2. Set the `VPN_NAME` variable to your preferred standardized profile name.
3. Deploy the script as a root task through your MDM solution.

The profile will be installed at the following path:

```text
/Library/Application Support/Tunnelblick/Shared/<VPN_NAME>.tblk

```

### Execution Flow

* If Tunnelblick is currently running during deployment, the script restarts it automatically to register the new profile.
* If Tunnelblick is not running, the profile will be loaded on the next application launch.
* Upon completion, Tunnelblick launches automatically, prompting the user for their VPN credentials.

---

## Directory Structure (`.tblk`)

```text
VPN_NAME.tblk/
└── Contents/
    ├── Info.plist        (644 root:wheel)
    └── Resources/
        └── config.ovpn   (700 root:wheel)

```

---

## Permissions & Security Requirements

Tunnelblick enforces strict file permission checks via `openvpnstart`. To prevent execution failures, the Shared directory layout must follow these exact permission boundaries:

| Path | Required Permissions | Ownership |
| --- | --- | --- |
| `Shared/` | `755` (`rwxr-xr-x`) | `root:wheel` |
| `VPN.tblk/` | `755` (`rwxr-xr-x`) | `root:wheel` |
| `Contents/` | `755` (`rwxr-xr-x`) | `root:wheel` |
| `Contents/Info.plist` | `644` (`rw-r--r--`) | `root:wheel` |
| `Contents/Resources/` | `755` (`rwxr-xr-x`) | `root:wheel` |
| `Contents/Resources/config.ovpn` | **`700` (`rwx------`)** | `root:wheel` |
| Any additional file in `Resources/` | **`700` (`rwx------`)** | `root:wheel` |

> **Critical Note:** `config.ovpn` and any accompanying credentials, certificates, or keys inside `Resources/` **must be set to `0700**`. Tunnelblick flags any configuration file readable by non-root users as insecure and will refuse connection with the error: *"The configuration is not secure. It must be reinstalled."*

---

## Applivery Configuration (PPPC / Full Disk Access)

To allow the MDM agent to modify protected system paths (`/Library/Application Support/Tunnelblick`) without user intervention, a **Privacy Preferences Policy Control (PPPC)** profile must be deployed beforehand.

Without this profile, macOS System Integrity Protection (SIP) will block directory creation and the script will fail.

### Payload Specification:

| Field | Value |
| --- | --- |
| **Service** | System Policy All Files |
| **Identifier** | `com.applivery.mdm-agent-macos` |
| **Identifier Type** | Bundle ID |
| **Code Requirement** | `anchor apple generic and identifier "com.applivery.mdm-agent-macos" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = BJ55G8KDLB)` |
| **Comment** | Full Disk Access profile for Tunnelblick deployment script |

---

## Known Issues & Workarounds

### 1. Tunnelblick Installer Binary Crash in Non-GUI Root Context

The built-in installer binary (`Tunnelblick.app/Contents/Resources/installer`) crashes with an `NSInvalidArgumentException` when executed from an MDM root process without an active user GUI session:

```text
Unable to determine user. Some operations cannot be performed.
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
reason: '-[__NSCFString deleteCharactersInRange:]: Range or index out of bounds'

```

*Workaround:* This script bypasses the native installer binary completely and constructs the `.tblk` structure directly inside the `Shared/` directory with explicit permissions.

### 2. Symlink Resolution in Temporary Paths

macOS resolves `/tmp` to `/private/tmp`. Tunnelblick security routines reject paths containing symbolic links. All staging actions and temporary files created by this script explicitly use `/private/tmp`.

---

## Debugging & Verification

To trace script execution during testing, enable standard logging by adding the following statements:

```bash
# Verify detected application version and active user
echo "Tunnelblick detected: ${TB_VERSION}"
echo "Console user: ${CONSOLE_USER} (uid=${CONSOLE_UID})"

# Trace build steps
echo "==> [1/4] Building .tblk structure..."
echo "==> [2/4] Writing config.ovpn..."
echo "==> [3/4] Applying permissions..."

# Verify permissions tree
ls -laR "$DEST_TBLK"

# Application state notification
echo "==> [4/4] Notifying Tunnelblick..."

```

To inspect log outputs generated directly by the Tunnelblick installer binary (if used in troubleshooting):

```bash
ls /private/tmp/*tunnelblick-installer* 2>/dev/null | while read -r log_file; do
    echo ">> File: $log_file"
    cat "$log_file"
done

```