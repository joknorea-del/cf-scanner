#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - DYNAMIC LIVE FILE ENGINE      ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
INPUT_FILE="ranges.txt"
RESULT_FILE="devil_clean_ips.txt"

# Check if the file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}[!] Error: '$INPUT_FILE' not found in this directory!${NC}"
    exit 1
fi

echo -e "IP\t\tPing" > $RESULT_FILE
echo "----------------------------------------" >> $RESULT_FILE

echo -e "${YELLOW}[*] Loading all ranges from $INPUT_FILE and shuffling...${NC}"
# Read all lines from your file and shuffle them instantly in memory
shuffled_ranges=$(shuf "$INPUT_FILE")
total_ranges=$(echo "$shuffled_ranges" | wc -l)
echo -e "${GREEN}[✔] Successfully loaded $total_ranges ranges!${NC}\n"

current_count=0

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    # High precision sanitization
    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Scanning Range: $clean_range.0/24${NC}"
    
    # Concurrent 254-pipe subshell engine
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # Fast TCP Check inside the same shell mapping
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                start_time=$(date +%s%N)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
                    --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM")
                end_time=$(date +%s%N)

                if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    echo -e "${GREEN}[✔ LIVE IP] $ip | Ping: ${ping_ms}ms | Status: $http_code${NC}"
                    echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                fi
            fi
        ) &
        
        # Throttling to protect memory context
        if (( i % 40 == 0 )); then
            sleep 0.1
        fi
    done
    
    # Secure synchronization point: wait for the whole range to finish
    wait
    
done <<< "$shuffled_ranges"

echo -e "\n${GREEN}[★] Scan finished! Results saved to $RESULT_FILE${NC}"
cat $RESULT_FILE
