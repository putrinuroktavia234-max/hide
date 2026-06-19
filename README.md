# 🦀 Youzin Crabz Tunel — Auto Script VPN

**SSH • VMess • VLess • Trojan • WebSocket • gRPC • Multi-VPS • OrderVPN Web Panel**

Script auto-install VPN lengkap dengan Web Panel, Telegram Bot, Multi-VPS management, Backup System, dan DDoS Protection.

---

## 📸 Tampilan Menu VPS

### Dashboard Utama (langsung muncul saat SSH login)

```
┌──────────────────────────────────────────────────────────────────┐
│                    ✦  YOUZINCRABZ PANEL  ✦                      │
│                        The Professor                             │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    SERVER CORE STATUS                            │
│──────────────────────────────────────────────────────────────────│
│  IP Address  : 123.45.67.89                                     │
│  Domain      : vpn.example.com                                  │
│  OS          : Ubuntu 22.04 LTS                                 │
│  Uptime      : 3d 12h 45m                                       │
│  CPU Load    : 12%                                              │
│  RAM Usage   : 512 / 4096 MB  [████░░░░░░░░] 12%               │
│  SSL Status  : LetsEncrypt (Active)                             │
│  Services    : 9/9 Running                                      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    ACTIVE ACCOUNTS                               │
│──────────────────────────────────────────────────────────────────│
│     SSH: 15  VMess: 23  VLess: 8  Trojan: 5                     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    NETWORK SERVICES                              │
│──────────────────────────────────────────────────────────────────│
│  XRAY     : ● ONLINE    NGINX    : ● ONLINE                      │
│  HAPROXY  : ● ONLINE    DROPBEAR : ● ONLINE                      │
│  SSH      : ● ONLINE    UDP CUST : ● ONLINE                      │
│  KEEPALIVE: ● ONLINE    BOT TG   : ● ONLINE                      │
│  FAIL2BAN : ● ONLINE    CRON AUTO: ● ONLINE                      │
│  FIREWALL : ● ONLINE                                             │
└──────────────────────────────────────────────────────────────────┘
```

### Main Menu

```
┌──────────────────────────────────────────────────────────────────┐
│                    ACCOUNT MANAGEMENT                            │
│──────────────────────────────────────────────────────────────────│
│  [ 1] SSH / OpenVPN        [ 5] List All Accounts               │
│  [ 2] VMess Account        [ 6] Renew / Extend Akun             │
│  [ 3] VLess Account        [ 7] Check Expired                   │
│  [ 4] Trojan Account       [ 8] Delete Expired                  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    SYSTEM CONTROL                                │
│──────────────────────────────────────────────────────────────────│
│  [ 9] Telegram Bot         [14] Speedtest VPS                   │
│  [10] Change Domain        [15] Backup Config                   │
│  [11] SSL Manager          [16] Restore Config                  │
│  [12] Optimize VPS         [17] Uninstall Panel                 │
│  [13] Restart Service      [18] Advanced Mode                   │
│  [19] Port Info            [20] ZI VPN UDP                      │
│  [21] OrderVPN Web         [22] DDoS Protect                    │
│  [23] Traffic Monitor      [24] Health Check                    │
│──────────────────────────────────────────────────────────────────│
│  [0]  Exit Panel                                                │
└──────────────────────────────────────────────────────────────────┘
```

### Advanced Menu [18]

```
┌──────────────────────────────────────────────────────────────────┐
│  [1]  Change Domain        [6]  SSH Brute Protection            │
│  [2]  Renew Certificate    [7]  UFW Manager                     │
│  [3]  Auto Backup          [8]  Limit User Login                │
│  [4]  Restore Backup       [9]  Quota Manager                   │
│  [5]  Speedtest            [10] Custom Payload                  │
│──────────────────────────────────────────────────────────────────│
│  [0]  Back                                                      │
└──────────────────────────────────────────────────────────────────┘
```

### OrderVPN Web Panel (Port 8888)

