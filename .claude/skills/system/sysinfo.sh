#!/bin/bash
MODE="${1:-all}"

battery_info() {
    pmset -g batt | tail -1
}

disk_info() {
    df -h / | tail -1 | awk '{print "Disk: " $3 " used / " $2 " total (" $5 " used)"}'
}

memory_info() {
    vm_stat | awk '
    /Pages free/ {free=$3}
    /Pages active/ {active=$3}
    /Pages inactive/ {inactive=$3}
    /Pages speculative/ {spec=$3}
    /Pages wired/ {wired=$3}
    END {
        pagesize=16384
        used=(active+wired+0)*pagesize/1073741824
        total=(free+active+inactive+spec+wired+0)*pagesize/1073741824
        printf "Memory: %.1fG used / %.1fG total\n", used, total
    }'
}

wifi_info() {
    networksetup -getairportnetwork en0 2>/dev/null || echo "Wifi: not available"
}

uptime_info() {
    uptime | awk '{print "Uptime:" $3 " " $4 " " $5}' | sed 's/,$//'
}

display_info() {
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Display Type|Resolution|Display Asleep" | sed 's/^ *//'
}

cpu_info() {
    sysctl -n machdep.cpu.brand_string
    echo "Cores: $(sysctl -n hw.ncpu)"
    top -l 1 -n 0 | grep "CPU usage" | sed 's/^ *//'
}

case "$MODE" in
    battery) battery_info ;;
    disk) disk_info ;;
    memory) memory_info ;;
    wifi) wifi_info ;;
    uptime) uptime_info ;;
    display) display_info ;;
    cpu) cpu_info ;;
    all)
        echo "=== Battery ==="
        battery_info
        echo ""
        echo "=== Disk ==="
        disk_info
        echo ""
        echo "=== Memory ==="
        memory_info
        echo ""
        echo "=== CPU ==="
        cpu_info
        echo ""
        echo "=== Wifi ==="
        wifi_info
        echo ""
        echo "=== Uptime ==="
        uptime_info
        echo ""
        echo "=== Display ==="
        display_info
        ;;
    *) echo "Unknown mode: $MODE. Options: all, battery, disk, memory, wifi, uptime, display, cpu" ;;
esac
