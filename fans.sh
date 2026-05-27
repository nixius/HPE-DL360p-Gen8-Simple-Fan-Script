#!/bin/bash
# HP iLO Fan Control Script for DL360p Gen8
# I runs on ubuntu VM via cron every 10 mins, SSHes into iLO and sets fan speed based on HD Max temp
# Install: sudo crontab -e and add:
# */10 * * * * /etc/fan_control.sh

# ===================== CONFIGURATION =====================
ILO_HOST="<HP ILO IP>"
ILO_USER="Administrator"
ILO_PASS="<PASSWORD>"
LOG_FILE="/var/log/fan_control.log"
# =========================================================

# This was a requirement for me
SSH_OPTS="-o StrictHostKeyChecking=no \
          -o KexAlgorithms=+diffie-hellman-group1-sha1 \
          -o HostKeyAlgorithms=+ssh-rsa \
          -o PubkeyAcceptedKeyTypes=+ssh-rsa \
          -o ConnectTimeout=10"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Read HD Max temperature from iLO (sensor12 = "12-HD Max")
# You can find sensor names in HP ILO > system Information > Temperatures
# I chose 12-HD MAx as this was my limiting temperature sensor
HD_TEMP=$(sshpass -p "$ILO_PASS" ssh $SSH_OPTS "$ILO_USER@$ILO_HOST" \
    "show /system1/sensor12" 2>/dev/null | \
    grep "CurrentReading" | cut -d'=' -f2 | tr -d '[:space:]' | cut -d'.' -f1)


# Validate we got a reading
if [ -z "$HD_TEMP" ]; then
    echo "$TIMESTAMP - ERROR: Could not read HD temp from iLO, skipping" >> "$LOG_FILE"
    exit 1
fi

# Determine fan speed based on HD Max temp
# I based these on my environment, tweak as you need
# The values go form 0-255, so 255 is 100% and 125 is ~50%
# if temp <= 52 degrees c, set to 64, or 25%
if [ "$HD_TEMP" -le 51 ]; then
    FAN_SPEED=64
elif [ "$HD_TEMP" -eq 52 ]; then
    FAN_SPEED=76
elif [ "$HD_TEMP" -eq 53 ]; then
    FAN_SPEED=89
elif [ "$HD_TEMP" -eq 54 ]; then
    FAN_SPEED=102
elif [ "$HD_TEMP" -eq 55 ]; then
    FAN_SPEED=127
elif [ "$HD_TEMP" -eq 56 ]; then
    FAN_SPEED=153
elif [ "$HD_TEMP" -eq 57 ]; then
    FAN_SPEED=178
elif [ "$HD_TEMP" -eq 58 ]; then
    FAN_SPEED=204
else
    # 59 and above
    FAN_SPEED=255
fi

# Set fan speed via iLO SSH
# I have 8 fans, if you don't you need to figure out the indexes, or just set all it won't hurt
for i in 0 1 2 3 4 5 6 7; do
  sshpass -p "$ILO_PASS" ssh $SSH_OPTS "$ILO_USER@$ILO_HOST" "fan p $i max $FAN_SPEED" 2>/dev/null
done

# Log the result
echo "$TIMESTAMP - HD Temp: ${HD_TEMP}C -> Fan: ${FAN_SPEED}%" >> "$LOG_FILE"
