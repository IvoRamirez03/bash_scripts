#!/bin/bash

export PATH=/usr/bin:/bin:/usr/sbin:/sbin 

echo "Cleaning up CUPS debug mode and web interface settings..."

# 1. Deactivate CUPS debug mode to prevent excessive logging and potential disk space issues
if cupsctl --no-debug-logging; then
    echo "[OK]: CUPS debug mode deactivated."
else
    echo "[ERROR]: Failed to deactivate CUPS debug mode." >&2
fi

# 2. Deactivate Web Interface to prevent unauthorized access
if cupsctl WebInterface=no; then
    echo "[OK]: CUPS web interface hidden."
else
    echo "[ERROR]: Failed to hide CUPS web interface." >&2
fi

# 3. Clear the CUPS error log to free up disk space and remove old error messages
if [ -f /var/log/cups/error_log ]; then
    echo "[INFO]: Emptying the accumulated error log..."
    cp /dev/null /var/log/cups/error_log
fi

echo "[INFO]: Process completed successfully."
exit 0