#!/bin/bash

# Configuración
USER_EMAIL="yourcompany@yourdomain.com"
INSTALL_PASS="165-723-701" 
AGENT_NAME=$(hostname)
DEBUG_LOG="/tmp/dwagent_debug.log"
ERROR_LOG="/tmp/dwagent_error.log"

# Función para logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEBUG_LOG"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERROR_LOG" "$DEBUG_LOG"
    exit 1
}

# Limpiar logs anteriores
> "$DEBUG_LOG"
> "$ERROR_LOG"

log_message "=== INICIO INSTALACIÓN DWAGENT ==="
log_message "Usuario: $USER_EMAIL"
log_message "Nombre del agente: $AGENT_NAME"

# Verificar si ya está instalado
if [ -f "/usr/local/dwagent/dwagent" ] || [ -f "/opt/dwagent/dwagent" ]; then
    log_message "DWAgent ya está instalado"
    exit 0
fi

# Verificar dependencias
log_message "Verificando dependencias..."
command -v curl >/dev/null 2>&1 || log_error "curl no está instalado. Instálalo con: brew install curl"
command -v python3 >/dev/null 2>&1 || log_error "Python3 no está instalado"
log_message "Dependencias verificadas correctamente"

# Descargar el agente
log_message "Descargando dwagent_x86.sh..."
if curl -L "https://www.dwservice.net/download/dwagent_x86.sh" -o /tmp/dwagent.sh 2>>"$ERROR_LOG"; then
    log_message "Descarga completada: /tmp/dwagent.sh"
    
    if [ ! -f "/tmp/dwagent.sh" ]; then
        log_error "El archivo no se descargó correctamente"
    fi
    
    FILE_SIZE=$(stat -f%z "/tmp/dwagent.sh" 2>/dev/null || wc -c < "/tmp/dwagent.sh")
    log_message "Tamaño del archivo: ${FILE_SIZE} bytes"
else
    log_error "Error al descargar dwagent_x86.sh"
fi

# Dar permisos de ejecución
log_message "Asignando permisos de ejecución..."
chmod +x /tmp/dwagent.sh 2>>"$ERROR_LOG" || log_error "Error al asignar permisos"

# **MODIFICACIÓN PRINCIPAL: Instalación interactiva**
log_message "=== INICIO INSTALACIÓN INTERACTIVA ==="
log_message "NOTA: La instalación silenciosa está bloqueada por DWService"
log_message "Se procederá con instalación interactiva"

# Preparar respuesta automática (si es posible)
log_message "Ejecutando instalador interactivo..."
log_message "El instalador pedirá:"
log_message "1. Idioma (español = 1)"
log_message "2. Aceptar términos (sí = y)"
log_message "3. Email: $USER_EMAIL"
log_message "4. Contraseña: [la proporcionada]"
log_message "5. Nombre del agente: $AGENT_NAME"

# Intentar instalar de forma interactiva
INSTALL_LOG="/tmp/dwagent_install.log"
log_message "Ejecutando: /tmp/dwagent.sh"

# Opción 1: Intentar con expect (si está disponible)
if command -v expect >/dev/null 2>&1; then
    log_message "Usando expect para automatización interactiva"
    expect -c "
    set timeout 300
    spawn /tmp/dwagent.sh
    expect \"Select your language:\"
    send \"1\r\"
    expect \"accept the terms of the license agreement?\"
    send \"y\r\"
    expect \"Email:\"
    send \"$USER_EMAIL\r\"
    expect \"Password:\"
    send \"$INSTALL_PASS\r\"
    expect \"Name:\"
    send \"$AGENT_NAME\r\"
    expect eof
    " > "$INSTALL_LOG" 2>&1
else
    # Opción 2: Instalación manual con instrucciones
    log_message "Expect no está disponible. Necesitarás instalar manualmente:"
    log_message "1. Ejecuta: sudo /tmp/dwagent.sh"
    log_message "2. Selecciona español (opción 1)"
    log_message "3. Acepta los términos (y)"
    log_message "4. Introduce el email: $USER_EMAIL"
    log_message "5. Introduce la contraseña: $INSTALL_PASS"
    log_message "6. Introduce el nombre: $AGENT_NAME"
    
    echo "=== INSTRUCCIONES DE INSTALACIÓN MANUAL ==="
    echo "Ejecuta los siguientes comandos:"
    echo "1. chmod +x /tmp/dwagent.sh"
    echo "2. sudo /tmp/dwagent.sh"
    echo ""
    echo "Durante la instalación:"
    echo "- Selecciona idioma español (1)"
    echo "- Acepta los términos (y)"
    echo "- Email: $USER_EMAIL"
    echo "- Contraseña: $INSTALL_PASS"
    echo "- Nombre: $AGENT_NAME"
    
    # Preguntar si el usuario quiere continuar
    read -p "¿Quieres ejecutar el instalador ahora? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo /tmp/dwagent.sh
    else
        log_message "Instalación manual requerida"
        exit 0
    fi
fi

# Verificar instalación
log_message "Verificando instalación..."
if [ -f "/usr/local/dwagent/dwagent" ] || [ -f "/opt/dwagent/dwagent" ] || [ -d "$HOME/.dwagent" ]; then
    log_message "✅ DWAgent instalado correctamente"
    
    # Verificar si el servicio está corriendo
    if pgrep -f dwagent > /dev/null; then
        log_message "✅ Servicio DWAgent en ejecución"
    else
        log_message "⚠️  Servicio no está corriendo. Iniciando..."
        # Intentar iniciar el servicio
        if [ -f "/usr/local/dwagent/dwagent" ]; then
            /usr/local/dwagent/dwagent > /dev/null 2>&1 &
        fi
    fi
else
    log_error "La instalación no se completó correctamente"
fi

# Limpiar
log_message "Limpiando archivos temporales..."
rm -f /tmp/dwagent.sh 2>>"$ERROR_LOG"

log_message "=== INSTALACIÓN COMPLETADA ==="
log_message "Debug log: $DEBUG_LOG"