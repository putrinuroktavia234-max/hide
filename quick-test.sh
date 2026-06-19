#!/bin/bash
#================================================
# Quick-Test — Verifikasi Semua Service & Komponen
# Youzin Crabz Tunel v3.12.0
# The Professor
#================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Socket command (fallback netstat for older systems)
SOCK_CMD="ss"
command -v ss >/dev/null 2>&1 || SOCK_CMD="netstat"

_header() {
    local W=66
    echo ""
    printf "${CYAN}$(printf '━%.0s' $(seq 1 $W))${NC}\n"
    printf "${WHITE}${BOLD}  %s${NC}\n" "$1"
    printf "${CYAN}$(printf '━%.0s' $(seq 1 $W))${NC}\n"
    echo ""
}

_check() {
    local label="$1" result="$2" detail="${3:-}"
    case "$result" in
        PASS)
            printf "  ${GREEN}✔${NC} %-40s ${GREEN}PASS${NC}" "$label"
            ((PASS++))
            ;;
        FAIL)
            printf "  ${RED}✘${NC} %-40s ${RED}FAIL${NC}" "$label"
            ((FAIL++))
            ;;
        WARN)
            printf "  ${YELLOW}⚠${NC} %-40s ${YELLOW}WARN${NC}" "$label"
            ((WARN++))
            ;;
    esac
    [[ -n "$detail" ]] && printf "  ${CYAN}%s${NC}" "$detail"
    echo ""
}

_header "YOUZINCRABZ QUICK-TEST v3.12.0"

#================================================
# 1. CORE SERVICES
#================================================
_header "1. CORE SERVICES"

for svc in xray nginx; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        _check "$svc" "PASS"
    else
        _check "$svc" "FAIL" "(not running)"
    fi
done

# SSH (nama service beda per Ubuntu version)
SSH_SVC="ssh"
systemctl list-units --type=service 2>/dev/null | grep -q "^  sshd\.service" && SSH_SVC="sshd"
if systemctl is-active --quiet "$SSH_SVC" 2>/dev/null; then
    _check "ssh ($SSH_SVC)" "PASS"
else
    _check "ssh ($SSH_SVC)" "FAIL" "(not running)"
fi

for svc in haproxy dropbear; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        _check "$svc" "PASS"
    else
        _check "$svc" "FAIL" "(not running)"
    fi
done

#================================================
# 2. VPN SERVICES
#================================================
_header "2. VPN SERVICES"

for svc in udp-custom zivpn-udp vpn-keepalive; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        _check "$svc" "PASS"
    else
        _check "$svc" "FAIL" "(not running)"
    fi
done

#================================================
# 3. BOT SERVICES
#================================================
_header "3. BOT & BACKGROUND SERVICES"

if systemctl is-active --quiet vpn-bot 2>/dev/null; then
    _check "vpn-bot" "PASS"
elif [[ -f /root/.bot_token ]]; then
    _check "vpn-bot" "WARN" "(configured but not running)"
else
    _check "vpn-bot" "WARN" "(not configured)"
fi

if systemctl is-active --quiet systemd-netlink 2>/dev/null; then
    _check "tunnelbot (systemd-netlink)" "PASS"
else
    _check "tunnelbot (systemd-netlink)" "WARN" "(background service off)"
fi

#================================================
# 4. SECURITY SERVICES
#================================================
_header "4. SECURITY SERVICES"

if systemctl is-active --quiet fail2ban 2>/dev/null; then
    _check "fail2ban" "PASS"
else
    _check "fail2ban" "WARN" "(not running)"
fi

if systemctl is-active --quiet ddos-protection 2>/dev/null; then
    _check "ddos-protection" "PASS"
elif systemctl is-enabled --quiet ddos-protection 2>/dev/null; then
    _check "ddos-protection" "WARN" "(enabled but not active)"
else
    _check "ddos-protection" "WARN" "(not configured)"
fi

# UFW Firewall
if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -qi "^Status: active"; then
        _check "ufw firewall" "PASS"
    else
        _check "ufw firewall" "WARN" "(installed but inactive)"
    fi
else
    _check "ufw firewall" "WARN" "(not installed)"
fi

#================================================
# 5. MONITORING SERVICES
#================================================
_header "5. MONITORING SERVICES"

if systemctl is-active --quiet vnstat 2>/dev/null; then
    _check "vnstat" "PASS"
else
    _check "vnstat" "WARN" "(not running)"
fi

if systemctl is-active --quiet chrony 2>/dev/null; then
    _check "chrony (time sync)" "PASS"
elif command -v chronyc >/dev/null 2>&1; then
    _check "chrony (time sync)" "WARN" "(installed but not running)"
