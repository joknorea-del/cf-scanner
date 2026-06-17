#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}     DEVIL CF SCANNER - RANDOM RANGE SELECTION        ${NC}"
echo -e "${RED}======================================================${NC}"

RANGES_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"
LOCAL_RANGES="ranges.txt"

echo -e "${CYAN}[*] Fetching ranges.txt from GitHub...${NC}"
curl -s -L "$RANGES_URL" -o "$LOCAL_RANGES"

if [ ! -s "$LOCAL_RANGES" ] || grep -q "404" "$LOCAL_RANGES"; then
    echo -e "${RED}[!] Error: Could not fetch ranges.txt from GitHub or file is empty!${NC}"
    exit 1
fi

# Ask for the Target IP to beat
echo -e "${YELLOW}[?] Do you have a benchmark Clean IP to beat? (y/n):${NC} "
read -r has_bench
BENCH_PING=9999
BENCH_SPEED=0

if [ "$has_bench" == "y" ] || [ "$has_bench" == "Y" ]; then
    echo -e "${YELLOW}[>] Enter your current Clean IP:${NC} "
    read -r bench_ip
    echo -e "${CYAN}[*] Benchmarking your IP... Please wait...${NC}"
    
    t_start=$(date +%s%N)
    h_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 -H "Host: speedtest.net" -H "Upgrade: websocket" -H "Connection: Upgrade" "https://$bench_ip/cdn-cgi/trace")
    t_end=$(date +%s%N)
    
    if [ "$h_code" == "200" ] || [ "$h_code" == "400" ]; then
        BENCH_PING=$(( (t_end - t_start) / 1000000 ))
        bench_sp=$(curl -s -w "%{speed_download}" -o /dev/null --max-time 3 "https://$bench_ip/cdn-cgi/images/trace" | cut -d'.' -f1)
        BENCH_SPEED=$(( bench_sp / 1024 ))
        echo -e "${GREEN}[✔] Benchmark Set -> Ping: ${BENCH_PING}ms | Speed: ${BENCH_SPEED} KB/s${NC}\n"
    else
        echo -e "${RED}[!] Failed to benchmark your IP. Proceeding with default values.${NC}\n"
    fi
fi

RESULT_FILE="devil_clean_ips.txt"
echo -e "IP\t\tPing\tSpeed" > $RESULT_FILE
echo "----------------------------------------" >> $RESULT_FILE

# Core function to scan a single IP with high precision
test_concrete_ip() {
    local ip=$1
    
    if ! nc -z -w 2 "$ip" 443 2>/dev/null; then
        return 1
    fi

    local tls_check=$(timeout 3 openssl s_client -connect "$ip:443" -tls1_3 -sni "speedtest.net" </dev/null 2>&1)
    if [[ ! "$tls_check" == *"Verification: OK"* ]] && [[ ! "$tls_check" == *"Cipher is"* ]]; then
        return 1
    fi

    local start_time=$(date +%s%N)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
        -H "Host: speedtest.net" \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        "https://$ip/cdn-cgi/trace")
    local end_time=$(date +%s%N)

    if [ "$http_code" == "200" ] || [ "$http_code" == "400" ]; then
        local ping_ms=$(( (end_time - start_time) / 1000000 ))
        
        local speed_test=$(curl -s -w "%{speed_download}" -o /dev/null --max-time 4 "https://$ip/cdn-cgi/images/trace" | cut -d'.' -f1)
        local speed_kb=$(( speed_test / 1024 ))
        
        if [ "$ping_ms" -lt "$BENCH_PING" ] && [ "$speed_kb" -ge "$BENCH_SPEED" ]; then
            echo -e "${GREEN}[😈 DEVIL IP FOUND] $ip | Ping: ${ping_ms}ms | Speed: ${speed_kb} KB/s${NC}"
            echo -e "$ip\t${ping_ms}ms\t${speed_kb}KB/s" >> $RESULT_FILE
        fi
    fi
}

check_range_alive() {
    local base_range=$1
    if nc -z -w 2 "$base_range.1" 443 2>/dev/null || nc -z -w 2 "$base_range.128" 443 2>/dev/null || nc -z -w 2 "$base_range.254" 443 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 🎯 STEP 1: Shuffle the rows of ranges.txt to make the selection completely random!
shuffled_ranges=$(shuf "$LOCAL_RANGES")

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g')

    echo -e "${CYAN}[*] Selected Random Range: $clean_range.0/24${NC}"
    
    if ! check_range_alive "$clean_range"; then
        echo -e "${RED}[❌] Range $clean_range.0/24 is blocked. Skipping to next random range...${NC}"
        continue
    fi

    echo -e "${YELLOW}[+] Range Alive! Scanning all 254 IPs inside this range...${NC}"
    
    MAX_JOBS=25
    job_count=0
    
    # STEP 2: Scan IPs inside this specific range (shuffled internally for extra safety)
    for i in $(shuf -i 1-254); do
        test_concrete_ip "$clean_range.$i" &
        
        ((job_count++))
        if [ "$job_count" -ge "$MAX_JOBS" ]; then
            wait
            job_count=0
        fi
    done
    wait
    echo -e "${GREEN}[✔] Finished scanning range $clean_range.0/24${NC}\n"
    
done <<< "$shuffled_ranges"

# Clean up temporary ranges file
rm -f "$LOCAL_RANGES"

echo -e "\n${GREEN}[★] Scan finished! Results saved to $RESULT_FILE${NC}"
cat $RESULT_FILE

