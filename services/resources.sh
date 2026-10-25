#!/bin/sh
# A light sample for the System tab: one "key values" line per resource.
# CPU load is worked out in QML from consecutive samples.
export LC_ALL=C

grep '^cpu ' /proc/stat
awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { print "mem", t - a, t }' /proc/meminfo
df -B1 --output=used,size / | awk 'NR == 2 { print "disk", $1, $2 }'

# The CPU package sensor, or the first one available.
for hwmon in /sys/class/hwmon/hwmon*; do
    case "$(cat "$hwmon/name" 2>/dev/null)" in
        coretemp|k10temp|zenpower) echo "temp $(cat "$hwmon/temp1_input")"; break ;;
    esac
done

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
        | awk -F', *' 'NR == 1 { print "gpu", $1, $2 }'
fi
