#!/bin/bash

# Estructura: "NOMBRE|DESCRIPCION|IP|DEFAULT(yes/no)"
IMPRESORAS=(
    "192.168.2.20|impresora-respaldo|192.168.2.20|no"   
    "192.168.2.24|Impresora-A3|192.168.2.24|no"
    "192.168.2.35|Impresora-Oficial|192.168.2.35|yes" # <-- Impresora por omisión
    "192.168.2.39|Impresora-Cool|192.168.2.39|no"
)

# Agrega cuantas impresoras quieras en el listado. 
# Usa pipes para dividir la información ya que con los puntos de las IP's puede joder el script.

agregar_impresora() {
    local nombre="$1"
    local desc="$2"
    local ip="$3"
    local is_default="$4"

    echo "[INFO]: Añadiendo '$desc' ($ip)..."
    lpadmin -p "$nombre" -E -D "$desc" -v "ipp://$ip:631/ipp/print" -m everywhere
    
    # Si esta marcada como default, la establecemos como predeterminada
    if [ "$is_default" = "yes" ]; then
        lpadmin -d "$nombre"
        echo "[INFO]: '$desc' configurada como IMPRESORA POR DEFECTO."
    fi

    sleep 2
}

# Limpieza inicial
lpstat -v | awk '{print $3}' | sed 's/://' | xargs -r -I {} lpadmin -x {}

# Recorrer lista
for item in "${IMPRESORAS[@]}"; do
    IFS='|' read -r nombre desc ip es_default <<< "$item"
    agregar_impresora "$nombre" "$desc" "$ip" "$es_default"
done

echo "Proceso completado con éxito."