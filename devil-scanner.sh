#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - THE RESILIENT BEAST ENGINE     ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"
CACHE_FILE=".cached_ranges.txt"
SHUFFLED_FILE=".shuffled_ranges.txt"
GITHUB_RAW_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"

# Safe file initializer
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tAvg_Ping" > "$RESULT_FILE"
    echo "----------------------------------------" >> "$RESULT_FILE"
fi

# Sync & Shuffle straight into a local hard-file
echo -e "${YELLOW}[*] Downloading ranges from GitHub...${NC}"
if curl -s --connect-timeout 10 "$GITHUB_RAW_URL" -o "$CACHE_FILE"; then
    if [ -s "$CACHE_FILE" ] && ! grep -q "404" "$CACHE_FILE"; then
        # Shuffle hard on disk to prevent memory dropouts
        shuf "$CACHE_FILE" > "$SHUFFLED_FILE"
        echo -e "${GREEN}[✔] Hard-disk cache synchronized and shuffled!${NC}"
    else
        echo -e "${YELLOW}[!] Cloud returned invalid data. Trying to use old shuffled file...${NC}"
    fi
fi

if [ ! -s "$SHUFFLED_FILE" ]; then
    echo -e "${RED}[!] Error: No ranges available to scan! Check internet connection.${NC}"
    exit 1
fi

total_ranges=$(wc -l < "$SHUFFLED_FILE")
echo -e "${GREEN}[✔] Loaded $total_ranges ranges. SCANNING POWER INSANE...${NC}\n"

current_count=0

# 🌟 Bulletproof loop reading directly from file descriptor 3
while IFS= read -r raw_range <&3; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Testing: $clean_range.0/24${NC}"
    
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # Phase 1: TCP connection test
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                total_ping=0
                valid_tests=0
                
                # Phase 2: 3-Round test with friendly 1.8s timeout
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

                # 🎯 CHANGE: If at least 1 test succeeds, we accept the IP! No more harsh drops.
                if [ "$valid_tests" -gt 0 ]; then
                    avg_ping=$(( total_ping / valid_tests ))
                    
                    # Store premium IPs
                    if [ "$avg_ping" -lt 1400 ]; then
                        echo -e "${GREEN}[★ LIVE IP] $ip | Avg Ping: ${avg_ping}ms | Success: $valid_tests/3${NC}"
                        echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                    fi
                fi
            fi
        ) &
        
        # Smooth pacing for Termux stability
        if (( i % 12 == 0 )); then
            sleep 0.1
        fi
    done
    
    wait
    
done 3< "$SHUFFLED_FILE"

# Clean temporary shuffled files at the very end
rm -f "$CACHE_FILE"
