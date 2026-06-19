#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - THE INVINCIBLE GEAR ENGINE V5  ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"
CACHE_FILE=".cached_ranges.txt"
SHUFFLED_FILE=".shuffled_ranges.txt"
GITHUB_RAW_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"

# Concurrency Pacing Limit
MAX_PARALLEL=15

# Safe file initializer
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tAvg_Ping" > "$RESULT_FILE"
    echo "----------------------------------------" >> "$RESULT_FILE"
fi

# Sync & Shuffle Cloud
echo -e "${YELLOW}[*] Downloading ranges from GitHub...${NC}"
if curl -s --connect-timeout 10 "$GITHUB_RAW_URL" -o "$CACHE_FILE"; then
    if [ -s "$CACHE_FILE" ] && ! grep -q "404" "$CACHE_FILE"; then
        shuf "$CACHE_FILE" > "$SHUFFLED_FILE"
        echo -e "${GREEN}[✔] Ranges synced and shuffled successfully!${NC}"
    else
        echo -e "${YELLOW}[!] Invalid data from cloud. Trying to use old file...${NC}"
    fi
fi

if [ ! -s "$SHUFFLED_FILE" ]; then
    echo -e "${RED}[!] Error: No ranges available!${NC}"
    exit 1
fi

total_ranges=$(wc -l < "$SHUFFLED_FILE")
echo -e "${GREEN}[✔] Loaded $total_ranges ranges. GEAR ENGINE ONLINE...${NC}\n"

current_count=0

while IFS= read -r raw_range <&3; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range: $clean_range.0/24 ...${NC}"
    
    # 🎯 ADVANCED RANGE PRE-CHECK (3-Start, 3-Middle, 3-End with Timeout)
    scout_passed=0
    for scout_id in 2 3 4 126 127 128 251 252 253; do
        scout_ip="$clean_range.$scout_id"
        
        # Fast TCP validation wrapper with strict 1.2s execution boundary
        if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/443" 2>/dev/null; then
            scout_passed=1
            break
        fi
    done

    # If all 9 scout IPs failed to respond quickly, skip the dead range
    if [ $scout_passed -eq 0 ]; then
        echo -e "${RED}[!] Range $clean_range.0/24 is totally BLOCKED (Timeout). Skipping!${NC}"
        continue
    fi
    
    # If range is alive, unleash the full scan engine
    echo -e "${GREEN}[+] Range is ALIVE. Scanning 254 IPs...${NC}"
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # Phase 1: TCP Test
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                total_ping=0
                valid_tests=0
                
                # Phase 2: Precise 3-Round Checking
                for test_round in {1..3}; do
                    start_time=$(date +%s%N)
                    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1.8 --max-time 2.2 \
                        --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM" < /dev/null)
                    end_time=$(date +%s%N)

                    if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                        ping_ms=$(( (end_time - start_time) / 1000000 ))
                        total_ping=$(( total_ping + ping_ms ))
                        ((valid_tests++))
                    fi
                    sleep 0.02
                done

                if [ "$valid_tests" -gt 0 ]; then
                    avg_ping=$(( total_ping / valid_tests ))
                    if [ "$avg_ping" -lt 1400 ]; then
                        echo -e "${GREEN}[★ LIVE IP] $ip | Avg Ping: ${avg_ping}ms${NC}"
                        echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                    fi
                fi
            fi
        ) &
        
        # Mechanical Queue Controller
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
            sleep 0.05
        done
        
    done
    wait
done 3< "$SHUFFLED_FILE"

rm -f "$CACHE_FILE"
echo -e "${GREEN}[✔] Scan fully completed!${NC}"
