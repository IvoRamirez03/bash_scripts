#!/bin/bash

# Agree how many printers you want in the list.
# Use pipes to divide the information since the dots in the IPs can mess up the script. 
# Structure: "NAME|DESCRIPTION|IP|DEFAULT(yes/no)" (Use your own printer names and IPs)
PRINTERS=(
    "192.168.0.10|printer1-name|192.168.0.10|no"   
    "192.168.0.11|printer2-name|192.168.0.11|no"
    "192.168.0.12|printer3-name|192.168.0.12|yes" 
    "192.168.0.13|printer4-name|192.168.0.13|no"
)
    

add_printer() {
    local name="$1"
    local desc="$2"
    local ip="$3"
    local is_default="$4"

    echo "[INFO]: Adding '$desc' ($ip)..."
    lpadmin -p "$name" -E -D "$desc" -v "ipp://$ip:631/ipp/print" -m everywhere
    
    # If it is marked as default, we set it as the default printer
    if [ "$is_default" = "yes" ]; then
        lpadmin -d "$name"
        echo "[INFO]: '$desc' Default printer set."
    fi

    sleep 5
}

# Initial cleanup
lpstat -v | awk '{print $3}' | sed 's/://' | xargs -r -I {} lpadmin -x {}

# Iterate through the list
for item in "${PRINTERS[@]}"; do
    IFS='|' read -r name desc ip is_default <<< "$item"
    add_printer "$name" "$desc" "$ip" "$is_default"
done

echo "Process completed successfully."