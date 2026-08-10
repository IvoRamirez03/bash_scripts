#!/bin/bash

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

echo "Iniciando limpieza del sistema de impresión..."

# 1. Desactivar el registro de depuración masiva
if cupsctl --no-debug-logging; then
    echo "OK: Modo Debug de CUPS desactivado."
else
    echo "ERROR: No se pudo desactivar el modo Debug." >&2
fi

# 2. Desactivar la interfaz web local por seguridad
if cupsctl WebInterface=no; then
    echo "OK: Interfaz web de CUPS oculta."
else
    echo "ERROR: No se pudo ocultar la interfaz web." >&2
fi

# 3. Forzar la rotación del log actual para liberar el espacio en disco usado
if [ -f /var/log/cups/error_log ]; then
    echo "Vaciando el log de errores acumulado..."
    cp /dev/null /var/log/cups/error_log
fi

echo "Proceso finalizado correctamente."
exit 0