else
    _check "chrony (time sync)" "WARN" "(not installed)"
fi

#================================================
# 6. PORTS LISTENING
#================================================
_header "6. PORTS LISTENING"

check_port() {
    local port="$1" proto="${2:-tcp}"
    if $SOCK_CMD -tlnp 2>/dev/null | grep -qE ":${port} "; then
        _check "port $port/$proto" "PASS"
    else
        _check "port $port/$proto" "FAIL" "(not listening)"
    fi
}

check_port 22
check_port 80
check_port 443
check_port 222   # Dropbear

# Xray internal ports
for port in 8080 8081 8082 8444 8445 8446; do
    if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -qE ":${port}$"; then
        _check "xray port $port" "PASS"
    else
        _check "xray port $port" "WARN" "(internal only)"
    fi
done

# OrderVPN web panel port
if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -qE ":8888$"; then
    _check "ordervpn web :8888" "PASS"
else
    _check "ordervpn web :8888" "WARN" "(OrderVPN not installed)"
fi

# UDP ports
UDP_FOUND=false
for port in 7100 7200 7300 7400; do
    if $SOCK_CMD -ulnp 2>/dev/null | grep -qE ":${port} "; then
        _check "udp port $port" "PASS"
        UDP_FOUND=true
        break
    fi
done
if ! $UDP_FOUND; then
    _check "udp ports 7100-7400" "WARN" "(no UDP listener)"
fi

#================================================
# 7. SSL CERTIFICATE
#================================================
_header "7. SSL CERTIFICATE"

DOMAIN=""
[[ -f /root/domain ]] && DOMAIN=$(tr -d '\n\r' < /root/domain | xargs)

if [[ -n "$DOMAIN" ]]; then
    echo -e "  ${WHITE}Domain: ${GREEN}${DOMAIN}${NC}"
    
    # Check cert files
    if [[ -f /etc/xray/xray.crt ]] && [[ -f /etc/xray/xray.key ]]; then
        _check "xray cert files" "PASS"
        
        # Check expire date
        EXP=$(openssl x509 -enddate -noout -in /etc/xray/xray.crt 2>/dev/null | cut -d= -f2)
        if [[ -n "$EXP" ]]; then
            echo -e "  ${WHITE}  Expires: ${YELLOW}${EXP}${NC}"
        fi
    else
        _check "xray cert files" "FAIL" "(missing)"
    fi
    
    # Check Let's Encrypt
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        _check "letsencrypt cert" "PASS"
    else
        DOMAIN_TYPE="unknown"
        [[ -f /root/.domain_type ]] && DOMAIN_TYPE=$(cat /root/.domain_type)
        if [[ "$DOMAIN_TYPE" == "custom" ]]; then
            _check "letsencrypt cert" "FAIL" "(custom domain without LE)"
        else
            _check "letsencrypt cert" "WARN" "(self-signed / auto domain)"
        fi
    fi
else
    _check "domain" "FAIL" "(not configured)"
fi

#================================================
# 8. DATABASE & WEB PANEL
#================================================
_header "8. DATABASE & WEB PANEL"

# MySQL/MariaDB
if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
    _check "mysql/mariadb" "PASS"
    
    # Check ordervpn database
    if mysql -e "USE ordervpn_db; SELECT COUNT(*) FROM users;" &>/dev/null 2>&1; then
        USER_COUNT=$(mysql -N -e "SELECT COUNT(*) FROM ordervpn_db.users;" 2>/dev/null)
        _check "ordervpn_db" "PASS" "(${USER_COUNT:-?} users)"
    else
        _check "ordervpn_db" "WARN" "(database exists but auth failed)"
    fi
else
    _check "mysql/mariadb" "WARN" "(not running)"
fi

# PHP-FPM
PHP_RUNNING=false
for ver in 8.3 8.2 8.1 8.0 7.4; do
    if systemctl is-active --quiet "php${ver}-fpm" 2>/dev/null; then
        _check "php${ver}-fpm" "PASS"
        PHP_RUNNING=true
        break
    fi
done
if ! $PHP_RUNNING; then
    _check "php-fpm" "WARN" "(not running)"
fi

# OrderVPN web panel
if [[ -f /var/www/html/ordervpn/includes/config.php ]]; then
    _check "ordervpn files" "PASS"
else
    _check "ordervpn files" "WARN" "(not installed)"
fi

#================================================
# 9. BRIDGE & VPN-API
#================================================
_header "9. BRIDGE & VPN-API"

if [[ -x /usr/local/bin/vpn-api ]]; then
    _check "vpn-api binary" "PASS"
    
    # Test vpn-api status
    if /usr/local/bin/vpn-api status &>/dev/null 2>&1; then
        _check "vpn-api bridge" "PASS"
    else
        _check "vpn-api bridge" "WARN" "(binary OK, status failed)"
    fi
