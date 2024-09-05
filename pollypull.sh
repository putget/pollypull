#!/bin/bash

# nullx
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

DOMAINS=("polyfill.io" "bootcss.com" "bootcdn.net" "staticfile.net" "staticfile.org" "unionadjs.com" "xhsbpza.com" "union.macoms.la" "newcrbpc.com")
POLYFILL_VULNERABILITY_PATTERNS=(
    "<script[^>]*src=['\"]https://polyfill.io/"
)

URL_FILE="$1"
LOG_FILE="scan_results.txt"


high_confidence_count=0
vulnerable_scripts_count=0
domain_found_count=0

check_high_confidence() {
    local src_url="$1"
    for domain in "${DOMAINS[@]}"; do
        if [[ "$src_url" == *"$domain"* ]]; then
            echo -e "${RED}High confidence alert:${NC} ${CYAN}Script loaded from an untrusted domain${NC} - ${RED}$domain${NC} - $src_url" >> "$LOG_FILE"
            ((high_confidence_count++))
            return 0
        fi
    done
    return 1
}

check_polyfill_vulnerability() {
    local url="$1"
    local script_content
    script_content=$(curl -s "$url")
    for pattern in "${POLYFILL_VULNERABILITY_PATTERNS[@]}"; do
        if echo "$script_content" | grep -Eq "$pattern"; then
            echo -e "${YELLOW}Vulnerability found:${NC} ${MAGENTA}Script may be compromised${NC} - $url" >> "$LOG_FILE"
            ((vulnerable_scripts_count++))
            return 0
        fi
    done
    return 1
}

scan_url() {
    local url="$1"
    echo -e "${BLUE}Scanning URL:${NC} ${CYAN}$url${NC}"

    local response
    response=$(curl -s "$url")

    local script_urls
    script_urls=$(echo "$response" | grep -oE '(?<=<script[^>]*src=["'\''])https?://[^"'\'']*(?=["'\''])')

    local high_alert_found=0
    while IFS= read -r script_url; do
        if check_high_confidence "$script_url"; then
            high_alert_found=1
        fi

        if [[ "$script_url" == *"polyfill.io"* ]]; then
            if check_polyfill_vulnerability "$script_url"; then
                echo -e "${YELLOW}Vulnerable script URL:${NC} ${MAGENTA}$script_url${NC}" >> "$LOG_FILE"
            fi
        fi
    done <<< "$script_urls"

    if [ $high_alert_found -eq 0 ]; then
        local line_number=0
        while IFS= read -r line; do
            line_number=$((line_number + 1))
            for domain in "${DOMAINS[@]}"; do
                if [[ "$line" == *"$domain"* ]]; then
                    echo -e "${RED}Domain found:${NC} ${CYAN}$domain${NC} - Line ${RED}$line_number${NC} in URL: ${CYAN}$url${NC}" >> "$LOG_FILE"
                    ((domain_found_count++))
                    break
                fi
            done
        done <<< "$response"
    fi
}

if [ -z "$URL_FILE" ] || [ ! -f "$URL_FILE" ]; then
    echo -e "${RED}Usage:${NC} $0 ${CYAN}urls.txt${NC}"
    exit 1
fi

# Start time tracking
start_time=$(date +%s)

> "$LOG_FILE"
while IFS= read -r url; do
    [[ -z "$url" || "$url" =~ ^# ]] && continue
    
    scan_url "$url"
done < "$URL_FILE"

# End time tracking
end_time=$(date +%s)
duration=$((end_time - start_time))

# Summary
echo -e "${GREEN}Scan complete.${NC} Results are logged in ${CYAN}$LOG_FILE${NC}."
echo -e "${MAGENTA}Domains detected:${NC} $domain_found_count"
echo -e "${BLUE}Total scan duration:${NC} $(date -ud "@$duration" +'%H:%M:%S')"