```
┌─────────────────────────────────────────────────────┐
│              ORDER VPN                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  Total User  │  │  Server     │  │  Akun Aktif │  │
│  │     47       │  │     3       │  │     38      │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│                                                     │
│  ▸ Dashboard   ▸ Servers   ▸ Users                 │
│  ▸ Orders      ▸ Top Up    ▸ Settings              │
│  ▸ Announcements (3 editable cards)                │
│                                                     │
│  📊 Traffic Graph (Chart.js)                        │
│  📋 Recent Transactions                            │
│  🔔 Activity Log                                   │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 Fitur

### Core VPN
- ✅ **SSH** — OpenSSH + Dropbear (port 22 & 222)
- ✅ **VMess** — WebSocket TLS/NonTLS + gRPC
- ✅ **VLess** — WebSocket TLS/NonTLS + gRPC  
- ✅ **Trojan** — WebSocket TLS/NonTLS + gRPC
- ✅ **UDP Custom** — BadVPN 7100-7300 + ZI VPN 7400-7500

### Web Panel (OrderVPN v2.0)
- ✅ **Admin Dashboard** — User management, server management, transactions
- ✅ **Auto Order** — User bisa order VPN sendiri via web
- ✅ **Top Up Saldo** — Manual + Tripay auto payment
- ✅ **Pengumuman** — 3 editable announcement cards
- ✅ **OTP Reset Password** — Email verification + 15-min expiry
- ✅ **Dark Theme** — Modern UI dengan Chart.js analytics

### System
- ✅ **Auto Install** — One-click install semua dependency
- ✅ **Multi-VPS** — Remote deploy via SSH bridge (vpn-api)
- ✅ **SSL Let's Encrypt** — Auto-renew tgl 1 & 15 setiap bulan
- ✅ **Auto Backup** — MySQL + config ke Google Drive (rclone)
- ✅ **DDoS Protection** — 40 iptables rules
- ✅ **Fail2ban** — SSH brute force protection
- ✅ **Traffic Monitor** — vnstat integration
- ✅ **Speedtest** — Ookla CLI
- ✅ **BBR Optimization** — TCP tuning
- ✅ **Health Check** — Quick-test 50+ service checks

---

## 📦 Cara Install

### Fresh VPS (Ubuntu 20.04 / 22.04 / 24.04)

```bash
wget https://raw.githubusercontent.com/putrinuroktavia234-max/hide/main/tunnel.sh
chmod +x tunnel.sh
bash tunnel.sh
```

Menu akan langsung muncul — pilih opsi install untuk memulai.

### Quick Test Setelah Install

```bash
bash quick-test.sh
```

Atau dari dalam menu: pilih **[24] Health Check**

---

## 📋 Menu Lengkap

| # | Menu | Fungsi |
|---|------|--------|
| 1 | SSH / OpenVPN | Buat akun SSH |
| 2 | VMess Account | Buat akun VMess |
| 3 | VLess Account | Buat akun VLess |
| 4 | Trojan Account | Buat akun Trojan |
| 5 | List All Accounts | Lihat semua akun |
| 6 | Renew / Extend | Perpanjang akun |
| 7 | Check Expired | Cek akun expired |
| 8 | Delete Expired | Hapus akun expired |
| 9 | Telegram Bot | Setup bot notifikasi |
| 10 | Change Domain | Ganti domain |
| 11 | SSL Manager | Kelola SSL certificate |
| 12 | Optimize VPS | BBR + sysctl tuning |
| 13 | Restart Service | Restart individual service |
| 14 | Speedtest VPS | Tes kecepatan (Ookla) |
| 15 | Backup Config | Backup manual |
| 16 | Restore Config | Restore dari backup |
| 17 | Uninstall Panel | Hapus komponen |
| 18 | Advanced Mode | Menu lanjutan |
| 19 | Port Info | Info port & protocol |
| 20 | ZI VPN UDP | UDP gateway 7400-7500 |
| 21 | OrderVPN Web | Install web panel |
| 22 | DDoS Protect | DDoS protection rules |
| 23 | Traffic Monitor | Monitor bandwidth |
| 24 | Health Check | Verifikasi 50+ service |

---

## 🔧 Teknologi

| Komponen | Teknologi |
|----------|-----------|
| **VPN Core** | Xray-Core (XTLS) |
| **Web Server** | Nginx + HAProxy |
| **Database** | MySQL / MariaDB |
| **Web Panel** | PHP 8.x + PDO + Chart.js |
| **Bot** | Python 3 + Telegram API |
| **Backup** | rclone → Google Drive |
| **Firewall** | UFW + iptables (40 rules) |
| **Monitoring** | vnstat, chrony, fail2ban |
| **SSL** | Let's Encrypt (certbot) |
| **Payment** | Tripay integration |

---

## 🌐 Port yang Digunakan

| Port | Service |
|------|---------|
| 22 | SSH OpenSSH |
| 222 | SSH Dropbear |
| 80 | Nginx HTTP / Xray WS NonTLS |
| 443 | Nginx HTTPS / Xray WS TLS + gRPC |
| 8080-8082 | Xray VMess/VLess/Trojan WS (internal) |
| 8444-8446 | Xray VMess/VLess/Trojan gRPC (internal) |
| 7100-7300 | BadVPN UDP |
| 7400-7500 | ZI VPN UDP |
| 8888 | OrderVPN Web Panel |

---

## ⚡ Quick Test (Health Check)

```bash
bash quick-test.sh
```

Mengecek 12 kategori:
1. Core Services (xray, nginx, ssh, haproxy, dropbear)
2. VPN Services (udp-custom, zivpn-udp, vpn-keepalive)
3. Bot Services (vpn-bot, tunnelbot)
4. Security (fail2ban, ddos-protection, ufw)
5. Monitoring (vnstat, chrony)
6. Ports Listening (10+ ports)
7. SSL Certificate (expiry, Let's Encrypt)
8. Database & Web Panel (MySQL, PHP-FPM)
9. Bridge vpn-api (binary, status, sudoers)
10. Cron Jobs (ssl-renew, backup, cleanup)
11. Disk & Memory
12. Optimization (BBR, file descriptors, IPv6)

---

## 📁 File di Repository

| File | Fungsi |
|------|--------|
| `tunnel.sh` | Script utama (32,000+ lines) |
| `quick-test.sh` | Health check verifikasi service |
| `OrderVPN_Preview.html` | Preview dashboard web panel |

---

## 👤 Credits

**Youzin Crabz Tunel — The Professor**

- Telegram: [@YouzinCrabz](https://t.me/YouzinCrabz)
- GitHub: [putrinuroktavia234-max](https://github.com/putrinuroktavia234-max)

---

> ⚠️ **Disclaimer**: Script ini untuk tujuan edukasi dan manajemen server pribadi. Gunakan dengan bijak.