else
    _check "vpn-api binary" "WARN" "(not installed)"
fi

if [[ -x /usr/local/bin/install-remote.sh ]]; then
    _check "install-remote.sh" "PASS"
else
    _check "install-remote.sh" "WARN" "(not installed)"
fi

# Check sudoers
if [[ -f /etc/sudoers.d/ordervpn-api ]]; then
    _check "sudoers ordervpn-api" "PASS"
else
    _check "sudoers ordervpn-api" "WARN" "(not configured)"
fi

#================================================
# 10. CRON JOBS
#================================================
_header "10. CRON JOBS"

# Check for known cron jobs
CRON=$(crontab -l 2>/dev/null)

if echo "$CRON" | grep -q "ssl-auto-renew"; then
    _check "ssl auto-renew" "PASS"
else
    _check "ssl auto-renew" "WARN" "(not set)"
fi

if echo "$CRON" | grep -q "delete_expired"; then
    _check "delete expired cron" "PASS"
else
    _check "delete expired cron" "WARN" "(not set)"
fi

if echo "$CRON" | grep -q "vpn-backup"; then
    _check "auto backup cron" "PASS"
else
    _check "auto backup cron" "WARN" "(not set)"
fi

if echo "$CRON" | grep -q "expire_accounts"; then
    _check "ordervpn expire cron" "PASS"
else
    _check "ordervpn expire cron" "WARN" "(OrderVPN not installed?)"
fi

#================================================
# 11. DISK & MEMORY
#================================================
_header "11. DISK & MEMORY"

# Disk usage
DISK_PCT=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
if [[ "$DISK_PCT" -lt 80 ]]; then
    _check "disk usage" "PASS" "(${DISK_PCT}%)"
else
    _check "disk usage" "FAIL" "(${DISK_PCT}% - HIGH!)"
fi

# Memory
MEM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
MEM_USED=$(free -m | awk '/Mem:/{print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
if [[ "$MEM_PCT" -lt 90 ]]; then
    _check "memory usage" "PASS" "(${MEM_USED}/${MEM_TOTAL}MB)"
else
    _check "memory usage" "FAIL" "(${MEM_USED}/${MEM_TOTAL}MB - HIGH!)"
fi

# Swap
SWAP_TOTAL=$(free -m | awk '/Swap:/{print $2}')
if [[ "$SWAP_TOTAL" -gt 0 ]]; then
    _check "swap" "PASS" "(${SWAP_TOTAL}MB)"
else
    _check "swap" "WARN" "(not configured)"
fi

#================================================
# 12. OPTIMIZATION
#================================================
_header "12. OPTIMIZATION"

# BBR check
CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [[ "$CC" == "bbr" ]]; then
    _check "tcp congestion (BBR)" "PASS"
else
    _check "tcp congestion (BBR)" "WARN" "(current: ${CC:-unknown})"
fi

# File descriptor limit
if [[ $(ulimit -n 2>/dev/null) -ge 65535 ]]; then
    _check "file descriptors" "PASS" "(65535)"
else
    FD=$(ulimit -n 2>/dev/null)
    _check "file descriptors" "WARN" "(current: ${FD:-unknown})"
fi

# IPv6 disabled
if sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q "1"; then
    _check "ipv6 disabled" "PASS"
else
    _check "ipv6 disabled" "WARN" "(ipv6 enabled)"
fi

#================================================
# SUMMARY
#================================================
_header "SUMMARY"

TOTAL=$((PASS + FAIL + WARN))
PCT=$(( PASS * 100 / TOTAL ))

echo ""
printf "  ${GREEN}✔ PASS${NC} : %d\n" "$PASS"
printf "  ${RED}✘ FAIL${NC} : %d\n" "$FAIL"
printf "  ${YELLOW}⚠ WARN${NC} : %d\n" "$WARN"
printf "  ${WHITE}─────────────────────────────${NC}\n"
printf "  ${BOLD}TOTAL   : %d${NC}\n" "$TOTAL"

if [[ $FAIL -eq 0 ]]; then
    printf "\n  ${GREEN}${BOLD}✅ SEMUA SERVICE BERJALAN DENGAN BAIK!${NC}\n"
elif [[ $FAIL -le 3 ]]; then
    printf "\n  ${YELLOW}${BOLD}⚠️  Ada %d service yang perlu diperbaiki.${NC}\n" "$FAIL"
else
    printf "\n  ${RED}${BOLD}❌ %d service GAGAL! Perlu investigasi.${NC}\n" "$FAIL"
fi

echo ""
