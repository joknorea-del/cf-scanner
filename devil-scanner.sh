#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - THE INVINCIBLE GEAR ENGINE V7.5${NC}"
echo -e "${RED}======================================================${NC}"
echo -e "${YELLOW}         [★] Multi-Stack Dynamic Scanner Mode [★]       ${NC}"
echo -e "${RED}======================================================${NC}"

# Selection Menu
echo -e "${CYAN}Please select the IP family you want to scan:${NC}"
echo -e "1) ${GREEN}IPv4 Ranges${NC} (Standard Cloudflare IPv4)"
echo -e "2) ${GREEN}IPv6 Ranges${NC} (Hyper-Space Cloudflare IPv6)"
echo -ne "\nEnter your choice (1 or 2): "

# Secure TTY input reader
read -r SCAN_CHOICE < /dev/tty

# GitHub Configurations
GITHUB_BASE_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main"

if [ "$SCAN_CHOICE" == "1" ]; then
    echo -e "\n${YELLOW}[*] Selected: IPv4 Scanning Mode${NC}"
    GITHUB_RAW_URL="${GITHUB_BASE_URL}/ranges.txt"
    IS_IPV6_MODE=0
elif [ "$SCAN_CHOICE" == "2" ]; then
    echo -e "\n${YELLOW}[*] Selected: IPv6 Scanning Mode${NC}"
    GITHUB_RAW_URL="${GITHUB_BASE_URL}/ranges6.txt"
    IS_IPV6_MODE=1
else
    echo -e "${RED}[!] Invalid choice! Exiting...${NC}"
    exit 1
fi

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"
CACHE_FILE=".cached_ranges.txt"
SHUFFLED_FILE=".shuffled_ranges.txt"

# Concurrency Limit
MAX_PARALLEL=15

# Initialize Output File
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tAvg_Ping\tSuccess_Rate" > "$RESULT_FILE"
    echo "--------------------------------------------------------" >> "$RESULT_FILE"
fi

# Sync & Shuffle
echo -e "${YELLOW}[*] Downloading selected ranges from GitHub...${NC}"
if curl -s --connect-timeout 10 "$GITHUB_RAW_URL" -o "$CACHE_FILE"; then
    if [ -s "$CACHE_FILE" ] && ! grep -q "404" "$CACHE_FILE"; then
        shuf "$CACHE_FILE" > "$SHUFFLED_FILE"
        echo -e "${GREEN}[✔] Ranges synced and shuffled successfully!${NC}"
    else
        echo -e "${YELLOW}[!] Invalid data from cloud. Trying to use old cache if exists...${NC}"
    fi
fi

if [ ! -s "$SHUFFLED_FILE" ]; then
    echo -e "${RED}[!] Error: No ranges available to scan!${NC}"
    exit 1
fi

total_ranges=$(wc -l < "$SHUFFLED_FILE")
echo -e "${GREEN}[✔] Loaded $total_ranges ranges. GEAR ENGINE ONLINE...${NC}\n"

current_count=0

# Helper function to generate target IPv6 addresses
generate_ipv6_targets() {
    local base_route=$1
    for i in {1..250}; do
        local hex_suffix=$(printf '%x' $((49409 + RANDOM%240)))
        echo "${base_route}a29f:${hex_suffix}"
    done
}

# Scan Execution Engine
while IFS= read -r raw_range <&3; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    if [ $IS_IPV6_MODE -eq 1 ]; then
        # ======================================================
        # IPV6 SCANNING FLOW (Dedicated & Isolated)
        # ======================================================
        clean_line=$(echo "$raw_range" | tr -d '\r' | tr -d ' ' | cut -d'/' -f1)
        
        if [[ "$clean_line" != *"::" ]]; then
            if [[ "$clean_line" == *":" ]]; then
                ipv6_base="${clean_line}:"
            else
                ipv6_base="${clean_line}::"
            fi
        else
            ipv6_base="$clean_line"
        fi
        
        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range: $clean_line ...${NC}"
        
        scout_passed=0
        for scout_suffix in "a29f:c101" "a29f:c110" "a29f:c120"; do
            scout_ip="${ipv6_base}${scout_suffix}"
            
            http_code=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 2.0 --max-time 3.0 \
                --resolve "$TARGET_DOM:443:$scout_ip" "https://$TARGET_DOM" < /dev/null)
            
            if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                scout_passed=1
                break
            fi
        done

        if [ $scout_passed -eq 0 ]; then
            echo -e "${RED}[!] Range $clean_line is totally BLOCKED (Timeout). Skipping!${NC}"
            continue
        fi
        
        echo -e "${GREEN}[+] Range is ALIVE. Scanning IPs...${NC}"
        targets=$(generate_ipv6_targets "$ipv6_base")

        echo "$targets" | while read -r ip; do
            [ -z "$ip" ] && continue

            (
                if timeout 1.5 curl -6 -s -o /dev/null --connect-timeout 1.2 --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM" < /dev/null; then
                    total_ping=0
                    valid_tests=0
                    
                    for test_round in {1..3}; do
                        start_time=$(date +%s%N)
                        http_code=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 1.5 --max-time 2.0 \
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
                            echo -e "${GREEN}[★ LIVE IP] $ip | Avg Ping: ${avg_ping}ms | Success: $valid_tests/3${NC}"
                            echo -e "$ip\t${avg_ping}ms\t$valid_tests/3" >> "$RESULT_FILE"
                        fi
                    fi
                fi
            ) &
            
            while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
                sleep 0.05
            done
        done
        wait

    else
        # ======================================================
        # IPV4 SCANNING FLOW (Original Pure V5 Logic)
        # ======================================================
        clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
        clean_range="${clean_range%.}"

        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range: $clean_range.0/24 ...${NC}"
        
        scout_passed=0
        for scout_id in 2 3 4 126 127 128 251 252 253; do
            scout_ip="$clean_range.$scout_id"
            
            if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/443" 2>/dev/null; then
                scout_passed=1
                break
            fi
        done

        if [ $scout_passed -eq 0 ]; then
            echo -e "${RED}[!] Range $clean_range.0/24 is totally BLOCKED (Timeout). Skipping!${NC}"
            continue
        fi
        
        echo -e "${GREEN}[+] Range is ALIVE. Scanning 254 IPs...${NC}"
        for i in {1..254}; do
            ip="$clean_range.$i"
            
            (
                if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                    total_ping=0
                    valid_tests=0
                    
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
                            echo -e "${GREEN}[★ LIVE IP] $ip | Avg Ping: ${avg_ping}ms | Success: $valid_tests/3${NC}"
                            echo -e "$ip\t${avg_ping}ms\t$valid_tests/3" >> "$RESULT_FILE"
                        fi
                    fi
                fi
            ) &
            
            while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
                sleep 0.05
            done
        done
        wait
    fi

done 3< "$SHUFFLED_FILE"

rm -f "$CACHE_FILE"
rm -f "$SHUFFLED_FILE"
echo -e "${GREEN}[✔] Scan fully completed!${NC}"
