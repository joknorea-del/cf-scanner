#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF & WARP SCANNER - THE INVINCIBLE ENGINE    ${NC}"
echo -e "${RED}======================================================${NC}"

# Fix Pipe Input by reading directly from Terminal TTY
echo -e "${CYAN}[?] Select Scan Mode:${NC}"
echo -e "  ${YELLOW}1)${NC} Cloudflare Normal IPs (CDN/Proxy)"
echo -e "  ${YELLOW}2)${NC} Cloudflare WARP Endpoints"
read -p "Enter choice [1-2]: " SCAN_MODE < /dev/tty

echo -e "\n${CYAN}[?] Select IP Version:${NC}"
echo -e "  ${YELLOW}1)${NC} IPv4"
echo -e "  ${YELLOW}2)${NC} IPv6"
read -p "Enter choice [1-2]: " IP_VERSION < /dev/tty

# Sanitize & Default Fallbacks
SCAN_MODE=${SCAN_MODE:-1}
IP_VERSION=${IP_VERSION:-1}

# Configuration
TARGET_DOM="chatgpt.com"
MAX_PARALLEL=15
CACHE_FILE=".cached_ranges.txt"
SHUFFLED_FILE=".shuffled_ranges.txt"
GITHUB_BASE_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main"

# Set Result File based on mode
if [ "$SCAN_MODE" -eq 2 ]; then
    RESULT_FILE="devil_warp_ips.txt"
else
    RESULT_FILE="devil_clean_ips.txt"
fi

# Safe File Initializer
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tAvg_Ping\tSuccess_Rate" > "$RESULT_FILE"
    echo "--------------------------------------------------------" >> "$RESULT_FILE"
fi

# Internal WARP Ranges
WARP_IPV4_RANGES=(
    "162.159.192.0/24"
    "162.159.193.0/24"
    "162.159.195.0/24"
    "162.159.204.0/24"
    "188.114.96.0/24"
    "188.114.97.0/24"
    "188.114.98.0/24"
    "188.114.99.0/24"
)

WARP_IPV6_RANGES=(
    "2606:4700:d0::"
    "2606:4700:d1::"
)

# Helper function to generate target IPv6 addresses
generate_ipv6_targets() {
    local base_route=$1
    for i in {1..250}; do
        local hex_suffix=$(printf '%x' $((49409 + RANDOM%240)))
        echo "${base_route}a29f:${hex_suffix}"
    done
}

# Load Ranges Strategy
> "$CACHE_FILE"

if [ "$SCAN_MODE" -eq 2 ]; then
    echo -e "${YELLOW}[*] Loading Built-in WARP Ranges...${NC}"
    if [ "$IP_VERSION" -eq 1 ]; then
        printf "%s\n" "${WARP_IPV4_RANGES[@]}" > "$CACHE_FILE"
    else
        printf "%s\n" "${WARP_IPV6_RANGES[@]}" > "$CACHE_FILE"
    fi
else
    if [ "$IP_VERSION" -eq 1 ]; then
        echo -e "${YELLOW}[*] Downloading Cloudflare IPv4 ranges (ranges.txt) from GitHub...${NC}"
        curl -s --connect-timeout 10 "${GITHUB_BASE_URL}/ranges.txt" -o "$CACHE_FILE"
    else
        echo -e "${YELLOW}[*] Downloading Cloudflare IPv6 ranges (ranges6.txt) from GitHub...${NC}"
        curl -s --connect-timeout 10 "${GITHUB_BASE_URL}/ranges6.txt" -o "$CACHE_FILE"
    fi
fi

if [ -s "$CACHE_FILE" ] && ! grep -q "404" "$CACHE_FILE"; then
    shuf "$CACHE_FILE" > "$SHUFFLED_FILE"
    echo -e "${GREEN}[✔] Ranges loaded and shuffled successfully!${NC}"
else
    echo -e "${RED}[!] Error: Failed to load ranges! Check your internet or GitHub repository.${NC}"
    exit 1
fi

total_ranges=$(wc -l < "$SHUFFLED_FILE")
echo -e "${GREEN}[✔] Loaded $total_ranges ranges. GEAR ENGINE ONLINE...${NC}\n"

current_count=0

