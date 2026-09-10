#!/bin/bash

# ---
# Title: Force Reboot Policy (Uptime Enforcement)
# Description: Muestra un diálogo con opción de posponer cuando el equipo lleva 10 días o más sin reiniciar. Si el usuario elige reiniciar, se ejecuta un reinicio inmediato.
# Author: Ivo Ramirez
# Version: 2.0.0
# ---


# 1. CLEANUP OLD INSTALLATIONS

DIALOG_OLD="/Applications/Dialog.app"

if [ -d "$DIALOG_OLD" ]; then
    echo "[INFO]: Dialog.app antiguo encontrado"
    pgrep -if "Dialog.app" && {
        echo "[INFO]: Cerrando Dialog..."
        pkill -if "Dialog.app" 2>/dev/null
        sleep 1
    }
    if sudo rm -rf "$DIALOG_OLD" 2>/dev/null; then
        echo "[INFO]: Eliminado correctamente"
    else
        echo "[ERROR]: No se pudo eliminar la app antigua."
    fi
else
    echo "[INFO]: No hay Dialog.app antiguo presente"
fi


# 2. PRE-FLIGHT & BRANDING SETUP

PATH=/usr/bin:/bin:/usr/sbin:/sbin

DIALOG_CLI="/usr/local/bin/dialog"
DIALOG_APP="/Library/Application Support/Dialog/Dialog.app"
DIALOG_ICON_DIR="/Library/Application Support/Dialog"
DIALOG_ICON="$DIALOG_ICON_DIR/Dialog.png"
BRAND_ICON="/var/root/AppliveryAssets/Dialog.png"

needs_install=0
needs_reinstall=0

CURRENT_USER=$(stat -f %Su /dev/console)
USER_ID=$(id -u "$CURRENT_USER" 2>/dev/null || true)

get_swiftdialog_pkg_url() {
    local url
    url="$(/usr/bin/curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: Force_Reboot" \
        "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | \
        /usr/bin/sed -nE 's/.*"browser_download_url":"([^"]*\.pkg)".*/\1/p' | \
        /usr/bin/head -n 1)"
    [ -n "$url" ] && echo "$url" && return 0
    return 1
}

run_as_user() {
    if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "loginwindow" ] || [ -z "$USER_ID" ]; then
        return 1
    fi
    launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CURRENT_USER" -- "$@"
}

# Verificar si swiftDialog está instalado
if [ ! -x "$DIALOG_CLI" ] || [ ! -d "$DIALOG_APP" ]; then
    needs_install=1
fi

# Lógica de icono de marca
mkdir -p "$DIALOG_ICON_DIR"
chmod 755 "$DIALOG_ICON_DIR"

if [ -f "$BRAND_ICON" ]; then
    tmp_brand="$(/usr/bin/mktemp /tmp/dialog_brand.XXXXXX.png)"
    if ! sips -Z 512 "$BRAND_ICON" --out "$tmp_brand" >/dev/null 2>&1; then
        /bin/cp "$BRAND_ICON" "$tmp_brand"
    fi
    if [ -f "$tmp_brand" ]; then
        if [ ! -f "$DIALOG_ICON" ] || ! cmp -s "$tmp_brand" "$DIALOG_ICON"; then
            cp "$tmp_brand" "$DIALOG_ICON"
            chmod 644 "$DIALOG_ICON"
            chown root:wheel "$DIALOG_ICON" >/dev/null 2>&1
            needs_reinstall=1
        fi
    fi
    rm -f "$tmp_brand"
fi


# 3. SWIFTDIALOG INSTALLATION

if [ "$needs_install" -eq 1 ] || [ "$needs_reinstall" -eq 1 ]; then
    pkg_url="$(get_swiftdialog_pkg_url 2>/dev/null || true)"
    if [ -n "$pkg_url" ]; then
        pkg_path="/tmp/swiftDialog_$(date +%s).pkg"
        /usr/bin/curl -fL --retry 3 --retry-delay 1 "$pkg_url" -o "$pkg_path"
        installer -pkg "$pkg_path" -target /
        rm -f "$pkg_path"
    else
        echo "[ERROR]: No se pudo obtener la URL de swiftDialog." >&2
        exit 1
    fi
fi

killall Dialog 2>/dev/null


# 4. CÁLCULO DEL UPTIME

current_unix_time="$(date '+%s')"
boot_time_unix="$(sysctl -n kern.boottime | awk -F 'sec = |, usec' '{ print $2; exit }')"
uptime_seconds="$(( current_unix_time - boot_time_unix ))"
uptime_days="$(( uptime_seconds / 86400 ))"

#TEST_UPTIME_DAYS="10" # Descomenta esta línea para pruebas (simula X días de uptime)

if [ -n "$TEST_UPTIME_DAYS" ]; then
    uptime_days="$TEST_UPTIME_DAYS"
fi


# 5. LÓGICA DE AVISO CON OPCIÓN DE POSPONER

if [ "$uptime_days" -gt 9 ]; then
    echo "[INFO]: Uptime: $uptime_days días (10 o más). Requiere atención. Mostrando aviso..."
    afplay "/System/Library/Sounds/Sosumi.aiff" &

    run_as_user "$DIALOG_CLI" \
        --title "Es necesario reiniciar" \
        --message "*¡Llevas ${uptime_days} días sin reiniciar!* \n\nPor favor, guarda tu trabajo y reinicia cuando puedas. Este aviso volverá a aparecer hasta que reinicies el equipo." \
        --icon "$DIALOG_ICON" \
        --button1text "Posponer" \
        --button2text "Reiniciar ahora" \
        --timer 840 --width 650 --height 280 --position bottomright --ontop

    dialog_results=$?
else
    echo "[INFO]: Uptime: $uptime_days días. No se requiere acción (9 días o menos)."
    exit 0
fi


# 6. LÓGICA DE REINICIO O POSPONER
if [ "$dialog_results" = "2" ]; then
    echo "[INFO]: Reiniciando..."
    shutdown -r now
    sleep 2
    reboot
else
    echo "[INFO]: El usuario ha pospuesto el reinicio."
fi