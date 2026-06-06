#!/bin/bash
# HP iLO Fan Control Script for DL360p Gen8
# Runs on Ubuntu VM via cron every 10 mins, SSHes into iLO and sets fan speed
# based on the HIGHEST demand across all configured sensors.
#
# Install: sudo crontab -e and add:
# */10 * * * * /etc/fan_control.sh

# ===================== CONFIGURATION =====================

ILO_HOST="<HP ILO IP>"
ILO_USER="Administrator"
ILO_PASS="<PASSWORD>"
LOG_FILE="/var/log/fan_control.log" # of course anywhere you want is fine

# Global minimum fan speed (0-255). Applied when all sensors are below their
# lowest threshold. 76 = ~30%
GLOBAL_MIN=76

# Number of fans (0-indexed, so 8 fans = 0..7)
FAN_COUNT=7

# Sensors to monitor.
# Format: "SENSOR_ID:LABEL:TEMP=SPEED TEMP=SPEED ..."
#   - SENSOR_ID : the iLO sensor index (from: show /system1/sensorN)
#   - LABEL     : human-readable name used in logs
#   - TEMP=SPEED pairs: thresholds in descending order. First match wins.
#     Temps below the lowest listed threshold fall back to GLOBAL_MIN.
#     Speed values are 0-255 (255 = 100%, 76 = ~30%, 128 = ~50%)
#
# To find your sensor IDs: SSH into iLO and run:
#   show /system1  -- lists all sensors
#   show /system1/sensor12  -- example for sensor 12
#
SENSORS=(
    "12:HD-Max:59=255 58=204 57=178 56=153 55=127 54=102 53=89 52=76 51=64"
    "31:HD-Controller:100=255 95=225 90=200 85=175 80=150 75=125"
)

# ===================== END CONFIGURATION =====================

# On my firmware at least, we need to be picky on how to connect
SSH_OPTS="-o StrictHostKeyChecking=no \
          -o KexAlgorithms=+diffie-hellman-group1-sha1 \
          -o HostKeyAlgorithms=+ssh-rsa \
          -o PubkeyAcceptedKeyTypes=+ssh-rsa \
          -o ConnectTimeout=10"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# ---- Helper: get demanded fan speed for a given temp and curve string ----
# Args: $1 = temp (int), $2 = "TEMP=SPEED TEMP=SPEED ..." (descending order)
# Returns the matched speed via stdout, or GLOBAL_MIN if below all thresholds.
get_speed_for_temp() {
    local temp=$1
    local curve=$2
    for pair in $curve; do
        local threshold="${pair%%=*}"
        local speed="${pair##*=}"
        if [ "$temp" -ge "$threshold" ]; then
            echo "$speed"
            return
        fi
    done
    echo "$GLOBAL_MIN"
}

# ---- Main logic ----

MAX_SPEED=$GLOBAL_MIN
LOG_PARTS=""

for sensor_def in "${SENSORS[@]}"; do
    # Parse sensor definition
    SENSOR_ID=$(echo "$sensor_def" | cut -d: -f1)
    LABEL=$(echo "$sensor_def"     | cut -d: -f2)
    CURVE=$(echo "$sensor_def"     | cut -d: -f3)

    # Read temperature from iLO
    TEMP=$(sshpass -p "$ILO_PASS" ssh $SSH_OPTS "$ILO_USER@$ILO_HOST" \
        "show /system1/sensor${SENSOR_ID}" 2>/dev/null | \
        grep "CurrentReading" | cut -d'=' -f2 | tr -d '[:space:]' | cut -d'.' -f1)

    if [ -z "$TEMP" ]; then
        echo "$TIMESTAMP - WARNING: Could not read sensor ${SENSOR_ID} (${LABEL}), skipping" >> "$LOG_FILE"
        continue
    fi

    DEMANDED=$(get_speed_for_temp "$TEMP" "$CURVE")
    DEMANDED_PCT=$(( (DEMANDED * 100) / 255 ))
    LOG_PARTS="${LOG_PARTS} | ${LABEL}: ${TEMP}C -> ${DEMANDED}/255 (${DEMANDED_PCT}%)"

    if [ "$DEMANDED" -gt "$MAX_SPEED" ]; then
        MAX_SPEED=$DEMANDED
    fi
done

# If we got no readings at all, bail out
if [ -z "$LOG_PARTS" ]; then
    echo "$TIMESTAMP - ERROR: No sensor readings obtained, skipping fan update" >> "$LOG_FILE"
    exit 1
fi

# Set all fans to the winning speed
for i in $(seq 0 $FAN_COUNT); do
    sshpass -p "$ILO_PASS" ssh $SSH_OPTS "$ILO_USER@$ILO_HOST" \
        "fan p $i max $MAX_SPEED" 2>/dev/null
done

PCT=$(( (MAX_SPEED * 100) / 255 ))
echo "$TIMESTAMP - Fan set to: ${MAX_SPEED}/255 (${PCT}%)${LOG_PARTS}" >> "$LOG_FILE"