# Engine Execution
while IFS= read -r raw_range <&3; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    if [ "$IP_VERSION" -eq 2 ]; then
        # ======================================================
        # IPV6 SCANNING FLOW
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
        
        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range IPv6: $clean_line ...${NC}"
        
        scout_passed=0
        for scout_suffix in "a29f:c101" "a29f:c110" "a29f:c120"; do
            scout_ip="${ipv6_base}${scout_suffix}"
            
            if [ "$SCAN_MODE" -eq 2 ]; then
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/500" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
            else
                http_code=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 2.0 --max-time 3.0 \
                    --resolve "$TARGET_DOM:443:$scout_ip" "https://$TARGET_DOM" < /dev/null)
                
                if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                    scout_passed=1
                    break
                fi
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
                if [ "$SCAN_MODE" -eq 2 ]; then
                    total_ping=0
                    valid_tests=0
                    
                    for test_round in {1..3}; do
                        start_time=$(date +%s%N)
                        if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$ip/500" 2>/dev/null; then
                            end_time=$(date +%s%N)
                            ping_ms=$(( (end_time - start_time) / 1000000 ))
                            total_ping=$(( total_ping + ping_ms ))
                            ((valid_tests++))
                        fi
                        sleep 0.02
                    done

                    if [ "$valid_tests" -gt 0 ]; then
                        avg_ping=$(( total_ping / valid_tests ))
                        echo -e "${GREEN}[★ LIVE WARP IP] $ip | Avg Ping: ${avg_ping}ms | Success: $valid_tests/3${NC}"
                        echo -e "$ip\t${avg_ping}ms\t$valid_tests/3" >> "$RESULT_FILE"
                    fi
                else
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
                fi
            ) &
            
            while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
                sleep 0.05
            done
        done
        wait

    else
        # ======================================================
        # IPV4 SCANNING FLOW
        # ======================================================
        clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
        clean_range="${clean_range%.}"

        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range IPv4: $clean_range.0/24 ...${NC}"
        
        # Scout Check: 3 from start (2,3,4), 3 from middle (126,127,128), 3 from end (251,252,253)
        scout_passed=0
        for scout_id in 2 3 4 126 127 128 251 252 253; do
            scout_ip="$clean_range.$scout_id"
            
            if [ "$SCAN_MODE" -eq 2 ]; then
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/500" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
            else
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/443" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
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
                if [ "$SCAN_MODE" -eq 2 ]; then
                    total_ping=0
                    valid_tests=0
                    
                    for test_round in {1..3}; do
                        start_time=$(date +%s%N)
                        if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$ip/500" 2>/dev/null; then
                            end_time=$(date +%s%N)
                            ping_ms=$(( (end_time - start_time) / 1000000 ))
                            total_ping=$(( total_ping + ping_ms ))
                            ((valid_tests++))
                        fi
                        sleep 0.02
                    done

                    if [ "$valid_tests" -gt 0 ]; then
                        avg_ping=$(( total_ping / valid_tests ))
                        echo -e "${GREEN}[★ LIVE WARP IP] $ip | Avg Ping: ${avg_ping}ms | Success: $valid_tests/3${NC}"
                        echo -e "$ip\t${avg_ping}ms\t$valid_tests/3" >> "$RESULT_FILE"
                    fi
                else
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
echo -e "${GREEN}[✔] Scan fully completed without interrupts!${NC}"
    if [ "$IP_VERSION" -eq 2 ]; then
        # ======================================================
        # IPV6 SCANNING FLOW
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
        
        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range IPv6: $clean_line ...${NC}"
        
        scout_passed=0
        for scout_suffix in "a29f:c101" "a29f:c110" "a29f:c120"; do
            scout_ip="${ipv6_base}${scout_suffix}"
            
            if [ "$SCAN_MODE" -eq 2 ]; then
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/500" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
            else
                http_code=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 2.0 --max-time 3.0 \
                    --resolve "$TARGET_DOM:443:$scout_ip" "https://$TARGET_DOM" < /dev/null)
                
                if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                    scout_passed=1
                    break
                fi
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
                if [ "$SCAN_MODE" -eq 2 ]; then
                    start_time=$(date +%s%N)
                    if : 2>/dev/null >"/dev/tcp/$ip/2408" || : 2>/dev/null >"/dev/tcp/$ip/500"; then
                        end_time=$(date +%s%N)
                        ping_ms=$(( (end_time - start_time) / 1000000 ))
                        if [ "$ping_ms" -lt 1400 ]; then
                            echo -e "${GREEN}[★ LIVE WARP IP] $ip | Ping: ${ping_ms}ms${NC}"
                            echo -e "$ip\t${ping_ms}ms\t3/3" >> "$RESULT_FILE"
                        fi
                    fi
                else
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
                fi
            ) &
            
            while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
                sleep 0.05
            done
        done
        wait

    else
        # ======================================================
        # IPV4 SCANNING FLOW
        # ======================================================
        clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
        clean_range="${clean_range%.}"

        echo -e "${CYAN}[*] [$current_count/$total_ranges] Checking Range IPv4: $clean_range.0/24 ...${NC}"
        
        # Scout Check: 3 from start (2,3,4), 3 from middle (126,127,128), 3 from end (251,252,253)
        scout_passed=0
        for scout_id in 2 3 4 126 127 128 251 252 253; do
            scout_ip="$clean_range.$scout_id"
            
            if [ "$SCAN_MODE" -eq 2 ]; then
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/2408" 2>/dev/null || timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/500" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
            else
                if timeout 1.2 bash -c ": 2>/dev/null >/dev/tcp/$scout_ip/443" 2>/dev/null; then
                    scout_passed=1
                    break
                fi
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
                if [ "$SCAN_MODE" -eq 2 ]; then
                    start_time=$(date +%s%N)
                    if : 2>/dev/null >"/dev/tcp/$ip/2408" || : 2>/dev/null >"/dev/tcp/$ip/500"; then
                        end_time=$(date +%s%N)
                        ping_ms=$(( (end_time - start_time) / 1000000 ))
                        if [ "$ping_ms" -lt 1400 ]; then
                            echo -e "${GREEN}[★ LIVE WARP IP] $ip | Ping: ${ping_ms}ms${NC}"
                            echo -e "$ip\t${ping_ms}ms\t3/3" >> "$RESULT_FILE"
                        fi
                    fi
                else
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
echo -e "${GREEN}[✔] Scan fully completed without interrupts!${NC}"

    for i in {1..254}; do
        if [ "$IP_VERSION" -eq 1 ]; then
            ip="$clean_range.$i"
        else
            ip_hex=$(printf '%x' $i)
            ip="$clean_range::$ip_hex"
        fi
        
        (
            if [ "$SCAN_MODE" -eq 2 ]; then
                # WARP Scan Phase
                start_time=$(date +%s%N)
                if : 2>/dev/null >"/dev/tcp/$ip/2408" || : 2>/dev/null >"/dev/tcp/$ip/500"; then
                    end_time=$(date +%s%N)
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    if [ "$ping_ms" -lt 1400 ]; then
                        echo -e "${GREEN}[★ LIVE WARP IP] $ip | Ping: ${ping_ms}ms${NC}"
                        echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                    fi
                fi
            else
                # Normal Cloudflare Scan Phase
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
                            echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                        fi
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
echo -e "${GREEN}[✔] Scan fully completed without interrupts!${NC}"
            if [ "$SCAN_MODE" -eq 2 ]; then
                # WARP Scan Phase: Socket check on WARP primary ports (2408/500)
                start_time=$(date +%s%N)
                if : 2>/dev/null >"/dev/tcp/$ip/2408" || : 2>/dev/null >"/dev/tcp/$ip/500"; then
                    end_time=$(date +%s%N)
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    if [ "$ping_ms" -lt 1400 ]; then
                        echo -e "${GREEN}[★ LIVE WARP IP] $ip | Ping: ${ping_ms}ms${NC}"
                        echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                    fi
                fi
            else
                # Normal Cloudflare Scan Phase
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
                            echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                        fi
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
echo -e "${GREEN}[✔] Scan fully completed without interrupts!${NC}"
                # WARP Scan Phase: Socket check on WARP primary ports (2408/500)
                start_time=$(date +%s%N)
                if : 2>/dev/null >"/dev/tcp/$ip/2408" || : 2>/dev/null >"/dev/tcp/$ip/500"; then
                    end_time=$(date +%s%N)
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    if [ "$ping_ms" -lt 1400 ]; then
                        echo -e "${GREEN}[★ LIVE WARP IP] $ip | Ping: ${ping_ms}ms${NC}"
                        echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                    fi
                fi
            else
                # Normal Cloudflare Scan Phase
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
                            echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                        fi
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
echo -e "${GREEN}[✔] Scan fully completed without interrupts!${NC}"
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
