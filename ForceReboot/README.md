# Force Reboot Policy for macOS with swiftDialog

**Repo swiftDialog:** https://github.com/swiftDialog/swiftDialog
**Repo Applivery:** https://github.com/applivery/applivery-mdm-scripts/tree/main/Apple

---

## Version 1.0

Muestra un diálogo con opción de posponer cuando el equipo lleva más de 10 días sin reiniciar.

**Comportamiento:**
- Botón por defecto (Enter): `Reiniciar ahora`
- Botón secundario: `Posponer`
- Si el timer de 14 minutos expiraba → reinicio automático
- Si el usuario pulsaba Enter con foco en el diálogo → reinicio inmediato

---

## Version 2.0 — Fixes

### Fix 1: Inversión de botones para evitar reinicios accidentales

**Problema:** el botón 1 en swiftDialog está mapeado a la tecla Enter. Si el usuario tenía el foco en el diálogo (por ejemplo, tras hacer click sobre él) y pulsaba Enter con intención de "posponer", en realidad disparaba el reinicio, porque button1 era `Reiniciar ahora`.

**Solución:** invertir los botones para que el que responde a Enter sea el "seguro" (`Posponer`).

```bash
run_as_user "$DIALOG_CLI" \
    --title "Es necesario reiniciar" \
    --message "..." \
    --icon "$DIALOG_ICON" \
    # --button1text "Reiniciar ahora"   # Before
    --button1text "Posponer"            # After
    # --button2text "Posponer"          # Before
    --button2text "Reiniciar ahora"     # After
    --timer 840 --width 650 --height 280 --position bottomright --ontop
```

---

### Fix 2: El reinicio solo ocurre por acción explícita del usuario

**Problema:** la lógica original disparaba `shutdown -r now` tanto si el usuario pulsaba el botón principal como si el timer llegaba a 0. Esto suponía un riesgo de pérdida de trabajo sin guardar si el usuario se ausentaba del equipo con el diálogo abierto.

**Solución:** el equipo se reinicia **únicamente** con click explícito en `Reiniciar ahora` (exit code `2`). Cualquier otro escenario (posponer, timer expirado, cierre inesperado del diálogo) se trata como "no reiniciar", y el aviso volverá a aparecer en la siguiente ejecución del script vía MDM.

```bash
# if [ "$dialog_results" = "0" ] || [ "$dialog_results" = "4" ]; then   # Before
if [ "$dialog_results" = "2" ]; then                                     # After
    echo "[INFO]: Reiniciando..."
    shutdown -r now
    sleep 2
    reboot
# elif [ "$dialog_results" = "2" ]; then                                 # Before
else                                                                     # After
    echo "[INFO]: El usuario ha pospuesto el reinicio."
fi
```

El uso de `else` (en lugar de listar códigos con `||`) garantiza que ningún exit code inesperado — presente o futuro — pueda provocar un reinicio no intencionado.

---

### Fix 3: Mensaje actualizado

**Problema:** el mensaje original ("Si lo pospones, recibirás un recordatorio") sugería que solo posponer activamente traía un recordatorio, cuando ahora el diálogo también reaparece si el usuario lo ignora por completo.

```bash
# --message "*¡Llevas ${uptime_days} días sin reiniciar!* \n\nPor favor, guarda tu trabajo y reinicia el equipo. Si lo pospones, recibirás un recordatorio." \                    # Before
--message "*¡Llevas ${uptime_days} días sin reiniciar!* \n\nPor favor, guarda tu trabajo y reinicia cuando puedas. Este aviso volverá a aparecer hasta que reinicies el equipo." \  # After
```

---

## Exit codes de swiftDialog relevantes

| Código | Causa                                                                 |
|--------|-----------------------------------------------------------------------|
| `0`    | Botón por defecto (button1 = `Posponer`) clicado o Enter pulsado      |
| `2`    | button2 (`Reiniciar ahora`) clicado, o Esc pulsado                    |
| `4`    | Timer agotado (versiones antiguas de swiftDialog)                     |
| `10`   | Usuario cerró con Cmd+Q                                               |
| `20`   | Timer agotado (versiones recientes de swiftDialog)                    |

Referencia oficial: https://github.com/swiftDialog/swiftDialog/wiki/Exit-codes

---

## Notas de comportamiento

- El script se ejecuta cada X tiempo vía MDM. Mientras `uptime_days > 9`, el diálogo aparecerá en cada ejecución hasta que el usuario reinicie voluntariamente.
- La ventana se posiciona en `bottomright` con `--ontop` para ser visible sin bloquear el flujo de trabajo.
- El branding (icono) se carga desde `/var/root/AppliveryAssets/Dialog.png`, desplegado previamente por el MDM. Si no está presente, swiftDialog usa su icono genérico.
- **Recordatorio:** antes de desplegar en producción, comentar la línea `TEST_UPTIME_DAYS="10"` en la sección 4, o el script simulará siempre 10 días de uptime.