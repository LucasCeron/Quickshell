#!/bin/sh
# One sample of the system for the activity monitor, in "#section" blocks.
# Rates and percentages are worked out in QML from consecutive samples.
export LC_ALL=C

echo "#cpu"
grep '^cpu' /proc/stat

echo "#mem"
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo

# Bytes received and sent on every interface but loopback.
echo "#net"
awk 'NR > 2 && $1 !~ /^lo:/ { gsub(":", " "); rx += $2; tx += $10 } END { print rx + 0, tx + 0 }' /proc/net/dev

echo "#disk"
df -B1 --output=used,size / | tail -1

echo "#uptime"
cut -d' ' -f1 /proc/uptime

# top's first frame averages since each process started; the second one is current.
echo "#ps"
top -b -n 2 -d 0.4 -o %CPU -w 256 | awk '/^top -/ { frame++ } frame == 2 && /^ *[0-9]+ / && $12 != "top" { print $1, $9, $10, $12; if (++shown == 7) exit }'
