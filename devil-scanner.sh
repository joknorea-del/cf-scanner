#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - ULTRA SPEED CLOUD ENGINE       ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"
GITHUB_RAW_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"

# Initialize clean result file if not exists
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tPing" > $RESULT_FILE
    echo "----------------------------------------" >> $RESULT_FILE
fi

echo -e "${YELLOW}[*] Fetching all ranges live from GitHub...${NC}"
shuffled_ranges=$(curl -s "$GITHUB_RAW_URL" | shuf)

if [ -z "$shuffled_ranges" ] || echo "$shuffled_ranges" | grep -q "404"; then
    echo -e "${RED}[!] Error: Could not fetch data from GitHub!${NC}"
    exit 1
fi

total_ranges=$(echo "$shuffled_ranges" | wc -l)
echo -e "${GREEN}[✔] Successfully loaded $total_ranges ranges from cloud!${NC}\n"

current_count=0

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Scanning: $clean_range.0/24${NC}"
    
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # ⚡ تِست فوق سریع پورت با کانکشن تایم‌اوت ۱ ثانیه‌ای
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                start_time=$(date +%s%N)
                # 🎯 کاهش تایم‌اوت به ۱.۲ ثانیه برای رد کردن سریع آی‌پی‌های سنگین و بن شده
                http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1.2 --max-time 1.5 \
                    --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM")
                end_time=$(date +%s%N)

                if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    # 🔥 فقط آی‌پی‌های زیر ۱۲۰۰ میلی‌ثانیه که واقعاً خفن هستند نمایش داده و ذخیره شوند
                    if [ "$ping_ms" -lt 1200 ]; then
                        echo -e "${GREEN}[✔ LIVE IP] $ip | Ping: ${ping_ms}ms | Status: $http_code${NC}"
                        echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                    else
                        # نمایش آی‌پی‌های پینگ بالا با رنگ زرد جهت اطلاع، بدون ذخیره در فایل طلایی
                        echo -e "${YELLOW}[▲ SLOW IP] $ip | Ping: ${ping_ms}ms (Filtered)${NC}"
                    fi
                fi
            fi
        ) &
        
        # 🏎️ تنظیم بهینه دسته شلیک برای جلوگیری از اشباع شبکه و پینگ کاذب
        if (( i % 25 == 0 )); then
            sleep 0.05
        fi
    done
    
    wait
    
done <<< "$shuffled_ranges"
